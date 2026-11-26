#!/usr/bin/env node
// kit CLI. Node の標準ライブラリだけで書く（ADR-005）。各リポジトリでは `node .kit/cli/kit.mjs <cmd>` で、install の前でも動く。
const table = {
  sync: "./commands/sync.mjs",
  check: "./commands/check.mjs",
  uninstall: "./commands/uninstall.mjs",
  "sync-verdict": "./commands/sync-verdict.mjs",
  guard: "./commands/guard.mjs",
  verify: "./commands/verify.mjs",
  risk: "./commands/risk.mjs",
  merge: "./commands/merge.mjs",
  env: "./commands/env.mjs",
  "install-global": "./commands/install-global.mjs",
  release: "./commands/release.mjs",
  "release-check": "./commands/release-check.mjs",
  notes: "./commands/notes.mjs",
};
const [cmd, ...args] = process.argv.slice(2);
if (!table[cmd]) {
  console.error(`kit: 使えるコマンド: ${Object.keys(table).join(", ")}`);
  process.exit(64);
}
const m = await import(new URL(table[cmd], import.meta.url));
process.exitCode = (await m.main(args)) ?? 0;
