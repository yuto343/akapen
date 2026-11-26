// kit uninstall [<repo>] : kit.lock に書いたものだけを消す（ADR-004）。kit.config.json などリポジトリのデータは残す。
import fs from "node:fs";
import path from "node:path";
import { readJson, stripAgentsBlock } from "../lib.mjs";

export async function main(args) {
  const root = path.resolve(args[0] ?? process.cwd());
  let lock;
  try { lock = readJson(path.join(root, "kit.lock")); }
  catch { console.error("kit uninstall: kit.lock がありません"); return 1; }
  for (const l of Object.keys(lock.links)) removeAndPrune(root, l);
  for (const f of Object.keys(lock.files)) {
    if (f === "AGENTS.md#kit") {
      const ap = path.join(root, "AGENTS.md");
      if (!fs.existsSync(ap)) continue;
      const t = stripAgentsBlock(fs.readFileSync(ap, "utf8"));
      t.trim() ? fs.writeFileSync(ap, t) : fs.rmSync(ap);
    } else if (!f.startsWith(".kit/")) removeAndPrune(root, f);
  }
  fs.rmSync(path.join(root, ".kit"), { recursive: true, force: true });
  fs.rmSync(path.join(root, "kit.lock"), { force: true });
  console.log("kit uninstall: kit が置いたものを消しました。kit.config.json は残しています。フックの行は手で消してください");
  return 0;
}

// 消したあと、空になった親ディレクトリも消す（リポジトリのルートまで）
function removeAndPrune(root, rel) {
  fs.rmSync(path.join(root, rel), { force: true });
  let dir = path.dirname(path.join(root, rel));
  while (dir.startsWith(root + path.sep)) {
    try { fs.rmdirSync(dir); } catch { break; }
    dir = path.dirname(dir);
  }
}
