// kit sync-verdict <base> <head> : この差分は「kit の sync だけ」で、auto で merge してよいか（ADR-002）。
// 終了コード 0 = auto、1 = review。verify が green かは kit merge が見る。
// タグとの照合に kit の clone（KIT_SOURCE）が要る。CI では流さない。
import { gits, git, sha, bumpKind, expandHome, agentsBlock, agentsBlockText, stripAgentsBlock, readYanked, WORKFLOW, skillLink, skillTarget } from "../lib.mjs";

export async function main(args) {
  const [base, head] = args;
  if (!base || !head) { console.error("kit sync-verdict <base> <head>"); return 64; }
  const root = process.cwd();
  const why = review(root, base, head);
  console.log(why.length ? `review: ${why.join(" / ")}` : "auto: kit の sync だけの差分です（verify が green なら merge してよい）");
  return why.length ? 1 : 0;
}

const show = (root, rev, f) => { try { return git(root, "show", `${rev}:${f}`); } catch { return null; } };
const lockAt = (root, rev) => { const b = show(root, rev, "kit.lock"); try { const l = JSON.parse(b); return l.files && l.links ? l : null; } catch { return null; } };

export function review(root, base, head) {
  const why = [];
  const a = lockAt(root, base), b = lockAt(root, head);
  if (!b) return ["head の kit.lock が読めません"];
  const kitLinks = new Set([...Object.keys(a?.links ?? {}), ...Object.keys(b.links)]);

  // 1. 差分が kit の持ち物だけか
  const changed = gits(root, "diff", "--name-only", "--no-renames", `${base}..${head}`).split("\n").filter(Boolean);
  const owned = (f) => f.startsWith(".kit/") || f === "kit.lock" || f === "AGENTS.md" || f === WORKFLOW || kitLinks.has(f);
  const outside = changed.filter((f) => !owned(f));
  if (outside.length) why.push(`kit 以外のファイルが変わっています: ${outside.join(", ")}`);
  if (changed.includes("AGENTS.md")) {
    const strip = (rev) => stripAgentsBlock(show(root, rev, "AGENTS.md")?.toString("utf8") ?? "");
    if (strip(base) !== strip(head)) why.push("AGENTS.md の kit ブロックの外が変わっています");
  }

  // 3. 版の上がり方
  const kind = bumpKind(a?.version, b.version);
  if (!["patch", "minor", "same"].includes(kind)) why.push(`版の上がり方が ${kind} です`);

  // head の中身が kit.lock どおりか
  for (const [f, h] of Object.entries(b.files)) {
    if (f === "AGENTS.md#kit") {
      const blk = agentsBlock(show(root, head, "AGENTS.md")?.toString("utf8") ?? "");
      if (!blk || sha(Buffer.from(blk.full)) !== h) { why.push("AGENTS.md の kit ブロックが kit.lock と違います"); break; }
      continue;
    }
    const buf = show(root, head, f);
    if (!buf || sha(buf) !== h) { why.push(`${f} が kit.lock と違います`); break; }
  }
  for (const [l, t] of Object.entries(b.links)) {
    const name = l.slice(skillLink("").length);
    if (!l.startsWith(skillLink("")) || t !== skillTarget(name)) why.push(`${l} の symlink の向き先が kit の形ではありません`);
  }

  // 2. kit.lock がタグの中身と一致するか
  const srcEnv = process.env.KIT_SOURCE;
  if (!srcEnv) { why.push("KIT_SOURCE が無いので、タグとの照合ができません"); return why; }
  const src = expandHome(srcEnv);
  let tagCommit = null;
  try { tagCommit = gits(src, "rev-list", "-n1", b.version); } catch {}
  if (tagCommit !== b.commit) { why.push(`kit.lock の commit がタグ ${b.version} と一致しません`); return why; }
  if (readYanked(src).has(b.version)) why.push(`${b.version} は取り下げられています`);
  const tagSha = (f) => { try { return sha(git(src, "show", `${b.version}:${f}`)); } catch { return null; } };
  for (const [f, h] of Object.entries(b.files)) {
    if (!f.startsWith(".kit/")) continue;
    if (tagSha(f.slice(5)) !== h) { why.push(`${f} がタグ ${b.version} の中身と違います`); return why; }
  }
  if (b.files[WORKFLOW]) {
    const ciHashes = Object.entries(b.files).filter(([f]) => /^\.kit\/ci\/kit-ci\.[a-z]+\.yml$/.test(f)).map(([, h]) => h);
    if (!ciHashes.includes(b.files[WORKFLOW])) why.push(`${WORKFLOW} が kit の ci/ のどれとも違います`);
  }
  if (b.files["AGENTS.md#kit"]) {
    let body = null;
    try { body = gits(src, "show", `${b.version}:agents/AGENTS.base.md`); } catch {}
    if (body === null || sha(Buffer.from(agentsBlockText(b.version, body))) !== b.files["AGENTS.md#kit"]) why.push("AGENTS.md の kit ブロックがタグの中身と違います");
  }
  return why;
}
