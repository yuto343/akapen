// kit check [<repo>] : .kit/、コピーした workflow、AGENTS.md の kit ブロック、symlink が kit.lock と一致するか。
// kit の clone は要らない（CI と新しい worktree で流す）。
import fs from "node:fs";
import path from "node:path";
import { sha, readJson, walk, agentsBlock, receivedPaths } from "../lib.mjs";
import { validate, configRules } from "../schema.mjs";

export async function main(args) {
  const root = path.resolve(args[0] ?? process.cwd());
  const errs = [];
  let lock;
  try { lock = readJson(path.join(root, "kit.lock")); }
  catch { console.error("kit check: kit.lock がありません"); return 1; }
  const schemaDir = path.join(root, ".kit/schemas");
  let cfg = {};
  try {
    errs.push(...validate(readJson(path.join(schemaDir, "kit.lock.schema.json")), lock).map((e) => `kit.lock: ${e}`));
    cfg = readJson(path.join(root, "kit.config.json"));
    const bad = validate(readJson(path.join(schemaDir, "kit.config.schema.json")), cfg);
    errs.push(...(bad.length ? bad : configRules(cfg)).map((e) => `kit.config.json: ${e}`));
  } catch (e) { errs.push(`設定かスキーマが読めません（${e.message}）`); }
  if (errs.length) return report(errs);
  const guardErr = guardHookProblem(root, cfg.receive?.includes("guard"));
  if (guardErr) errs.push(guardErr);

  const paths = receivedPaths(cfg).map((p) => `.kit/${p}/`);
  const placed = Object.keys(lock.files).filter((f) => f.startsWith(".kit/"));
  for (const p of paths) if (!placed.some((f) => f.startsWith(p))) errs.push(`kit.config.json では ${p} を受け取りますが、kit.lock にありません（kit sync を流してください）`);
  for (const f of placed) if (!paths.some((p) => f.startsWith(p))) errs.push(`${f} は、kit.config.json の receive と skills に無いのに入っています（kit sync を流してください）`);

  for (const [f, h] of Object.entries(lock.files)) {
    if (f === "AGENTS.md#kit") {
      let t = "";
      try { t = fs.readFileSync(path.join(root, "AGENTS.md"), "utf8"); } catch {}
      const b = agentsBlock(t);
      if (!b) errs.push("AGENTS.md の kit ブロックがありません");
      else if (sha(Buffer.from(b.full)) !== h) errs.push("AGENTS.md の kit ブロックが手で編集されています（kit 側を直して sync してください）");
      continue;
    }
    const p = path.join(root, f);
    if (!fs.existsSync(p)) { errs.push(`${f} がありません`); continue; }
    if (sha(fs.readFileSync(p)) !== h) errs.push(`${f} が kit.lock と違います（kit が置いたファイルは手で編集しません）`);
  }
  for (const f of walk(path.join(root, ".kit"))) if (!lock.files[`.kit/${f}`]) errs.push(`.kit/${f} は kit.lock にありません`);
  for (const [l, t] of Object.entries(lock.links)) {
    const p = path.join(root, l);
    let ok = false;
    try { ok = fs.readlinkSync(p) === t && fs.existsSync(p); } catch {}
    if (!ok) errs.push(`${l} の symlink が壊れています`);
  }
  if (errs.length) return report(errs);
  console.log(`kit check: ${lock.version} と一致しています`);
  return 0;
}

function report(errs) {
  for (const e of errs) console.error(`kit check: ${e}`);
  return 1;
}

// PreToolUse の Bash に、ちょうど `node .kit/cli/kit.mjs guard` を呼ぶフックがあるか
const GUARD_COMMAND = /^node (["']?)(?:\$CLAUDE_PROJECT_DIR\/)?\.kit\/cli\/kit\.mjs\1 guard$/;
const matchesBash = (m) => {
  if (!m || m === "*") return true;
  try { return new RegExp(`^(?:${m})$`).test("Bash"); } catch { return false; }
};
export function hasGuardHook(settings) {
  return (settings.hooks?.PreToolUse ?? []).some((h) => matchesBash(h.matcher) &&
    (h.hooks ?? []).some((x) => x.type === "command" && GUARD_COMMAND.test((x.command ?? "").trim())));
}

function guardHookProblem(root, received) {
  let settings = {};
  try { settings = readJson(path.join(root, ".claude/settings.json")); } catch {}
  const hook = hasGuardHook(settings);
  if (!received) return hook ? ".claude/settings.json に guard のフックがありますが、kit.config.json の receive に guard が無いので guard を受け取っていません" : null;
  if (settings.disableAllHooks === true) return ".claude/settings.json の disableAllHooks: true で guard のフックが効きません";
  return hook ? null : ".claude/settings.json に guard のフックがありません（README の「guard を入れる」）";
}
