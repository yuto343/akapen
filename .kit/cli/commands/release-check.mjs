// kit release-check <タグ> --to <dev|production> : そのタグを出してよいかを見る。読むだけ。
// まだ無いタグは、HEAD に打つものとして見る。
import { gits } from "../lib.mjs";
import { releaseEnv } from "./env.mjs";
import * as R from "../release.mjs";

const USAGE = "kit release-check <タグ> --to <dev|production>";
const ENV = { dev: "dev", production: "prod" };
const PASSED = ["success", "neutral", "skipped"];

export async function main(args) {
  const [tag, to, name] = args;
  if (args.length !== 3 || tag.startsWith("-") || to !== "--to" || !Object.hasOwn(ENV, name)) { console.error(USAGE); return 64; }
  let errs;
  try {
    const root = R.repoRoot(), rel = R.loadRelease(root);
    R.fetchTrunk(root);
    errs = [...treeProblems(root), ...tagProblems(root, rel, tag, ENV[name])];
  } catch (e) { console.error(`kit release-check: 判定できません（${firstLine(e)}）`); return 2; }
  for (const e of errs) console.error(`kit release-check: ${e}`);
  console.log(`kit release-check: ${tag} は ${name} に${errs.length ? "出せません" : "出せます"}`);
  return errs.length ? 1 : 0;
}

export const firstLine = (e) => (e.stderr?.toString() || e.message).trim().split("\n")[0];

export const treeProblems = (root) => (gits(root, "status", "--porcelain") ? ["commit していない変更があります"] : []);
export const trunkProblems = (root) => (gits(root, "rev-parse", "HEAD") === gits(root, "rev-parse", "origin/main") ? [] : ["HEAD が origin/main の最新ではありません"]);

export function tagProblems(root, rel, tag, env) {
  const t = R.parseTag(rel, tag);
  if (!t) return [`${tag} は kit.config.json の release の形のタグではありません`];
  const rec = R.readRecord(root, rel, tag), local = R.tagCommit(root, tag);
  const commit = local ?? rec?.commit ?? gits(root, "rev-parse", "HEAD");
  const errs = local || rec ? [] : trunkProblems(root);

  const remote = R.remoteTags(root);
  for (const ref of [tag, R.refOf(env, tag)]) {
    if ([R.tagCommit(root, ref), remote.get(ref)].some((c) => c && c !== commit)) errs.push(`タグ ${ref} は別の commit を指しています`);
  }
  if (rec && rec.commit !== commit) errs.push(`${tag} の記録は別の commit のものです`);
  if (!R.isAncestor(root, commit, "origin/main")) errs.push(`${commit.slice(0, 7)} は origin/main に入っていません`);
  try {
    const e = releaseEnv(root, commit, t.surface);
    if (e.version !== t.version) errs.push(`${t.surface} の版は ${e.version} です`);
    errs.push(...e.problems);
  } catch (e) { errs.push(e.message); }
  errs.push(...ciProblems(root, commit), ...prProblems(root, rel, t.surface, commit), ...R.placeProblems(R.placeOf(root, env, commit), commit));
  if (env === "prod") errs.push(...devProblems(rel, t.surface, rec));
  return [...new Set(errs)];
}

// 同じ workflow が何度も流れていたら、新しいものだけを見る
function ciProblems(root, commit) {
  const latest = {};
  for (const r of R.gh(root, "run", "list", "--commit", commit, "--limit", "100", "--json", "workflowName,status,conclusion,createdAt")) {
    if (!latest[r.workflowName] || latest[r.workflowName].createdAt < r.createdAt) latest[r.workflowName] = r;
  }
  const errs = latest["kit-ci"] ? [] : [`${commit.slice(0, 7)} で kit-ci が流れていません`];
  for (const r of Object.values(latest)) if (!PASSED.includes(r.conclusion)) errs.push(`CI: ${r.workflowName} が ${r.conclusion || r.status}`);
  return errs;
}

// 前のタグに risk.config.json があれば、そこから先は全部 PR を通っているはず
function prProblems(root, rel, surface, commit) {
  const prev = R.previousTag(root, rel, surface, "dev", commit);
  if (!prev || !gits(root, "ls-tree", "--name-only", prev, "risk.config.json")) return [];
  return R.mergedIn(root, prev, commit).filter((c) => !c.pr).map((c) => `${c.oid.slice(0, 7)} は PR を通っていません（${c.subject}）`);
}

function devProblems(rel, surface, rec) {
  if (!rec?.dev) return ["dev の記録がありません（先に kit release dev で出します）"];
  const errs = R.stepsFor(rel, "dev", surface).filter((s) => rec.dev.steps[s.name]?.status !== "done").map((s) => `dev の ${s.name} が済んでいません`);
  if (!rec.dev.pushedAt) errs.push("dev のタグの push が済んでいません");
  return errs;
}
