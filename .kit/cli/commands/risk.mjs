// kit risk <base> [<head>] : 差分を auto で merge してよいか。終了コード 0 = auto、1 = review、2 = 判定できない。
// 設定は base 側の risk.config.json を読む。PR が自分の関門を緩めても効かない。
import { git, gits, matchesAny } from "../lib.mjs";
import { validate } from "../schema.mjs";
import { review as syncReview } from "./sync-verdict.mjs";
import { readFileSync } from "node:fs";

const GATE = [
  ".kit/**", "kit.lock", "kit.config.json", "verify.config.json", "risk.config.json",
  ".github/**", "**/.claude/settings*.json", "**/.claude/hooks/**",
  "**/vitest*.config.*", "**/vitest.workspace.*", "**/vite.config.*", "**/playwright*.config.*", "**/eslint.config.*", "**/.eslintrc*", "**/tsconfig*.json",
  "pnpm-workspace.yaml", "**/Cargo.toml", "**/Package.swift",
];
const ENV = ["**/.env*", "**/.dev.vars*"];
const ENV_EXAMPLE = ["**/*.example"];
const TEST = ["**/*.test.*", "**/*.spec.*", "**/__tests__/**", "**/Tests/**", "e2e/**"];
const DEP_KEYS = ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"];
const DEP_OVERRIDES = ["pnpm", "overrides", "resolutions"];

export async function main(args) {
  const [base, head = "HEAD"] = args;
  if (!base) { console.error("kit risk <base> [<head>]"); return 64; }
  let reasons;
  try { reasons = risk(gits(process.cwd(), "rev-parse", "--show-toplevel"), base, head); }
  catch (e) { console.error(`kit risk: 判定できません（${e.message.split("\n")[0]}）`); return 2; }
  console.log(reasons.length ? `review: ${reasons.join(" / ")}` : "auto");
  return reasons.length ? 1 : 0;
}

export function risk(root, base, head) {
  const from = gits(root, "merge-base", base, head);
  const files = diffFiles(root, from, head);
  if (!files.length) return ["差分がありません"];
  if (files.some(({ f }) => f.startsWith(".kit/") || f === "kit.lock")) {
    const why = syncReview(root, from, head);
    return why.length ? why.map((w) => `kit の sync ではない: ${w}`) : [];
  }
  const cfg = configAt(root, from);
  if (!cfg) return ["base に risk.config.json がありません"];

  const why = [];
  const ctx = { root, from, head };
  for (const { f, status } of files) {
    const hit = (cls) => why.push(`${cls}: ${f}`);
    if (matchesAny(GATE, f)) hit("gate");
    if (matchesAny(ENV, f) && !matchesAny(ENV_EXAMPLE, f)) hit("env");
    if (matchesAny(TEST, f)) for (const w of testWeakened(ctx, f, status)) hit(w);
    if (/(^|\/)package\.json$/.test(f)) for (const w of packageChanged(ctx, f)) hit(w);
    for (const c of cfg.classes) if (matchesAny(c.paths, f)) hit(c.name);
  }
  const lines = files.reduce((n, x) => n + x.lines, 0);
  if (files.length > (cfg.maxFiles ?? 40)) why.push(`size: ${files.length} ファイル`);
  if (lines > (cfg.maxLines ?? 1500)) why.push(`size: ${lines} 行`);
  return why;
}

function configAt(root, rev) {
  const text = show(root, rev, "risk.config.json");
  if (text === null) return null;
  const cfg = JSON.parse(text);
  const errs = validate(JSON.parse(readFileSync(new URL("../../schemas/risk.config.schema.json", import.meta.url), "utf8")), cfg);
  if (errs.length) throw new Error(`risk.config.json: ${errs.join(" / ")}`);
  return cfg;
}

function diffFiles(root, from, head) {
  const z = (...a) => git(root, "diff", "--no-renames", "-z", ...a, from, head).toString("utf8").split("\0").filter(Boolean);
  const names = z("--name-status");
  const lines = new Map();
  for (const row of z("--numstat")) {
    const [add, del, f] = row.split("\t");
    lines.set(f, add === "-" ? 0 : Number(add) + Number(del));
  }
  const out = [];
  for (let i = 0; i < names.length; i += 2) out.push({ status: names[i], f: names[i + 1], lines: lines.get(names[i + 1]) ?? 0 });
  return out;
}

const show = (root, rev, f) => { try { return git(root, "show", `${rev}:${f}`).toString("utf8"); } catch { return null; } };

// コメントを除いた中身を、base と head で数えて比べる
const bare = (t) => (t ?? "").replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
const count = (t, re) => (bare(t).match(re) ?? []).length;
function testWeakened({ root, from, head }, f, status) {
  if (status === "D") return ["テストの削除"];
  const a = show(root, from, f), b = show(root, head, f);
  const out = [];
  if (count(b, /\b(expect|assert)\b/g) < count(a, /\b(expect|assert)\b/g)) out.push("検査が減った");
  if (count(b, /\b(it|test)(\.\w+)*\(/g) < count(a, /\b(it|test)(\.\w+)*\(/g)) out.push("テストが減った");
  const OFF = /\b(skip|skipIf|only|todo|fixme|fails)\b\s*[(:]|\bx(it|test|describe)\(/g;
  if (count(b, OFF) > count(a, OFF)) out.push("テストを飛ばした");
  return out;
}

function packageChanged({ root, from, head }, f) {
  const read = (rev) => { const t = show(root, rev, f); return t === null ? {} : JSON.parse(t); };
  let a, b;
  try { a = read(from); b = read(head); } catch { return ["package.json が読めません"]; }
  const out = new Set();
  for (const k of DEP_KEYS) for (const [name, v] of Object.entries(b[k] ?? {})) if (a[k]?.[name] !== v && !compatible(a[k]?.[name], v)) out.add(`依存 ${name}`);
  for (const k of DEP_OVERRIDES) if (JSON.stringify(a[k]) !== JSON.stringify(b[k])) out.add(`package.json の ${k}`);
  for (const [name, v] of Object.entries(a.scripts ?? {})) if (b.scripts?.[name] !== v) out.add(`script ${name}`);
  return [...out];
}

// 同じ依存の、major が同じ（0.x は minor も同じ）版の変更だけを auto にする
function compatible(a, b) {
  const v = (x) => /^[\^~]?(\d+)\.(\d+)\.\d+$/.exec(x ?? "");
  const x = v(a), y = v(b);
  return !!x && !!y && x[1] === y[1] && (x[1] !== "0" || x[2] === y[2]);
}
