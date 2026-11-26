// kit verify [--changed <base>] [--fast] [--ci]
// verify.config.json の検査を流し、結果を .verify/<sha>/ に書く。全部流したものは summary.json、
// 範囲を絞ったものは changed-<分岐点>.json、ci.json、fast.json。狭い実行が広い実行の失敗を消さないように分ける。
// commit していない変更があるときは、その commit の証拠にならないので .verify/partial/ に書く。
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { git, gits, readJson, matchesAny } from "../lib.mjs";
import { validate, verifyRules } from "../schema.mjs";
import { main as kitCheck } from "./check.mjs";

const USAGE = "kit verify [--changed <base>] [--fast] [--ci]";

export async function main(args) {
  const opt = parseArgs(args);
  if (!opt) { console.error(USAGE); return 64; }
  let root;
  try { root = gits(process.cwd(), "rev-parse", "--show-toplevel"); }
  catch { console.error("kit verify: git のリポジトリではありません"); return 2; }
  let cfg;
  try { cfg = loadConfig(root); } catch (e) { console.error(`kit verify: ${e.message}`); return 2; }
  let changed = null, from = null;
  if (opt.changed) {
    try { from = gits(root, "merge-base", opt.changed, "HEAD"); changed = changedSince(root, from); }
    catch { console.error(`kit verify: ${opt.changed} との差分が取れません`); return 2; }
  }

  const before = state(root);
  const outDir = path.join(root, ".verify", before.dirty ? "partial" : before.sha);
  const scope = [from && `changed-${from.slice(0, 12)}`, opt.ci && "ci", opt.fast && "fast"].filter(Boolean);
  const out = path.join(outDir, `${scope.join("-") || "summary"}.json`);
  fs.rmSync(out, { force: true });

  const started = Date.now();
  const checks = [];
  const record = (name, run, code, ms) => checks.push({ name, run, status: code === 0 ? "pass" : "fail", ms });
  const t = Date.now();
  record("kit-check", "kit check", await kitCheck([root]), Date.now() - t);
  let setupOk = true;
  for (const run of opt.ci ? cfg.setup ?? [] : []) {
    if (!setupOk) break;
    const r = sh(root, run);
    record("setup", run, r.code, r.ms);
    setupOk = r.code === 0;
  }
  let ran = 0;
  for (const c of cfg.checks) {
    const skip = !setupOk ? "setup が落ちた" : skipReason(c, cfg, opt, changed);
    if (skip) { checks.push({ name: c.name, run: c.run, status: "skip", reason: skip }); continue; }
    console.log(`\nkit verify: ${c.name}: ${c.run}`);
    const r = sh(root, c.run);
    record(c.name, c.run, r.code, r.ms);
    ran++;
  }

  const after = state(root);
  const moved = after.sha !== before.sha || after.status !== before.status;
  const ok = checks.every((c) => c.status !== "fail") && (changed !== null || ran > 0) && !moved;
  const summary = {
    sha: before.sha, dirty: before.dirty, ok,
    mode: { changed: opt.changed, from, fast: opt.fast, ci: opt.ci },
    startedAt: new Date(started).toISOString(), ms: Date.now() - started, checks,
  };
  writeSummary(root, out, summary);

  console.log("");
  for (const c of checks) console.log(`kit verify: ${c.status} ${c.name}${c.reason ? `（${c.reason}）` : `（${(c.ms / 1000).toFixed(1)} 秒）`}`);
  if (moved) console.error(`kit verify: 流している間に HEAD か作業ツリーが変わったので、失敗にします: ${[after.sha !== before.sha && after.sha, ...lines(after.status).filter((l) => !lines(before.status).includes(l))].filter(Boolean).join(", ")}`);
  if (changed === null && ran === 0) console.error("kit verify: 検査を 1 つも流していません");
  console.log(`kit verify: ${ok ? "通りました" : "落ちました"}。${path.relative(root, out)}`);
  return ok ? 0 : 1;
}

function parseArgs(args) {
  const opt = { changed: null, fast: false, ci: false };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--fast") opt.fast = true;
    else if (args[i] === "--ci") opt.ci = true;
    else if (args[i] === "--changed" && args[i + 1] && !args[i + 1].startsWith("-")) opt.changed = args[++i];
    else return null;
  }
  return opt;
}

function loadConfig(root) {
  const cfg = readJson(path.join(root, "verify.config.json"));
  const schema = readJson(path.join(root, ".kit/schemas/verify.config.schema.json"));
  const errs = [...validate(schema, cfg)];
  if (!errs.length) errs.push(...verifyRules(cfg));
  if (!errs.length) {
    const files = [...lines(git(root, "ls-files", "-z")), ...untracked(root)];
    for (const c of cfg.checks) for (const p of c.paths) if (!files.some((f) => matchesAny([p], f))) errs.push(`${c.name}: paths の ${p} に当たるファイルがありません（読めるのは ** と * だけ）`);
  }
  if (errs.length) throw new Error(`verify.config.json: ${errs.join(" / ")}`);
  return cfg;
}

const lines = (buf) => buf.toString("utf8").split("\0").filter(Boolean);

const untracked = (root) => lines(git(root, "ls-files", "--others", "--exclude-standard", "-z"));

function changedSince(root, from) {
  return [...new Set([
    ...lines(git(root, "diff", "--name-only", "--no-renames", "-z", from)),
    ...untracked(root),
  ])];
}

// 設定が変わったときと、どの検査の paths にも ignore にも無いファイルがあるときは、影響が分からないので全部流す
function skipReason(check, cfg, opt, changed) {
  if (opt.ci && check.ci === false) return "ci: false";
  if (opt.fast && !check.fast) return "fast ではない";
  if (!changed) return null;
  const known = [...(cfg.ignore ?? []), ...cfg.checks.flatMap((c) => c.paths)];
  const all = changed.includes("verify.config.json") || changed.some((f) => !matchesAny(known, f));
  return all || changed.some((f) => matchesAny(check.paths, f)) ? null : "差分に無い";
}

function sh(root, run) {
  const t = Date.now();
  const r = spawnSync(run, { cwd: root, shell: true, stdio: ["ignore", "inherit", "inherit"] });
  return { code: r.status ?? 1, ms: Date.now() - t };
}

function state(root) {
  const status = git(root, "status", "--porcelain", "--untracked-files=all", "-z").toString("utf8");
  return { sha: gits(root, "rev-parse", "HEAD"), status, dirty: status !== "" };
}

function writeSummary(root, out, summary) {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(path.join(root, ".verify/.gitignore"), "*\n");
  fs.writeFileSync(`${out}.tmp`, JSON.stringify(summary, null, 2) + "\n");
  fs.renameSync(`${out}.tmp`, out);
}
