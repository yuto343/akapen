// kit guard : エージェントが Bash で流すコマンドのうち、local の外に出るもの（リリース、デプロイ、
// タグ、main への push、local 以外の Convex への書き込み）を止める（ADR-006）。
//
// フックとして: stdin に Claude Code / Codex の PreToolUse の入力（{tool_name, tool_input.command, cwd}）。
//   止める = 終了コード 2 と stderr（エージェントに返る）。警告 = 終了コード 0 と stderr。通す = 0。
//   guard 自体が落ちたとき（設定が壊れている、rules.json が無い など）も 2 で止める。
// 手で: kit guard --cmd "<コマンド>" [--cwd <dir>]
//
// 設定はリポジトリの kit.config.json の guard:
//   warn: 止めずに警告だけにするルールの id（ADR-012）
//   allowScripts: 名前の規則では止まるが通すスクリプト（例 release:status）
//   blockScripts: 名前の規則では止まらないが止めるスクリプト（例 convex:cloud）
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { flag, expandHome } from "../lib.mjs";
import { validate } from "../schema.mjs";

let RULES;
const rules = () => (RULES ??= JSON.parse(fs.readFileSync(new URL("../../guard/rules.json", import.meta.url), "utf8")));

const WRAPPERS = new Set(["time", "nohup", "exec", "command", "builtin", "then", "do", "else", "elif", "if", "while", "until", "!", "{", "}"]);
const WRAP_OPTS = {
  env: new Set(["-u", "--unset", "-C", "--chdir", "-S", "--split-string"]),
  timeout: new Set(["-s", "--signal", "-k", "--kill-after"]),
  sudo: new Set(["-u", "--user", "-g", "--group", "-C", "--close-from", "-D", "--chdir", "-h", "--host", "-p", "--prompt", "-r", "--role", "-t", "--type", "-U", "--other-user", "-T", "--command-timeout"]),
  nice: new Set(["-n", "--adjustment"]),
  caffeinate: new Set(["-t", "-w"]),
  xargs: new Set(["-I", "-n", "-P", "-L", "-d", "-s", "-E", "-a"]),
};
const SHELLS = new Set(["bash", "sh", "zsh"]);
const RUNNERS = new Set(["node", "bun", "tsx", "ts-node", "bash", "sh", "zsh", "python", "python3", "source", "."]);
const RUNNER_OPTS = new Set(["--import", "-r", "--require", "--loader", "-e", "--eval", "-p", "--print", "-m", "--env-file"]);
const PMS = new Set(["pnpm", "npm", "yarn", "bun"]);
const EXEC_OPTS = new Set(["-p", "--package", "-c", "--call"]);
const ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*=/;
const KIT_RE = /^(?:.*\/)?kit(?:\.mjs)?$/;
const FILE_RE = /^(?![-/])(?!.*:\/\/)(?:\.\.?\/.+|.+\.(?:sh|mjs|js|cjs|ts|mts|py))$/;
const HELP = new Set(["--help", "-h", "--version"]);
const CONVEX_REMOTE = ["--deployment", "--deployment-name", "--env-file", "--url", "--admin-key", "--preview-name"];
const GIT_GLOBAL_VALUE = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"]);
const PUSH_VALUE = new Set(["--repo", "-o", "--push-option", "--receive-pack", "--exec"]);
const TAG_VALUE = new Set(["-m", "--message", "-F", "--file", "-u", "--local-user", "--cleanup"]);
const TAG_READ = new Set(["-l", "--list", "--merged", "--no-merged", "--contains", "--no-contains", "--points-at", "--column", "-d", "--delete", "-v", "--verify"]);
const GH_VALUE = new Set(["-R", "--repo", "-X", "--method", "-f", "-F", "--field", "--raw-field", "--input", "-H", "--header", "-q", "--jq", "-t", "--template", "--hostname", "--cache", "-p", "--preview"]);
// --help の直前にあると、--help がその値になるオプション
const VALUE_OPTS = new Set([...GIT_GLOBAL_VALUE, ...PUSH_VALUE, ...TAG_VALUE, ...GH_VALUE, ...CONVEX_REMOTE, "-b", "--body", "-n", "--notes", "--notes-file", "--title", "--target", "-e", "--env", "--config", "--name", "--command", "--file", "--platform", "--profile", "--branch", "--channel", "-j"]);

const base = (p) => path.basename(p ?? "");
const readText = (p) => { try { return fs.readFileSync(p, "utf8"); } catch { return null; } };
const safeJson = (s) => { try { return s ? JSON.parse(s) : null; } catch { return null; } };
const globRe = (s) => new RegExp(`^${s.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*")}$`);

// ---- 字句解析: 単純なコマンド {words, heredocs, op} の列と、中で実行されるコマンド置換の中身 subs にする
export function parse(src) {
  const cmds = [], subs = [], pending = [];
  let words = [], heredocs = [], w = null, skip = false, here = false, i = 0;
  const add = (s) => { w = (w ?? "") + s; };
  const pushWord = () => {
    if (w === null) return;
    if (skip) skip = false;
    else if (here) { heredocs.push({ body: w }); here = false; }
    else words.push(w);
    w = null;
  };
  const end = (op) => {
    pushWord(); skip = here = false;
    if (words.length || heredocs.length) cmds.push({ words, heredocs, op });
    words = []; heredocs = [];
  };
  const dollarParen = (j) => {
    const e = closeParen(src, j + 2);
    if (src[j + 2] !== "(") subs.push(src.slice(j + 2, e));
    return e + 1;
  };
  while (i < src.length) {
    const c = src[i];
    if (c === "\n") {
      end(";"); i++;
      for (const h of pending.splice(0)) {
        const lines = [];
        while (i < src.length) {
          const e = src.indexOf("\n", i);
          const line = src.slice(i, e < 0 ? src.length : e);
          i = e < 0 ? src.length : e + 1;
          if (line.trim() === h.tag) break;
          lines.push(line);
        }
        h.body = lines.join("\n");
      }
      continue;
    }
    if (c === " " || c === "\t") { pushWord(); i++; continue; }
    if (c === "#" && w === null) { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (c === "\\") { if (src[i + 1] !== "\n") add(src[i + 1] ?? ""); i += 2; continue; }
    if (c === "'") {
      const e = src.indexOf("'", i + 1);
      add(src.slice(i + 1, e < 0 ? src.length : e));
      i = e < 0 ? src.length : e + 1;
      continue;
    }
    if (c === '"') {
      let j = i + 1, s = "";
      while (j < src.length && src[j] !== '"') {
        if (src[j] === "\\" && j + 1 < src.length) { s += src[j + 1]; j += 2; }
        else if (src[j] === "$" && src[j + 1] === "(") { const e = dollarParen(j); s += src.slice(j, e); j = e; }
        else if (src[j] === "`") { const e = closeTick(src, j + 1); subs.push(src.slice(j + 1, e)); s += src.slice(j, e + 1); j = e + 1; }
        else s += src[j++];
      }
      add(s); i = j + 1;
      continue;
    }
    if (c === "$" && src[i + 1] === "(") { const e = dollarParen(i); add(src.slice(i, e)); i = e; continue; }
    if (c === "`") { const e = closeTick(src, i + 1); subs.push(src.slice(i + 1, e)); add(src.slice(i, e + 1)); i = e + 1; continue; }
    if ((c === "<" || c === ">") && src[i + 1] === "(") { pushWord(); const e = closeParen(src, i + 2); subs.push(src.slice(i + 2, e)); i = e + 1; continue; }
    if (src.startsWith("<<<", i)) { pushWord(); here = true; i += 3; continue; }
    if (src.startsWith("<<", i)) {
      const m = /^<<-?[ \t]*(?:'([^'\n]*)'|"([^"\n]*)"|\\?([^\s;&|<>()'"]+))/.exec(src.slice(i, i + 200));
      if (m) {
        if (w !== null && /^\d+$/.test(w)) w = null;
        pushWord();
        const h = { tag: m[1] ?? m[2] ?? m[3], body: "" };
        heredocs.push(h); pending.push(h); i += m[0].length;
        continue;
      }
    }
    if (src.startsWith("&&", i) || src.startsWith("||", i)) { end(src.slice(i, i + 2)); i += 2; continue; }
    if (src.startsWith("&>", i)) { pushWord(); i += src[i + 2] === ">" ? 3 : 2; skip = true; continue; }
    if (c === "|") { end("|"); i += src[i + 1] === "&" ? 2 : 1; continue; }
    if (";&()".includes(c)) { end(c); i++; continue; }
    if (c === ">" || c === "<") {
      if (w !== null && /^\d+$/.test(w)) w = null;
      pushWord(); i++;
      if (src[i] === ">" || src[i] === "|" || (c === "<" && src[i] === ">")) i++;
      if (src[i] === "&") {
        i++;
        while (i < src.length && /[\d-]/.test(src[i])) i++;
        if (/[\s;|&)]/.test(src[i] ?? " ")) continue;
      }
      skip = true;
      continue;
    }
    add(c); i++;
  }
  end(";");
  return { cmds, subs };
}

function closeParen(src, j) {
  for (let depth = 1; j < src.length; j++) {
    const c = src[j];
    if (c === "\\") j++;
    else if (c === "'") { const e = src.indexOf("'", j + 1); j = e < 0 ? src.length : e; }
    else if (c === '"') { j++; while (j < src.length && src[j] !== '"') j += src[j] === "\\" ? 2 : 1; }
    else if (c === "(") depth++;
    else if (c === ")" && --depth === 0) return j;
  }
  return src.length;
}
function closeTick(src, j) {
  while (j < src.length && src[j] !== "`") j += src[j] === "\\" ? 2 : 1;
  return j;
}

function skipFlags(a, i, takes = new Set()) {
  while (i < a.length && a[i].startsWith("-") && a[i] !== "-") {
    if (a[i] === "--") return i + 1;
    i += takes.has(a[i]) ? 2 : 1;
  }
  return i;
}
function positionals(a, takes = new Set()) {
  const out = [];
  for (let i = 0; i < a.length; i++) {
    if (a[i] === "--") { out.push(...a.slice(i + 1)); break; }
    if (a[i].startsWith("-") && a[i] !== "-") { if (takes.has(a[i])) i++; continue; }
    out.push(a[i]);
  }
  return out;
}

// 先頭の VAR=x と、env・timeout・sudo などのラッパーを外す。env は書き換える
function unwrap(a, env) {
  for (;;) {
    while (a.length && ASSIGN.test(a[0])) { const k = a[0].indexOf("="); env[a[0].slice(0, k)] = a[0].slice(k + 1); a = a.slice(1); }
    const b = base(a[0]);
    if (WRAPPERS.has(b)) { a = a.slice(1); continue; }
    if (WRAP_OPTS[b]) {
      let i = skipFlags(a, 1, WRAP_OPTS[b]);
      if (b === "env") a.slice(1, i).forEach((x, k, f) => { if (x === "-u" || x === "--unset") delete env[f[k + 1]]; });
      if (b === "timeout") i++;
      a = a.slice(i);
      continue;
    }
    const afterDashDash = ["dotenv", "dotenv-cli", "with-env"].includes(b) || (["doppler", "op", "infisical"].includes(b) && a[1] === "run");
    if (afterDashDash && a.includes("--")) { a = a.slice(a.indexOf("--") + 1); continue; }
    return a;
  }
}

// bash の引数: -c があれば {command}、スクリプトのファイルがあれば {file}、どちらも無ければ {}（stdin を読む）
function shellArgs(a) {
  let c = false, s = false;
  for (let i = 1; i < a.length; i++) {
    const x = a[i];
    if (x === "--") return c ? { command: a[i + 1] } : { file: a[i + 1] };
    if (/^[-+][a-zA-Z]+$/.test(x)) {
      if (x.includes("c")) c = true;
      if (x.includes("s")) s = true;
      if (x.includes("o")) i++;
      continue;
    }
    if (x.startsWith("--")) { if (x === "--rcfile" || x === "--init-file") i++; continue; }
    return c ? { command: x } : s ? {} : { file: x };
  }
  return {};
}

// ---- 判定。st = {wd, env, stack}（cd と export はこの入力の後ろのコマンドに効く）
function walk(src, st, depth, ctx) {
  if (depth > 8) return [];
  const { cmds, subs } = parse(src);
  const hits = [];
  const sub = (s, env = st.env) => { if (s) hits.push(...walk(s, { wd: st.wd, env: { ...env }, stack: [...st.stack] }, depth + 1, ctx)); };
  // cd で別のリポジトリ（clone や worktree）に入ったら、そのリポジトリのスクリプトで判定する
  const enter = () => { const r = fs.existsSync(st.wd) && findRepoRoot(st.wd); if (r && real(r) !== ctx.root) ctx = repoContext(real(r), ctx.cfg); };
  for (const s of subs) sub(s);
  let stages = [];
  for (const c of cmds) {
    const before = stages;
    stages = c.op === "|" ? [...stages, c] : [];
    const env = { ...st.env };
    const a = unwrap(c.words, env);
    if (!a.length) continue;
    const b = base(a[0]);
    if (b === "cd" || b === "pushd") {
      if (a[1] === "-") continue;
      if (b === "pushd") st.stack.push(st.wd);
      st.wd = real(path.resolve(st.wd, expandHome(a[1] ?? "~")));
      enter();
      continue;
    }
    if (b === "popd") { st.wd = st.stack.pop() ?? st.wd; enter(); continue; }
    if (b === "export") { for (const x of a.slice(1)) if (ASSIGN.test(x)) { const k = x.indexOf("="); st.env[x.slice(0, k)] = x.slice(k + 1); } continue; }
    if (b === "unset") { for (const x of a.slice(1)) delete st.env[x]; continue; }
    if (b === "eval") { sub(a.slice(1).join(" "), env); continue; }
    if (SHELLS.has(b)) {
      const sh = shellArgs(a);
      if ("command" in sh) { sub(sh.command, env); continue; }
      if (!sh.file) {
        for (const h of c.heredocs) sub(h.body, env);
        for (const s of before) { sub(s.words.slice(1).join(" "), env); for (const h of s.heredocs) sub(h.body, env); }
        continue;
      }
    }
    if (b === "source" || b === ".") for (const h of c.heredocs) sub(h.body, env);
    hits.push(...checkArgv(a, env, st.wd, depth, ctx));
  }
  return hits;
}

const hit = (id, argv, why = rules().why[id]) => ({ id, why, cmd: argv.join(" ") });
const TOOLS = { git: checkGit, convex: checkConvex, wrangler: checkWrangler, eas: checkEas, "eas-cli": checkEas, gh: checkGh, make: checkMake };

function checkArgv(a, env, wd, depth, ctx) {
  const b = base(a[0]);
  if (PMS.has(b) && !(b === "bun" && FILE_RE.test(a[1] ?? ""))) return checkPm(a, env, wd, depth, ctx);
  if (["npx", "pnpx", "bunx"].includes(b)) return execBin(a.slice(1), env, wd, depth, ctx);
  if (["npm-run-all", "run-p", "run-s"].includes(b)) {
    const pkg = ctx.nearest(wd);
    const names = positionals(a.slice(1)).flatMap((n) => (n.includes("*") ? Object.keys(pkg.scripts).filter((s) => globRe(n).test(s)) : [n]));
    return runScripts(names, [pkg], wd, env, depth, ctx, a);
  }
  if (b === "concurrently") {
    return positionals(a.slice(1), new Set(["-n", "--names", "-c", "--prefix-colors", "-p", "--prefix", "-m", "--max-processes"])).flatMap((x) =>
      x.startsWith("npm:") ? runScripts([x.slice(4)], [ctx.nearest(wd)], wd, env, depth, ctx, a) : walk(x, { wd, env: { ...env }, stack: [] }, depth + 1, ctx));
  }
  if (b === "turbo") {
    const args = a.slice(1, a.includes("--") ? a.indexOf("--") : a.length);
    const pos = positionals(args, new Set(["--filter", "-F", "--concurrency", "--cache-dir", "--output-logs", "--log-order", "--env-mode"]));
    return runScripts(pos[0] === "run" ? pos.slice(1) : pos, ctx.pkgs, null, env, depth, ctx, a);
  }
  if (HELP.has(a.at(-1)) && a.length > 1 && !VALUE_OPTS.has(a.at(-2))) return [];
  const hits = [...checkScriptFile(a, wd, ctx), ...checkKit(a)];
  if (TOOLS[b]) hits.push(...TOOLS[b](a, env, wd, ctx));
  return hits;
}

// npx・pnpm dlx・npm exec など: 自分のオプションを飛ばし、@版 を外した bin を呼ぶ
function execBin(a, env, wd, depth, ctx) {
  const c = a.findIndex((x) => x === "-c" || x === "--call");
  if (c !== -1 && a[c + 1] && a.slice(0, c).every((x) => x.startsWith("-"))) return walk(a[c + 1], { wd, env, stack: [] }, depth + 1, ctx);
  const rest = a.slice(skipFlags(a, 0, EXEC_OPTS));
  if (!rest.length) return [];
  rest[0] = rest[0].replace(/(.)@[^/]*$/, "$1");
  return checkArgv(rest, env, wd, depth + 1, ctx);
}

// ---- パッケージマネージャ。対象のパッケージを決め、その中のスクリプトを開く
function checkPm(a, env, wd, depth, ctx) {
  const pm = base(a[0]);
  let targets = null, explicit = false, run = false, i = 1;
  const val = (x) => (x.includes("=") ? x.slice(x.indexOf("=") + 1) : a[++i] ?? "");
  for (; i < a.length; i++) {
    const x = a[i], f = x.split("=")[0];
    if (!run && (x === "run" || x === "run-script")) { run = true; continue; }
    if (pm === "yarn" && !run && x === "workspace") { targets = ctx.byName(a[++i] ?? "", wd); explicit = true; continue; }
    if (!x.startsWith("-")) break;
    if (["-C", "--dir", "--prefix", "--cwd"].includes(f)) { targets = [ctx.nearest(path.resolve(wd, val(x)))]; explicit = true; }
    else if (["--filter", "-F"].includes(f)) { targets = [...(targets ?? []), ...ctx.filter(val(x), wd)]; explicit = true; }
    else if (pm === "npm" && ["-w", "--workspace"].includes(f)) { targets = [...(targets ?? []), ...ctx.byName(val(x), wd)]; explicit = true; }
    else if (pm === "pnpm" && ["-w", "--workspace-root"].includes(f)) { targets = [ctx.pkgs[0]]; explicit = true; }
    else if (["-r", "--recursive", "--workspaces", "-ws"].includes(f)) { targets = ctx.pkgs; explicit = true; }
  }
  const name = a[i], rest = a.slice(i + 1);
  if (name === undefined) return [];
  const bwd = explicit && targets.length ? targets[0].dir : wd;
  if (["exec", "dlx", "x"].includes(name)) return execBin(rest, env, bwd, depth, ctx);
  if (name === "version" && pm !== "bun" && !a.includes("--no-git-tag-version")) return [hit("git-tag", a)];
  targets ??= [ctx.nearest(wd)];
  const hits = runScripts([name], targets, explicit ? null : wd, env, depth, ctx, a);
  // "kit": "node .kit/cli/kit.mjs" に、後ろの引数が渡る
  for (const p of targets) {
    if (typeof p.scripts[name] === "string" && /\bkit\b/.test(p.scripts[name]) && firstWord(rest) === "release") hits.push(hit("kit-release", a));
  }
  if (pm !== "npm" && !targets.some((p) => typeof p.scripts[name] === "string")) {
    hits.push(...checkArgv(pm === "bun" && FILE_RE.test(name) ? ["bun", name, ...rest] : [name, ...rest], env, bwd, depth + 1, ctx));
  }
  return hits;
}

// keepWd が null なら、各パッケージのディレクトリで開く
function runScripts(names, pkgs, keepWd, env, depth, ctx, argv) {
  const hits = [];
  for (const name of names) {
    if (isBlockedScriptName(name, ctx.cfg)) hits.push(hit("script", argv, `スクリプト ${name} は local の外に出るので、オーナーが流します（pnpm release / pnpm release:dev）`));
    for (const p of pkgs) {
      const body = p.scripts[name];
      if (typeof body !== "string") continue;
      const found = walk(body, { wd: keepWd ?? p.dir, env: { ...env }, stack: [] }, depth + 1, ctx);
      hits.push(...found.map((h) => ({ ...h, via: [name, ...(h.via ?? [])], cmd: argv.join(" ") })));
    }
  }
  return hits;
}

export function isBlockedScriptName(name, cfg = {}) {
  const R = rules().scripts;
  if ((cfg.blockScripts ?? []).includes(name)) return true;
  if ([...R.allowAlways, ...(cfg.allowScripts ?? [])].includes(name)) return false;
  const [verb, next] = name.split(/[:-]/);
  return R.blockVerbs.includes(verb) && (verb !== "push" || next === "convex");
}

const firstWord = (a) => a.find((x) => !x.startsWith("-"));

// kit のサブコマンドのうち、外に出るのは release だけ
function checkKit(a) {
  const i = a.findIndex((x) => KIT_RE.test(x));
  const isKit = i === 0 || (i > 0 && RUNNERS.has(base(a[0])));
  return isKit && firstWord(a.slice(i + 1)) === "release" ? [hit("kit-release", a)] : [];
}

// 止めるスクリプトが使うファイルを直接流す。そのファイルの、止めないスクリプトでの使い方（サブコマンド）だけ通す
function checkScriptFile(a, wd, ctx) {
  let i = 0;
  if (RUNNERS.has(base(a[0]))) {
    i = base(a[0]) === "bun" && a[1] === "run" ? 2 : 1;
    for (; i < a.length && a[i].startsWith("-"); i++) {
      if (["--test", "--check", "-n"].includes(a[i])) return [];
      if (RUNNER_OPTS.has(a[i])) i++;
    }
  } else if (!a[0].includes("/")) return [];
  const file = a[i];
  const use = file && ctx.files.get(path.resolve(wd, file));
  const sub = a.slice(i + 1).find((x) => !x.startsWith("-")) ?? "";
  if (!use || use.allowed.has(sub)) return [];
  return [hit("script-file", a, `${path.basename(file)} はリリース・デプロイのスクリプトの中身です。オーナーが流します`)];
}

// ---- git
function gitq(cwd, ...args) {
  try { return execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); }
  catch { return null; }
}
const currentBranch = (cwd) => gitq(cwd, "symbolic-ref", "--short", "-q", "HEAD") || null;

function refKind(name, cwd) {
  if (name.startsWith("refs/tags/")) return { tag: true };
  if (name.startsWith("refs/heads/")) return { branch: name.slice("refs/heads/".length) };
  if (gitq(cwd, "show-ref", "--verify", "--quiet", `refs/tags/${name}`) !== null) return { tag: true };
  if (gitq(cwd, "show-ref", "--verify", "--quiet", `refs/heads/${name}`) !== null) return { branch: name };
  return new RegExp(rules().git.tagPattern).test(name) ? { tag: true } : { branch: name };
}

function checkGit(a, env, wd) {
  const G = rules().git;
  const pushMain = (b) => hit("git-push-main", a, `${b} への直接 push はしません。PR を作って kit merge を通します`);
  let k = 1, gwd = wd;
  while (k < a.length && a[k].startsWith("-")) {
    if (a[k] === "-C") gwd = path.resolve(gwd, a[k + 1] ?? ".");
    k += GIT_GLOBAL_VALUE.has(a[k]) ? 2 : 1;
  }
  const sub = a[k], args = a.slice(k + 1);
  if (sub === "tag") {
    const readOnly = args.some((x) => TAG_READ.has(x.split("=")[0]) || /^(-n\d*$|--sort|--format)/.test(x));
    return !readOnly && positionals(args, TAG_VALUE).length ? [hit("git-tag", a)] : [];
  }
  if (sub !== "push") return [];
  const flags = new Set(), pos = [];
  for (let i = 0; i < args.length; i++) {
    const x = args[i];
    if (x === "--") { pos.push(...args.slice(i + 1)); break; }
    if (x.startsWith("-")) { flags.add(x.split("=")[0]); if (PUSH_VALUE.has(x)) i++; continue; }
    pos.push(x);
  }
  if (flags.has("--dry-run") || flags.has("-n")) return [];
  const hits = [];
  const all = flags.has("--all") || flags.has("--mirror");
  if (flags.has("--tags") || flags.has("--follow-tags")) hits.push(hit("git-push-tag", a));
  if (all) hits.push(pushMain(G.protectedBranches.join("・")));
  const del = flags.has("--delete") || flags.has("-d");
  let refs = pos.slice(1);
  if (!refs.length && !del && !all && !flags.has("--tags")) {
    const up = gitq(gwd, "rev-parse", "--abbrev-ref", "@{u}");
    refs = [up ? up.slice(up.indexOf("/") + 1) : currentBranch(gwd)].filter(Boolean);
  }
  for (const ref of refs) {
    const r = ref.replace(/^\+/, "");
    let dst = r.includes(":") ? r.slice(r.indexOf(":") + 1) : r;
    if (dst === "HEAD") dst = currentBranch(gwd);
    if (!dst) continue;
    const kind = refKind(dst, gwd);
    if (kind.tag && !del && !r.startsWith(":")) hits.push(hit("git-push-tag", a));
    if (kind.branch && G.protectedBranches.includes(kind.branch)) hits.push(pushMain(kind.branch));
  }
  return hits;
}

// ---- 外のサービス
function checkConvex(a, env, wd, ctx) {
  const args = a.slice(1);
  const pos = positionals(args, new Set(CONVEX_REMOTE));
  const sub = pos[0];
  if (sub === "deploy") return [hit("convex-write", a)];
  const write = ["run", "import"].includes(sub) || (sub === "env" && ["set", "remove", "unset"].includes(pos[1]));
  if (sub !== "dev" && !write) return [];
  const remote = "CONVEX_DEPLOY_KEY" in env || args.some((x) => x === "--prod" || CONVEX_REMOTE.includes(x.split("=")[0]));
  if (!remote) {
    const d = env.CONVEX_DEPLOYMENT ?? deploymentFromFiles(wd, ctx);
    if (d && rules().convex.localDeployments.some((p) => d.startsWith(p))) return [];
  }
  return [hit(sub === "dev" ? "convex-dev-remote" : "convex-remote-write", a)];
}
// wd からパッケージのディレクトリまで上りながら .env.local、.env を読む
function deploymentFromFiles(wd, ctx) {
  const top = ctx.nearest(wd).dir;
  for (let d = wd; ; d = path.dirname(d)) {
    for (const f of [".env.local", ".env"]) {
      const m = /^\s*(?:export\s+)?CONVEX_DEPLOYMENT\s*=\s*['"]?([^'"\s#]+)/m.exec(readText(path.join(d, f)) ?? "");
      if (m) return m[1];
    }
    if (d === top || !d.startsWith(top + path.sep)) return null;
  }
}

function checkWrangler(a) {
  const args = a.slice(1);
  if (args.includes("--dry-run")) return [];
  const pos = positionals(args, new Set(["--env", "-e", "-c", "--config", "--cwd"]));
  if (pos[0] === "dev") return [];
  const has = (...w) => w.some((x) => pos.includes(x));
  const out = has("deploy", "publish", "upload") || (pos.includes("secret") && has("put", "bulk")) ||
    (args.includes("--remote") && has("put", "execute", "apply", "create", "delete"));
  return out ? [hit("wrangler-remote", a)] : [];
}

function checkEas(a) {
  const sub = positionals(a.slice(1), new Set(["-p", "--platform", "--profile", "-e", "--environment"]))[0];
  if (sub === "build" && a.includes("--local")) return [];
  return ["build", "submit", "update", "deploy", "upload", "workflow:run"].includes(sub) ? [hit("eas-remote", a)] : [];
}

function checkGh(a) {
  const [x, y] = positionals(a.slice(1), GH_VALUE);
  if ((x === "release" && ["create", "edit", "upload", "delete"].includes(y)) || (x === "workflow" && y === "run")) return [hit("gh-release", a)];
  if (x === "pr" && y === "merge") return [hit("gh-pr-merge", a)];
  if (x !== "api" || !y) return [];
  let method = null;
  a.forEach((z, k) => {
    if (z === "-X" || z === "--method") method = a[k + 1];
    else if (z.startsWith("--method=")) method = z.slice(9);
    else if (/^-X./.test(z)) method = z.slice(2);
  });
  const fields = a.some((z) => /^(-f|-F|--field|--raw-field|--input)(=|$)/.test(z) || /^-[fF]./.test(z));
  const write = method ? method.toUpperCase() !== "GET" : fields;
  if (!write || !/\/merge|\/releases|\/git\/refs|\/deployments|\/dispatches/.test(y)) return [];
  return [hit(/\/merge/.test(y) ? "gh-pr-merge" : "gh-release", a)];
}

function checkMake(a) {
  const re = new RegExp(rules().make.targetPattern);
  for (let i = 1; i < a.length; i++) {
    const x = a[i];
    if (["-C", "-f", "--file", "--directory", "-I", "-o", "-W"].includes(x)) { i++; continue; }
    if (x === "-j" || x === "--jobs") { if (/^\d+$/.test(a[i + 1] ?? "")) i++; continue; }
    if (!x.startsWith("-") && !x.includes("=") && re.test(x)) return [hit("make-release", a)];
  }
  return [];
}

// ---- リポジトリの文脈: workspace のパッケージ {dir, name, scripts} と、止めるスクリプトが使うファイル
const ctxCache = new Map();
function repoContext(root, cfg) {
  const key = root + JSON.stringify(cfg);
  if (ctxCache.has(key)) return ctxCache.get(key);
  const readPkg = (dir) => {
    const j = safeJson(readText(path.join(dir, "package.json")));
    if (!j || typeof j !== "object") return null;
    return { dir, name: typeof j.name === "string" ? j.name : null, scripts: j.scripts && typeof j.scripts === "object" ? j.scripts : {} };
  };
  const rootPkg = readPkg(root) ?? { dir: root, name: null, scripts: {} };
  const pkgs = [rootPkg];
  for (const g of workspaceGlobs(root)) {
    if (g.startsWith("!")) continue;
    const pat = g.replace(/^\.\//, "").replace(/\/+$/, "");
    const m = /^(.*)\/\*\*?$/.exec(pat);
    const dirs = m ? listDirs(path.join(root, m[1])) : [path.join(root, pat)];
    for (const dir of dirs) {
      if (pkgs.some((p) => p.dir === dir)) continue;
      const p = readPkg(dir);
      if (p) pkgs.push(p);
    }
  }
  const uses = new Map();
  for (const p of pkgs) {
    for (const [name, body] of Object.entries(p.scripts)) {
      if (typeof body !== "string") continue;
      const blocked = isBlockedScriptName(name, cfg);
      for (const { words } of parse(body).cmds) {
        words.forEach((x, k) => {
          if (!FILE_RE.test(x) || KIT_RE.test(x)) return;
          const f = path.resolve(p.dir, x);
          const e = uses.get(f) ?? { blocked: false, allowed: new Set() };
          uses.set(f, e);
          if (blocked) e.blocked = true;
          else e.allowed.add(words.slice(k + 1).find((y) => !y.startsWith("-")) ?? "");
        });
      }
    }
  }
  const inside = (wd, dir) => wd === dir || wd.startsWith(dir + path.sep);
  const ctx = {
    root,
    cfg,
    pkgs,
    files: new Map([...uses].filter(([, e]) => e.blocked)),
    nearest: (wd) => pkgs.filter((p) => inside(wd, p.dir)).sort((x, y) => y.dir.length - x.dir.length)[0] ?? rootPkg,
    byName: (n, wd) => pkgs.filter((p) => p.name === n || p.dir === path.resolve(wd, n)),
    filter: (f, wd) => {
      const s = f.replace(/^\.\.\.|\.\.\.$/g, "").replace(/^\^/, "").replace(/^\{(.*)\}$/, "$1");
      if (s.startsWith(".") || s.startsWith("/")) { const re = globRe(path.resolve(wd, s)); return pkgs.filter((p) => re.test(p.dir)); }
      const re = globRe(s);
      return pkgs.filter((p) => p.name && re.test(p.name));
    },
  };
  ctxCache.set(key, ctx);
  return ctx;
}
function workspaceGlobs(root) {
  const yaml = readText(path.join(root, "pnpm-workspace.yaml"));
  const ws = safeJson(readText(path.join(root, "package.json")))?.workspaces;
  const fromYaml = yaml ? [...yaml.matchAll(/^\s*-\s*['"]?([^'"\s#]+)['"]?/gm)].map((m) => m[1]) : [];
  const fromPkg = Array.isArray(ws) ? ws : Array.isArray(ws?.packages) ? ws.packages : [];
  const all = [...fromYaml, ...fromPkg].filter((g) => typeof g === "string");
  return yaml || ws ? all : ["apps/*", "packages/*"];
}
function listDirs(d) {
  try { return fs.readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => path.join(d, e.name)); }
  catch { return []; }
}

function findRepoRoot(cwd) { return gitq(cwd, "rev-parse", "--show-toplevel"); }
const real = (p) => { try { return fs.realpathSync(p); } catch { return p; } };

// 当たったものを全部返す
export function checkAll(command, { cwd = process.cwd(), root, cfg = {} } = {}) {
  cwd = real(path.resolve(cwd));
  root = real(root ?? findRepoRoot(cwd) ?? cwd);
  return walk(command, { wd: cwd, env: {}, stack: [] }, 0, repoContext(root, cfg));
}
export const check = (command, opts) => checkAll(command, opts)[0] ?? null;

function loadGuardConfig(root) {
  let text;
  try { text = fs.readFileSync(path.join(root, "kit.config.json"), "utf8"); }
  catch (e) { if (e.code === "ENOENT") return {}; throw e; }
  const guard = JSON.parse(text).guard ?? {};
  const schema = JSON.parse(fs.readFileSync(new URL("../../schemas/kit.config.schema.json", import.meta.url), "utf8"));
  const errs = validate(schema.properties.guard, guard, "guard");
  if (errs.length) throw new Error(`kit.config.json の ${errs.join("、")}`);
  return guard;
}

// ---- CLI
export async function main(args = []) {
  try { return run(args); }
  catch (e) {
    process.stderr.write(`kit guard: guard 自体が落ちたので止めました: ${e.message}\n`);
    return 2;
  }
}

function run(args) {
  let command = flag(args, "--cmd");
  let cwd = path.resolve(flag(args, "--cwd") ?? process.cwd());
  if (command === undefined) {
    let payload;
    try { payload = JSON.parse(fs.readFileSync(0, "utf8")); } catch { return 0; }
    if (payload?.tool_name && payload.tool_name !== "Bash") return 0;
    command = payload?.tool_input?.command;
    if (typeof command !== "string") return 0;
    if (typeof payload.cwd === "string") cwd = payload.cwd;
  }
  rules();
  const root = findRepoRoot(cwd) ?? cwd;
  const cfg = loadGuardConfig(root);
  const warn = cfg.warn ?? [];
  const hits = checkAll(command, { cwd, root, cfg });
  const lines = new Set(hits.map((h) => {
    const via = h.via ? `（${h.via.join(" → ")} の中）` : "";
    return warn.includes(h.id)
      ? `kit guard: 警告（${h.id}）${via}: ${h.why}。今は警告だけで通します\n  ${h.cmd}\n`
      : `kit guard: 止めました（${h.id}）${via}: ${h.why}\n  ${h.cmd}\n`;
  }));
  for (const l of lines) process.stderr.write(l);
  return hits.some((h) => !warn.includes(h.id)) ? 2 : 0;
}
