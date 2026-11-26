// kit notes <前のタグ>..<タグ> : 範囲で merge した PR の本文の「見える変更」から、リリースノートの下書きを出す。
// 節の無い PR と、PR の無い commit も、漏らさないように後ろに並べる。
import * as R from "../release.mjs";

const USAGE = "kit notes <前のタグ>..<タグ>";

export async function main(args) {
  const m = args.length === 1 && /^([^-.][^\s]*?)\.\.([^-.][^\s]*)$/.exec(args[0]);
  if (!m) { console.error(USAGE); return 64; }
  try {
    const root = R.repoRoot();
    for (const t of [m[1], m[2]]) if (!R.commitOf(root, t)) throw new Error(`${t} がありません`);
    console.log(notes(root, m[1], m[2]));
  } catch (e) { console.error(`kit notes: ${e.message.split("\n")[0]}`); return 2; }
  return 0;
}

export function notes(root, from, to) {
  const list = R.mergedIn(root, from, to);
  const out = [`# ${to}（${from} から）`];
  const rest = [];
  for (const { oid, subject, pr } of list) {
    const text = pr && visible(pr.body ?? "");
    if (text) out.push(`## ${pr.title}（#${pr.number}）\n\n${text}`);
    else rest.push(pr ? `- ${pr.title}（#${pr.number}）` : `- ${oid.slice(0, 7)} ${subject}（PR なし）`);
  }
  if (rest.length) out.push(`## 「見える変更」の無いもの\n\n${rest.join("\n")}`);
  return out.join("\n\n") + "\n";
}

// 見出し「見える変更」から、同じ深さか浅い次の見出しの前まで
function visible(body) {
  const lines = body.split(/\r?\n/);
  const i = lines.findIndex((l) => /^#+\s*見える変更\s*$/.test(l));
  if (i === -1) return "";
  const depth = /^#+/.exec(lines[i])[0].length;
  const end = lines.findIndex((l, k) => k > i && (/^(#+)\s/.exec(l)?.[1].length ?? 99) <= depth);
  return lines.slice(i + 1, end === -1 ? undefined : end).join("\n").trim();
}
