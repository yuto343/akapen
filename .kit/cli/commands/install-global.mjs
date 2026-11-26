// kit install-global [--remove]（kit の clone で流す）
// ユーザー全体のスキルを、この clone の skills/ への symlink にする。Codex の hooks.json に guard の shim を 1 つ足す（ADR-007、P-07）。
// 置き換えるものは <設定の場所>/kit-backup/<日時>/ に移す。--remove は、自分の symlink と shim だけを消し、バックアップを戻す。
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";

const KIT = path.resolve(import.meta.dirname, "../..");
const SKILLS = ["direct", "close", "merge-and-close"];
const BACKUP = "kit-backup";

// 自分の shim を、中身が変わった後の版からも見分ける印。`:` は何もしないコマンド
const MARK = ": kit install-global;";
// 動かすのはこの clone の guard だけ。リポジトリの .kit/ を動かすと、他人の clone を開いただけでその中のコードが動く。
// guard を受け取っていないリポジトリでは 0。受け取っていれば、guard が落ちても node が無くても 2 で止める。
// リポジトリは payload の cwd で決める（Codex 0.172 は workdir つきの呼び出しでも、フックをセッションの cwd で動かす）
const shQuote = (p) => `'${p.replaceAll("'", `'\\''`)}'`;
const SHIM = {
  matcher: "Bash",
  hooks: [{
    type: "command",
    command: `${MARK} i=$(cat); d=$(printf %s "$i" | sed -n 's/.*"cwd" *: *"\\([^"]*\\)".*/\\1/p'); r=$(git -C "\${d:-.}" rev-parse --show-toplevel 2>/dev/null) && grep -q '"\\.kit/guard/' "$r/kit.lock" 2>/dev/null || exit 0; printf %s "$i" | node ${shQuote(path.join(KIT, "cli/kit.mjs"))} guard || exit 2`,
    timeout: 30,
  }],
};

const lstat = (p) => fs.lstatSync(p, { throwIfNoEntry: false });
const isObj = (x) => typeof x === "object" && x !== null && !Array.isArray(x);

function parseHooks(text) {
  const j = JSON.parse(text);
  const groups = isObj(j) ? (j.hooks ?? {}).PreToolUse ?? [] : null;
  if (!isObj(j) || !isObj(j.hooks ?? {}) || !Array.isArray(groups) || !groups.every((g) => isObj(g) && Array.isArray(g.hooks))) throw new Error("フックの形ではありません");
  return j;
}
const isShim = (x) => typeof x?.command === "string" && x.command.startsWith(MARK);
const hasShim = (j) => (j.hooks?.PreToolUse ?? []).some((g) => g.hooks.some(isShim));
function withoutShim(j) {
  if (!hasShim(j)) return j;
  const groups = j.hooks.PreToolUse
    .map((g) => (g.hooks.some(isShim) ? { ...g, hooks: g.hooks.filter((x) => !isShim(x)) } : g))
    .filter((g, i) => g.hooks.length || !j.hooks.PreToolUse[i].hooks.length);
  return { ...j, hooks: { ...j.hooks, PreToolUse: groups } };
}
// Codex はフックの信頼を位置で覚えているので、今あるフックの位置が変わらないように最後に足す
function withShim(j) {
  const rest = withoutShim(j);
  return { ...rest, hooks: { ...rest.hooks, PreToolUse: [...(rest.hooks?.PreToolUse ?? []), SHIM] } };
}
const format = (j, like) => JSON.stringify(j, null, /\n([ \t]+)"/.exec(like)?.[1] ?? 2) + (like.endsWith("\n") || !like ? "\n" : "");

function backups(home, rel) {
  const dir = path.join(home, BACKUP);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).sort().map((d) => path.join(dir, d, rel)).filter((p) => lstat(p));
}
function backupPath(home, stamp, rel) {
  const p = path.join(home, BACKUP, stamp, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  return p;
}
function pruneBackups(home) {
  const dir = path.join(home, BACKUP);
  for (const d of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
    for (const p of [path.join(dir, d, "skills"), path.join(dir, d)]) try { fs.rmdirSync(p); } catch {}
  }
  try { fs.rmdirSync(dir); } catch {}
}

function installSkill(home, name, stamp) {
  const rel = path.join("skills", name), at = path.join(home, rel), want = path.join(KIT, "skills", name);
  const st = lstat(at);
  if (st?.isSymbolicLink() && fs.readlinkSync(at) === want) return;
  if (st) {
    const to = backupPath(home, stamp, rel);
    fs.renameSync(at, to);
    console.log(`バックアップ: ${at} → ${to}`);
  }
  fs.mkdirSync(path.dirname(at), { recursive: true });
  fs.symlinkSync(want, at);
  console.log(`symlink: ${at} → ${want}`);
}
function removeSkill(home, name) {
  const rel = path.join("skills", name), at = path.join(home, rel);
  const st = lstat(at);
  if (st?.isSymbolicLink() && fs.readlinkSync(at) === path.join(KIT, "skills", name)) {
    fs.unlinkSync(at);
    console.log(`消した: ${at}`);
  } else if (st) return;
  const last = backups(home, rel).at(-1);
  if (!last) return;
  fs.renameSync(last, at);
  console.log(`戻した: ${at}`);
}

function installHook(home, stamp, text) {
  const at = path.join(home, "hooks.json");
  const cur = text === null ? {} : parseHooks(text);
  const next = withShim(cur);
  if (isDeepStrictEqual(cur, next)) return;
  if (text !== null && !hasShim(cur)) fs.copyFileSync(at, backupPath(home, stamp, "hooks.json"));
  fs.writeFileSync(at, format(next, text ?? ""));
  console.log(`shim を足した: ${at}（次に Codex を開いたとき、フックの信頼を 1 回承認する）`);
}
function removeHook(home, text) {
  const at = path.join(home, "hooks.json");
  if (text === null) return;
  const cur = parseHooks(text);
  if (!hasShim(cur)) return;
  // install の後にほかの変更が無ければ、元のバイト列に戻す
  const last = backups(home, "hooks.json").at(-1);
  const orig = last ? fs.readFileSync(last, "utf8") : null;
  if (!isDeepStrictEqual(withoutShim(cur), withoutShim(withShim(orig === null ? {} : parseHooks(orig))))) fs.writeFileSync(at, format(withoutShim(cur), text));
  else if (orig === null) fs.rmSync(at);
  else { fs.writeFileSync(at, orig); fs.rmSync(last); }
  console.log(`shim を消した: ${at}`);
}

export async function main(args) {
  if (args.some((a) => a !== "--remove")) { console.error("使い方: kit install-global [--remove]"); return 64; }
  // .kit のコピーと、消えることのある worktree には、symlink を張らない
  if (!lstat(path.join(KIT, ".git"))?.isDirectory() || SKILLS.some((s) => !fs.existsSync(path.join(KIT, "skills", s, "SKILL.md")))) {
    console.error(`kit install-global: ${KIT} は kit の clone ではありません。clone の cli/kit.mjs で流してください`);
    return 1;
  }
  const codex = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
  const claude = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
  const homes = [claude, codex].filter((d) => fs.existsSync(d) || console.log(`飛ばす: ${d} がありません`));
  const hooksAt = path.join(codex, "hooks.json");
  const text = lstat(hooksAt) ? fs.readFileSync(hooksAt, "utf8") : null;
  try { if (text !== null) parseHooks(text); }
  catch (e) { console.error(`kit install-global: ${hooksAt} が読めないので、何も書きません（${e.message}）`); return 2; }

  if (args.length) {
    for (const home of homes) for (const s of SKILLS) removeSkill(home, s);
    if (homes.includes(codex)) removeHook(codex, text);
    for (const home of homes) {
      pruneBackups(home);
      for (const rel of [...SKILLS.map((s) => path.join("skills", s)), "hooks.json"]) for (const p of backups(home, rel)) console.log(`バックアップが残っています: ${p}`);
    }
    return 0;
  }
  const stamp = new Date().toISOString().replace(/[-:]/g, "");
  for (const home of homes) for (const s of SKILLS) installSkill(home, s, stamp);
  if (homes.includes(codex)) installHook(codex, stamp, text);
  return 0;
}
