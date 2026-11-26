// kit release・release-check・notes が共有する、設定、タグ、記録、PR の一覧
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { gits, readJson, sha } from "./lib.mjs";
import { validate, configRules } from "./schema.mjs";

export function repoRoot() {
  try { return gits(process.cwd(), "rev-parse", "--show-toplevel"); } catch { throw new Error("git のリポジトリではありません"); }
}

export function loadRelease(root) {
  let cfg;
  try { cfg = readJson(path.join(root, "kit.config.json")); } catch (e) { throw new Error(`kit.config.json: 読めません（${e.message}）`); }
  const errs = validate(readJson(new URL("../schemas/kit.config.schema.json", import.meta.url)), cfg);
  if (!errs.length) errs.push(...configRules(cfg));
  if (errs.length) throw new Error(`kit.config.json: ${errs.join(" / ")}`);
  if (!cfg.release) throw new Error("kit.config.json に release がありません");
  return cfg.release;
}

export const stepsFor = (rel, env, surface) => rel[env].steps.filter((s) => !s.surfaces || s.surfaces.includes(surface));

// --- タグ。通常のタグは tagPattern、印のタグは prod/<タグ>
export const refOf = (env, tag) => (env === "prod" ? `prod/${tag}` : tag);
export const tagName = (rel, surface, version) => rel.tagPattern.replace("{surface}", surface).replace("{version}", version);
export function parseTag(rel, tag) {
  for (const surface of rel.surfaces) {
    const [a, b] = rel.tagPattern.replace("{surface}", surface).split("{version}");
    const m = tag.startsWith(a) && tag.endsWith(b) && /^\d+\.\d+\.\d+$/.exec(tag.slice(a.length, tag.length - b.length));
    if (m) return { surface, version: m[0] };
  }
  return null;
}
export function newestTag(root, rel, surface) {
  const all = gits(root, "tag", "-l", "--sort=-v:refname", tagName(rel, surface, "*")).split("\n");
  return all.find((t) => parseTag(rel, t)?.surface === surface) ?? null;
}
// 出し終えたタグだけを見る。push は最後なので、origin に無いタグは出していない
export function previousTag(root, rel, surface, env, commit) {
  let list;
  try { list = gits(root, "tag", "--merged", `${commit}^`, "--sort=-v:refname", "-l", refOf(env, tagName(rel, surface, "*"))).split("\n").filter(Boolean); } catch { return null; }
  const remote = remoteTags(root);
  return list.find((t) => remote.has(t)) ?? null;
}
export function commitOf(root, ref) {
  try { return gits(root, "rev-parse", "--verify", "--quiet", `${ref}^{commit}`); } catch { return null; }
}
export const tagCommit = (root, tag) => commitOf(root, `refs/tags/${tag}`);
// origin のタグ → commit。注釈付きのタグは ^{} の行が後に来て上書きする
export function remoteTags(root) {
  const out = new Map();
  for (const l of gits(root, "ls-remote", "--tags", "origin").split("\n").filter(Boolean)) {
    const [c, ref] = l.split("\t");
    out.set(ref.slice("refs/tags/".length).replace(/\^\{\}$/, ""), c);
  }
  return out;
}
export const fetchTrunk = (root) => gits(root, "fetch", "--quiet", "origin", "+refs/heads/main:refs/remotes/origin/main");
export function isAncestor(root, a, b) {
  try { gits(root, "merge-base", "--is-ancestor", a, b); return true; } catch { return false; }
}

// --- 記録: {tag, commit, dev: {steps: {<name>: {status, at}}, pushedAt}, prod: 同じ形}。どの worktree から流しても同じ場所を見る
const mainRoot = (root) => path.dirname(gits(root, "rev-parse", "--path-format=absolute", "--git-common-dir"));
const recordDir = (root, rel) => path.join(mainRoot(root), rel.records ?? ".release");
export const recordPath = (root, rel, tag) => path.join(recordDir(root, rel), `${tag}.json`);
export function readRecord(root, rel, tag) {
  const p = recordPath(root, rel, tag);
  return fs.existsSync(p) ? readJson(p) : null;
}
export function writeRecord(root, rel, rec) {
  const p = recordPath(root, rel, rec.tag);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(path.join(path.dirname(p), ".gitignore"), "*\n");
  fs.writeFileSync(`${p}.tmp`, JSON.stringify(rec, null, 2) + "\n");
  fs.renameSync(`${p}.tmp`, p);
}

// --- 排他。kit が死んでも step が生き残ることがあるので、step の pid も見る
const alive = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === "EPERM"; } };
export function lock(root, rel) {
  const dir = recordDir(root, rel), at = path.join(dir, ".lock"), step = path.join(dir, ".step-pid");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, ".gitignore"), "*\n");
  const pidIn = (p) => { try { return Number(fs.readFileSync(p, "utf8")) || null; } catch { return null; } };
  const busy = () => [pidIn(at), pidIn(step)].find((pid) => pid && alive(pid));
  for (let i = 0; i < 2; i++) {
    const pid = busy();
    if (pid) throw new Error(`ほかの kit release か、その step が流れています（pid ${pid}）。終わってから流してください。動いていないと確かめたら ${at} と ${step} を消してください`);
    try {
      fs.writeFileSync(at, `${process.pid}\n`, { flag: "wx" });
      fs.rmSync(step, { force: true });
      return { stepPid: step, unlock: () => fs.rmSync(at, { force: true }) };
    } catch (e) {
      if (e.code !== "EEXIST") throw e;
      fs.rmSync(at, { force: true });
    }
  }
  throw new Error("ほかの kit release が同時に始まりました");
}

// --- 出す場所（タグの使い捨ての worktree）。続きから流せるよう、OS に消される一時ディレクトリには置かない
export function placeOf(root, env, commit) {
  const main = mainRoot(root);
  return path.join(os.homedir(), ".kit/release", `${path.basename(main)}-${sha(main).slice(0, 8)}`, `${env}-${commit.slice(0, 12)}`);
}
export function placeProblems(dir, commit) {
  if (!fs.existsSync(dir)) return [];
  let head = null, dirty = "";
  try {
    head = gits(dir, "rev-parse", "HEAD");
    dirty = gits(dir, "status", "--porcelain", "--untracked-files=no");
  } catch {}
  if (head !== commit) return [`作業場所 ${dir} が ${commit.slice(0, 7)} ではありません`];
  if (dirty) return [`作業場所 ${dir} の、git に入っているファイルが変わっています（git -C ${dir} diff で確かめ、要らなければ git -C ${dir} restore . で戻す）`];
  return envLocalProblems(dir);
}
export function envLocalProblems(dir) {
  const env = gits(dir, "ls-files", "--others", "-z", "--", ":(glob)**/.env.local", ":(glob)**/.env.*.local").split("\0");
  // 空のファイルは何も上書きしない（ashvally の push:convex:dev が空の .env.local を残す）
  return env.filter((f) => f && !f.includes("node_modules/") && fs.statSync(path.join(dir, f)).size > 0)
    .map((f) => `作業場所 ${dir} に未追跡の ${f} があります（.env.production より先に読まれます）`);
}

// --- GitHub（読むだけ）
export const gh = (root, ...a) => JSON.parse(execFileSync("gh", a, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 1 << 28 }));

// 範囲の first-parent の commit と、それを merge した PR（無ければ null）。古い順
export function mergedIn(root, from, to) {
  const commits = gits(root, "log", "--first-parent", "--reverse", "--format=%H%x09%s", `${from}..${to}`).split("\n").filter(Boolean).map((l) => l.split("\t"));
  if (!commits.length) return [];
  const prs = gh(root, "pr", "list", "--state", "merged", "--base", "main", "--limit", "1000", "--json", "number,title,body,mergeCommit");
  return commits.map(([oid, subject]) => ({ oid, subject, pr: prs.find((p) => p.mergeCommit?.oid === oid) ?? null }));
}
