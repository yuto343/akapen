// kit release <dev|prod> : オーナーが自分のターミナルで流す、リリースの入口（P-04）。
// release-check → タグ（手元）→ タグの worktree → release.<env>.steps → タグの push と notes。
// 落ちたらそこで止まり、もう一度流すと記録（.release/<タグ>.json）の続きから進む。
import fs from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline/promises";
import { spawnSync } from "node:child_process";
import { gits } from "../lib.mjs";
import { releaseEnv } from "./env.mjs";
import { tagProblems, treeProblems, trunkProblems, firstLine } from "./release-check.mjs";
import { notes } from "./notes.mjs";
import * as R from "../release.mjs";

const USAGE = "kit release <dev|prod>\n  dev   上げた版のタグを作り、dev に出す\n  prod  dev に出し終えたタグを、確認してから production に出す";
// エージェントが子プロセスに渡す印。CODEX_HOME と CODEX_API_KEY はオーナーの設定にもある
const AGENT = /^(CLAUDECODE|AI_AGENT|CODEX_(?!(?:HOME|API_KEY)$).+)$/;

export async function main(args) {
  const env = args[0];
  if (args.length !== 1 || !["dev", "prod"].includes(env)) { console.error(USAGE); return 64; }
  const agent = Object.keys(process.env).find((k) => AGENT.test(k) && process.env[k]);
  if (agent) return stop(`リリースはオーナーだけの操作です。エージェントの環境（${agent}）では流しません`);

  let root, rel;
  try { root = R.repoRoot(); rel = R.loadRelease(root); } catch (e) { return stop(e.message, 2); }
  const confirm = rel[env].confirm ?? env === "prod";
  if (confirm && !process.stdin.isTTY) return stop("確認が要りますが、標準入力が端末ではありません");
  let held;
  try { held = R.lock(root, rel); } catch (e) { return stop(e.message); }
  try { return await start(root, rel, env, confirm, held.stepPid); } finally { held.unlock(); }
}

async function start(root, rel, env, confirm, stepPid) {
  let plan;
  try {
    R.fetchTrunk(root);
    const errs = [...treeProblems(root), ...trunkProblems(root)];
    if (errs.length) return stop(errs.join("\nkit release: "));
    plan = targets(root, rel, env);
    for (const s of plan.skipped) console.log(`kit release: ${s}`);
    if (!plan.groups.length) return stop(`${env} に出すものがありません`);
    for (const t of plan.groups.flatMap((x) => x.tags)) errs.push(...tagProblems(root, rel, t.tag, env).map((e) => `${t.tag}: ${e}`));
    for (const x of plan.groups) errs.push(...changedSteps(rel, env, x).map((m) => `${refs(x)}: ${m}`));
    if (errs.length) return stop([...new Set(errs)].join("\nkit release: "));
  } catch (e) { return stop(`判定できません（${firstLine(e)}）`, 2); }

  for (const x of plan.groups) show(root, rel, env, x);
  if (confirm && !(await yes(`${env} に出します。よいですか？ [y/N] `))) return stop("やめました");
  for (const x of plan.groups) {
    try { release(root, rel, env, x, stepPid); } catch (e) { return stop(`${refs(x)}: ${firstLine(e)}。もう一度流すと、続きから進みます`); }
  }
  return 0;
}

function stop(msg, code = 1) { console.error(`kit release: ${msg}`); return code; }

// 出すもの: 同じ commit のタグを 1 組にした {commit, tags: [{surface, tag, ref, rec, envs}]}。
// 古い commit から並べる（新しいバックエンドを古いもので上書きしない）
function targets(root, rel, env) {
  const head = gits(root, "rev-parse", "HEAD"), remote = R.remoteTags(root);
  const byCommit = new Map(), skipped = [];
  for (const surface of rel.surfaces) {
    const tag = env === "dev" ? R.tagName(rel, surface, releaseEnv(root, head, surface).version) : R.newestTag(root, rel, surface);
    if (!tag) { skipped.push(`${surface}: タグがありません`); continue; }
    const rec = R.readRecord(root, rel, tag), ref = R.refOf(env, tag), mine = rec?.[env];
    const skip = mine?.pushedAt ? `${env} に出してあります`
      : !mine && env === "prod" && !rec?.dev?.pushedAt ? "dev の記録がありません（先に kit release dev で出します）"
      : !mine && (R.tagCommit(root, ref) || remote.has(ref)) ? `タグ ${ref} は既にありますが、kit release の記録がありません` : null;
    if (skip) { skipped.push(`${surface}（${tag}）は出しません: ${skip}`); continue; }
    const commit = rec?.commit ?? head;
    const t = { surface, tag, ref, rec: rec ?? { tag, commit }, envs: releaseEnv(root, commit, surface).envs };
    byCommit.set(commit, [...(byCommit.get(commit) ?? []), t]);
  }
  const age = (c) => Number(gits(root, "rev-list", "--count", c));
  return { groups: [...byCommit].map(([commit, tags]) => ({ commit, tags })).sort((a, b) => age(a.commit) - age(b.commit)), skipped };
}

const refs = (x) => x.tags.map((t) => t.ref).join("、");
// step と、その step が当てはまるタグ
const stepsOf = (rel, env, x) => rel[env].steps
  .map((s) => ({ ...s, tags: x.tags.filter((t) => !s.surfaces || s.surfaces.includes(t.surface)) })).filter((s) => s.tags.length);
const isDone = (env, s) => s.tags.every((t) => t.rec[env]?.steps[s.name]?.status === "done");

// 済んだ後で run を直した step は、流し直すのか、そのままでよいのかを機械では決められない
const changedSteps = (rel, env, x) => stepsOf(rel, env, x).flatMap((s) => s.tags.map((t) => t.rec[env]?.steps[s.name])
  .filter((r) => r?.status === "done" && r.run !== s.run)
  .map((r) => `済んでいる ${s.name} の run が変わっています（流したのは ${r.run}）。流し直すなら記録から ${s.name} を消し、流し直さないなら記録の run を今のものに書き換えてください`));

const MARK = { done: "済", running: "途中", failed: "落ちた" };
function show(root, rel, env, x) {
  console.log("");
  const behind = Number(gits(root, "rev-list", "--count", `${x.commit}..origin/main`));
  if (behind) console.log(`${x.commit.slice(0, 7)} は main より ${behind} commit 古い（前に始めたものの続き）`);
  for (const t of x.tags) {
    const e = Array.isArray(t.envs) ? {} : t.envs[env === "prod" ? "production" : "dev"] ?? {};
    console.log(`${t.ref}（${x.commit.slice(0, 7)}）→ ${[e.identifier, e.backend, e.updater, ...(e.urls ?? [])].filter(Boolean).join(" / ") || env}`);
  }
  for (const s of stepsOf(rel, env, x)) console.log(`  ${MARK[isDone(env, s) ? "done" : s.tags.map((t) => t.rec[env]?.steps[s.name]?.status).find((v) => v && v !== "done")] ?? ""} ${s.name}: ${s.run}`);
  console.log("");
}

async function yes(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await Promise.race([rl.question(question), new Promise((r) => rl.once("close", () => r("")))]);
  rl.close();
  return ["y", "yes"].includes(answer.trim().toLowerCase());
}

function release(root, rel, env, x, stepPid) {
  const save = (tags, f) => { for (const t of tags) { f(t.rec, t); R.writeRecord(root, rel, t.rec); } };
  // 記録を先に書く。タグを作る前に落ちても、次に同じ commit にタグを作る
  save(x.tags, (rec) => { rec[env] ??= { steps: {}, pushedAt: null }; });
  for (const { tag, ref } of x.tags) {
    if (!R.tagCommit(root, ref)) gits(root, "tag", "-a", "-m", env === "prod" ? `${tag} を production に出した` : tag, ref, x.commit);
  }

  const steps = stepsOf(rel, env, x), dir = R.placeOf(root, env, x.commit);
  if (!steps.every((s) => isDone(env, s))) place(root, dir, x.commit, steps.filter((s) => isDone(env, s)));
  for (const s of steps) {
    if (isDone(env, s)) { console.log(`kit release: ${s.name} は済んでいます`); continue; }
    if (s.tags.some((t) => t.rec[env].steps[s.name]?.status === "running")) console.log(`kit release: ${s.name} は前回、途中で切れています。もう一度流します`);
    const local = R.envLocalProblems(dir);
    if (local.length) throw new Error(local.join(" / "));
    console.log(`\nkit release: ${s.name}: ${s.run}`);
    const record = (status) => save(s.tags, (rec) => { rec[env].steps[s.name] = { status, run: s.run, at: new Date().toISOString() }; });
    record("running");
    const r = spawnSync(`echo $$ > "$KIT_STEP_PID"\n${s.run}`, { cwd: dir, shell: true, stdio: "inherit", env: { ...process.env, KIT_ROOT: root, KIT_STEP_PID: stepPid } });
    fs.rmSync(stepPid, { force: true });
    record(r.status === 0 ? "done" : "failed");
    if (r.status !== 0) throw new Error(`${s.name} が落ちました（${r.status ?? r.signal}）`);
  }

  for (const t of x.tags) {
    try {
      const there = R.remoteTags(root).get(t.ref);
      if (there && there !== x.commit) throw new Error(`origin の ${t.ref} は別の commit（${there.slice(0, 7)}）を指しています`);
      if (!there) gits(root, "push", "--quiet", "--no-follow-tags", "origin", `refs/tags/${t.ref}`);
    }
    catch (e) { throw new Error(`タグ ${t.ref} の push が落ちました（${firstLine(e)}）`); }
    save([t], (rec) => { rec[env].pushedAt = new Date().toISOString(); });
    console.log(`\nkit release: ${t.ref} を出しました。記録は ${R.recordPath(root, rel, t.tag)}\n`);
    const prev = R.previousTag(root, rel, t.surface, env, x.commit);
    if (!prev) continue;
    try { console.log(notes(root, prev, t.ref)); }
    catch (e) { console.error(`kit release: リリースノートを出せませんでした（${firstLine(e)}）。kit notes ${prev}..${t.ref} で出し直せます`); }
  }
  if (fs.existsSync(dir)) gits(root, "worktree", "remove", "--force", dir);
}

function place(root, dir, commit, done) {
  if (!fs.existsSync(dir)) {
    if (done.length) throw new Error(`${done.map((s) => s.name).join("、")} は済んでいますが、作業場所 ${dir} が無く、成果物が残っていません。流し直す step を記録から消してください`);
    fs.mkdirSync(path.dirname(dir), { recursive: true });
    gits(root, "worktree", "add", "--quiet", "--force", "--detach", dir, commit);
  }
  const errs = R.placeProblems(dir, commit);
  if (errs.length) throw new Error(errs.join(" / "));
}
