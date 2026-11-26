// kit sync [--into <repo>] [--to <tag>]
// kit の clone（KIT_SOURCE か kit.config.json の source）から、範囲に合う最新のタグを選び、
// <repo>/.kit にコピーして kit.lock を書く。前の kit.lock に無いものは上書きしない（ADR-001）。
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  git, gits, sha, readJson, expandHome, flag, parseSemver, cmp, satisfies,
  agentsBlockText, stripAgentsBlock, readYanked, MANDATORY, receivedPaths, WORKFLOW, skillLink, skillTarget,
} from "../lib.mjs";
import { validate, configRules } from "../schema.mjs";

const DEFAULT_SOURCE = "~/yuto/kit";

export async function main(args) {
  const into = path.resolve(flag(args, "--into") ?? process.cwd());
  let cfg;
  try { cfg = readJson(path.join(into, "kit.config.json")); }
  catch (e) { console.error(`kit sync: kit.config.json が読めません（${e.message}）`); return 2; }
  const src = expandHome(process.env.KIT_SOURCE || cfg.source || DEFAULT_SOURCE);
  try { gits(src, "fetch", "--tags", "--quiet", "origin"); }
  catch { console.error(`kit sync: kit の clone ${src} から fetch できません`); return 1; }

  const yanked = readYanked(src);
  let tag = flag(args, "--to");
  if (!tag) {
    let candidates;
    try {
      candidates = gits(src, "tag", "-l", "v*").split("\n").filter(Boolean)
        .map((t) => [t, parseSemver(t)])
        .filter(([t, v]) => v && satisfies(v, cfg.range ?? "") && !yanked.has(t))
        .sort((a, b) => cmp(a[1], b[1]));
    } catch (e) { console.error(`kit sync: ${e.message}`); return 2; }
    if (!candidates.length) { console.error(`kit sync: 範囲 ${cfg.range} に入るタグがありません`); return 1; }
    tag = candidates.at(-1)[0];
  }
  if (yanked.has(tag)) { console.error(`kit sync: ${tag} は取り下げられています（kit の YANKED）`); return 1; }
  let commit;
  try { commit = gits(src, "rev-list", "-n1", tag); }
  catch { console.error(`kit sync: タグ ${tag} がありません`); return 1; }

  // 何をどう置くかは、入れる版の sync が決める
  const own = gits(src, "ls-tree", "-r", "--name-only", tag, "--", ...MANDATORY).split("\n").filter(Boolean);
  if (!own.every((f) => sameAsRunning(f, git(src, "show", `${tag}:${f}`)))) return runTargetSync(src, tag, own, into);

  const schema = JSON.parse(gits(src, "show", `${tag}:schemas/kit.config.schema.json`));
  const bad = validate(schema, cfg);
  const cfgErrs = bad.length ? bad : configRules(cfg);
  if (cfgErrs.length) { for (const e of cfgErrs) console.error(`kit sync: kit.config.json: ${e}`); return 2; }

  const receive = cfg.receive ?? [];
  const skills = cfg.skills ?? [];
  let prev = { files: {}, links: {} };
  const hadLock = fs.existsSync(path.join(into, "kit.lock"));
  if (hadLock) prev = readJson(path.join(into, "kit.lock"));

  // リポジトリの持ち物は上書きしない
  const conflicts = [];
  if (!hadLock && fs.existsSync(path.join(into, ".kit"))) conflicts.push(".kit/");
  for (const s of skills) {
    const rel = skillLink(s);
    let st = null;
    try { st = fs.lstatSync(path.join(into, rel)); } catch {}
    if (st && !(st.isSymbolicLink() && prev.links[rel])) conflicts.push(rel);
  }
  if (receive.includes("ci") && fs.existsSync(path.join(into, WORKFLOW)) && !prev.files[WORKFLOW]) conflicts.push(WORKFLOW);
  if (conflicts.length) {
    console.error("kit sync: 次はリポジトリの持ち物なので上書きしません。先に消す PR を出すか、kit.config.json から外してください:");
    for (const c of conflicts) console.error(`  ${c}`);
    return 3;
  }

  // 取り出すパス（tag の中のパス）
  const entries = [];
  for (const w of receivedPaths(cfg)) {
    const list = gits(src, "ls-tree", "-r", "--name-only", tag, "--", w).split("\n").filter(Boolean);
    if (!list.length) { console.error(`kit sync: ${tag} に ${w} がありません`); return 1; }
    entries.push(...list);
  }

  // 書き込み。前の版が置いたものを片付けてから置き直す
  const kitDir = path.join(into, ".kit");
  fs.rmSync(kitDir, { recursive: true, force: true });
  for (const rel of Object.keys(prev.links)) fs.rmSync(path.join(into, rel), { force: true });
  if (prev.files[WORKFLOW]) fs.rmSync(path.join(into, WORKFLOW), { force: true });

  const files = {};
  for (const f of entries) {
    const buf = git(src, "show", `${tag}:${f}`);
    const dst = path.join(kitDir, f);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.writeFileSync(dst, buf);
    files[`.kit/${f}`] = sha(buf);
  }
  if (receive.includes("ci")) {
    const buf = fs.readFileSync(path.join(kitDir, `ci/kit-ci.${cfg.runtime}.yml`));
    fs.mkdirSync(path.join(into, path.dirname(WORKFLOW)), { recursive: true });
    fs.writeFileSync(path.join(into, WORKFLOW), buf);
    files[WORKFLOW] = sha(buf);
  }
  const agentsPath = path.join(into, "AGENTS.md");
  if (receive.includes("agents")) {
    const block = agentsBlockText(tag, fs.readFileSync(path.join(kitDir, "agents/AGENTS.base.md"), "utf8"));
    const text = fs.existsSync(agentsPath) ? fs.readFileSync(agentsPath, "utf8") : "";
    const re = /<!-- kit:begin [^>]*-->[\s\S]*?<!-- kit:end -->/;
    fs.writeFileSync(agentsPath, re.test(text) ? text.replace(re, block) : `${block}\n\n${text}`);
    files["AGENTS.md#kit"] = sha(Buffer.from(block));
  } else if (prev.files["AGENTS.md#kit"] && fs.existsSync(agentsPath)) {
    const t = stripAgentsBlock(fs.readFileSync(agentsPath, "utf8"));
    t.trim() ? fs.writeFileSync(agentsPath, t) : fs.rmSync(agentsPath);
  }
  const links = {};
  for (const s of skills) {
    const l = path.join(into, skillLink(s));
    fs.mkdirSync(path.dirname(l), { recursive: true });
    fs.symlinkSync(skillTarget(s), l);
    links[skillLink(s)] = skillTarget(s);
  }
  fs.writeFileSync(path.join(into, "kit.lock"), JSON.stringify({ version: tag, commit, files, links }, null, 2) + "\n");
  console.log(`kit sync: ${tag}（${commit.slice(0, 7)}）を入れました。ファイル ${Object.keys(files).length}、symlink ${Object.keys(links).length}`);
  return 0;
}

const RUNNING = path.resolve(import.meta.dirname, "../..");
const sameAsRunning = (f, buf) => fs.existsSync(path.join(RUNNING, f)) && buf.equals(fs.readFileSync(path.join(RUNNING, f)));

function runTargetSync(src, tag, own, into) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "kit-sync-"));
  try {
    for (const f of own) {
      const dst = path.join(dir, f);
      fs.mkdirSync(path.dirname(dst), { recursive: true });
      fs.writeFileSync(dst, git(src, "show", `${tag}:${f}`));
    }
    return spawnSync(process.execPath, [path.join(dir, "cli/kit.mjs"), "sync", "--into", into, "--to", tag], { stdio: "inherit" }).status ?? 1;
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
