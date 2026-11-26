// kit merge <pr> : PR の状態、CI、risk、head の証拠がすべて揃ったときだけ gh pr merge する。
// 揃わなければ理由を出して 1 で終わる。review の PR は、オーナーが GitHub で merge する。
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { gits, readJson } from "../lib.mjs";
import { risk } from "./risk.mjs";

const FIELDS = "number,state,isDraft,isCrossRepository,baseRefName,headRefName,headRefOid,mergeable,statusCheckRollup";
const PASSED = ["SUCCESS", "NEUTRAL", "SKIPPED"];
const gh = (root, ...a) => execFileSync("gh", a, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });

export async function main(args) {
  const [pr, ...rest] = args;
  if (!/^\d+$/.test(pr ?? "") || rest.length) { console.error("kit merge <pr の番号>"); return 64; }
  let root, view, why;
  try {
    root = gits(process.cwd(), "rev-parse", "--show-toplevel");
    view = JSON.parse(gh(root, "pr", "view", pr, "--json", FIELDS));
    why = blockers(root, view);
  } catch (e) { console.error(`kit merge: 判定できません（${e.message.split("\n")[0]}）`); return 2; }
  if (why.length) {
    for (const w of why) console.error(`kit merge: ${w}`);
    return 1;
  }
  try {
    gh(root, "pr", "merge", pr, "--squash", "--match-head-commit", view.headRefOid);
    const state = JSON.parse(gh(root, "pr", "view", pr, "--json", "state")).state;
    if (state !== "MERGED") { console.error(`kit merge: merge を頼みましたが、状態は ${state} です`); return 1; }
  } catch (e) { console.error(`kit merge: gh pr merge が落ちました（${(e.stderr || e.message).trim()}）`); return 1; }
  console.log(`kit merge: #${pr} を merge しました（${view.headRefOid.slice(0, 7)}）`);
  return 0;
}

function blockers(root, v) {
  const why = [];
  if (v.state !== "OPEN") why.push(`PR が開いていません（${v.state}）`);
  if (v.isDraft) why.push("PR が draft です");
  if (v.isCrossRepository) why.push("fork からの PR です");
  if (why.length) return why;

  if (v.mergeable !== "MERGEABLE") why.push(`base に merge できません（${v.mergeable}）`);
  const result = (c) => c.conclusion || c.state || c.status;
  const latest = new Map();
  for (const c of v.statusCheckRollup ?? []) {
    const key = `${c.workflowName} ${c.name ?? c.context}`;
    if (!(latest.get(key)?.startedAt > c.startedAt)) latest.set(key, c);
  }
  const runs = [...latest.values()];
  if (!runs.some((c) => c.workflowName === "kit-ci" && result(c) === "SUCCESS")) why.push("kit-ci が通っていません");
  for (const c of runs) {
    if (!PASSED.includes(result(c))) why.push(`CI: ${c.name ?? c.context} が ${result(c)}`);
  }

  gits(root, "fetch", "--quiet", "origin", `+refs/heads/${v.baseRefName}:refs/remotes/origin/${v.baseRefName}`, `+refs/heads/${v.headRefName}:refs/remotes/origin/${v.headRefName}`);
  const base = `refs/remotes/origin/${v.baseRefName}`, head = v.headRefOid;
  if (gits(root, "rev-parse", `refs/remotes/origin/${v.headRefName}`) !== head) return [...why, "head が動いています。もう一度流してください"];
  for (const w of risk(root, base, head)) why.push(`review: ${w}`);
  const e = evidenceProblem(root, base, head);
  if (e) why.push(`証拠: ${e}`);
  return why;
}

// 落ちた証拠が 1 つでもあれば止める。通った証拠は、全部流したものか、PR の差分の全部を見たものが要る
function evidenceProblem(root, base, head) {
  const dir = path.join(root, ".verify", head);
  let all = [];
  try { all = fs.readdirSync(dir).filter((f) => f.endsWith(".json")).map((f) => [f, readJson(path.join(dir, f))]); } catch {}
  const bad = all.find(([, s]) => s.sha !== head || s.dirty || !s.ok);
  if (bad) return `${bad[0]} が落ちているか、この head のものではありません`;
  const mergeBase = gits(root, "merge-base", base, head);
  const usable = ([, s]) => !s.mode.fast && !s.mode.ci && (!s.mode.changed || s.mode.from === mergeBase);
  return all.some(usable) ? null : `この head の全部の差分を見た証拠がありません（${head.slice(0, 7)} を checkout して kit verify --changed ${base.slice("refs/remotes/".length)} を流してください）`;
}
