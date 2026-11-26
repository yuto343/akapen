import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";

export const sha = (buf) => crypto.createHash("sha256").update(buf).digest("hex");
export const git = (cwd, ...a) =>
  execFileSync("git", ["-C", cwd, ...a], { encoding: "buffer", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 1 << 28 });
export const gits = (cwd, ...a) => git(cwd, ...a).toString("utf8").trim();
export const readJson = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
export const expandHome = (p) => p.replace(/^~(?=\/|$)/, process.env.HOME ?? "~");

export function flag(args, name) {
  const i = args.indexOf(name);
  return i === -1 ? undefined : args[i + 1];
}

// --- semver: ^x.y.z、~x.y.z、x.y.z だけを読む（ADR-002）
export function parseSemver(t) {
  const m = /^v(\d+)\.(\d+)\.(\d+)$/.exec(t);
  return m ? m.slice(1).map(Number) : null;
}
export function cmp(a, b) {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] - b[i];
  return 0;
}
export function satisfies(v, range) {
  const op = range[0] === "^" || range[0] === "~" ? range[0] : "=";
  const base = parseSemver("v" + range.replace(/^[\^~=]/, ""));
  if (!base) throw new Error(`範囲が読めません: ${range}`);
  if (cmp(v, base) < 0) return false;
  if (op === "=") return cmp(v, base) === 0;
  if (op === "~") return v[0] === base[0] && v[1] === base[1];
  return base[0] === 0 ? v[0] === 0 && v[1] === base[1] : v[0] === base[0];
}
export function bumpKind(from, to) {
  if (!from) return "initial";
  const a = parseSemver(from), b = parseSemver(to);
  if (b[0] !== a[0]) return "major";
  if (b[1] !== a[1]) return "minor";
  if (b[2] !== a[2]) return "patch";
  return "same";
}

// --- AGENTS.md の kit ブロック
const BLOCK_RE = /<!-- kit:begin (v\d+\.\d+\.\d+) -->\n([\s\S]*?)\n<!-- kit:end -->/;
export const agentsBlockText = (tag, body) => `<!-- kit:begin ${tag} -->\n${body.trimEnd()}\n<!-- kit:end -->`;
export function agentsBlock(text) {
  const m = BLOCK_RE.exec(text);
  return m ? { version: m[1], full: m[0] } : null;
}
export const stripAgentsBlock = (text) => text.replace(/<!-- kit:begin [^>]*-->[\s\S]*?<!-- kit:end -->\n*/, "");

// --- kit が置くもの
export const MANDATORY = ["cli", "schemas"]; // receive に関係なく必ず入る
export const receivedPaths = (cfg) => [
  ...MANDATORY,
  ...["agents", "ci", "guard"].filter((r) => cfg.receive?.includes(r)),
  ...(cfg.skills ?? []).map((s) => `skills/${s}`),
];
export const WORKFLOW = ".github/workflows/kit-ci.yml";
export const skillLink = (name) => `.claude/skills/${name}`;
export const skillTarget = (name) => `../../.kit/skills/${name}`;

export function walk(dir, base = dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(p, base));
    else out.push(path.relative(base, p));
  }
  return out.sort();
}

// --- glob: ** と * だけを読む。* は / をまたがない
export const matchesAny = (globs, f) => globs.some((g) => globRe(g).test(f));
const globRe = (g) => new RegExp(`^${g.split(/(\*\*\/|\*\*|\*)/).map((p) => ({ "**/": "(?:.*/)?", "**": ".*", "*": "[^/]*" })[p] ?? p.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join("")}$`);

// --- 取り下げた版（kit の main の YANKED）
export function readYanked(src) {
  const out = new Set();
  let text = "";
  try { text = gits(src, "show", "origin/main:YANKED"); } catch { return out; }
  for (const line of text.split("\n")) {
    const t = line.trim();
    if (t && !t.startsWith("#")) out.add(t.split(/\s/)[0]);
  }
  return out;
}
