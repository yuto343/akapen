// kit env check [--at <sha>]
// env.contract.json に書いた環境の値と、git に入っているファイルの値が合うかを見る（RELEASE-PLAN §2.2）。
// 契約は作業ツリーのものを読み、--at があればファイルだけをその commit から読む（今の契約で過去を調べるため）。
import fs from "node:fs";
import path from "node:path";
import { git, gits, readJson } from "../lib.mjs";
import { validate, envRules, ENVS } from "../schema.mjs";
import * as convex from "../env-kinds/convex.mjs";

const USAGE = "kit env check [--at <sha>]";
const CONTRACT = "env.contract.json";
const KINDS = { convex };

export async function main(args) {
  const opt = parseArgs(args);
  if (!opt) { console.error(USAGE); return 64; }
  let root;
  try { root = gits(process.cwd(), "rev-parse", "--show-toplevel"); }
  catch { console.error("kit env check: git のリポジトリではありません"); return 2; }
  let contract, repo;
  try { contract = loadContract(root); } catch (e) { console.error(`kit env check: ${e.message}`); return 2; }
  try { repo = opt.at ? atCommit(root, opt.at) : atWorktree(root); }
  catch { console.error(`kit env check: ${opt.at} がありません`); return 2; }

  for (const [name, s] of Object.entries(contract.surfaces)) if (Array.isArray(s.envs)) console.log(`kit env check: ${name} は ${s.envs.join(" / ")} だけで、向き先の宣言はありません`);
  const errs = problems(contract, repo);
  const warns = scriptWarnings(repo);
  for (const w of warns) console.log(`kit env check: warn: ${w}`);
  for (const e of new Set(errs)) console.error(`kit env check: ${e}`);
  console.log(`kit env check${opt.at ? ` ${opt.at}` : ""}: ${errs.length ? "落ちました" : "通りました"}（警告 ${warns.length}）`);
  return errs.length ? 1 : 0;
}

function problems(contract, repo) {
  const errs = [];
  for (const [name, s] of Object.entries(contract.surfaces)) {
    if (s.version) checkVersion(repo, name, s.version, errs);
    if (Array.isArray(s.envs)) continue;
    checkDeclared(name, s.envs, errs);
    for (const [env, e] of declared(s.envs)) checkEnv(repo, contract, name, s.kind, env, e, errs);
  }
  return errs;
}

// その commit の契約で、その commit を見る（kit release-check が使う）
export function releaseEnv(root, sha, surface) {
  const repo = atCommit(root, sha);
  if (!repo.files.has(CONTRACT)) throw new Error(`${CONTRACT} がありません`);
  const contract = parseContract(repo.text(CONTRACT)), errs = [];
  const source = contract.surfaces[surface]?.version?.source;
  if (!source) throw new Error(`${CONTRACT} に ${surface} の version がありません`);
  const version = versionAt(repo, source, errs);
  if (!version) throw new Error(errs.join(" / "));
  return { version, problems: problems(contract, repo), envs: contract.surfaces[surface].envs };
}

function parseArgs(args) {
  if (args[0] !== "check") return null;
  if (args.length === 1) return { at: null };
  return args.length === 3 && args[1] === "--at" && !args[2].startsWith("-") ? { at: args[2] } : null;
}

function loadContract(root) {
  const p = path.join(root, CONTRACT);
  if (!fs.existsSync(p)) throw new Error(`${CONTRACT} がありません`);
  return parseContract(fs.readFileSync(p, "utf8"));
}

function parseContract(text) {
  let contract;
  try { contract = JSON.parse(text); } catch (e) { throw new Error(`${CONTRACT}: 読めません（${e.message}）`); }
  const errs = validate(readJson(new URL("../../schemas/env.contract.schema.json", import.meta.url)), contract);
  if (!errs.length) errs.push(...envRules(contract));
  if (errs.length) throw new Error(`${CONTRACT}: ${errs.join(" / ")}`);
  return contract;
}

const lines = (buf) => buf.toString("utf8").split("\0").filter(Boolean);
function atCommit(root, at) {
  const sha = gits(root, "rev-parse", "--verify", "--quiet", `${at}^{commit}`);
  return { files: new Set(lines(git(root, "ls-tree", "-r", "--name-only", "-z", sha))), text: (f) => git(root, "show", `${sha}:${f}`).toString("utf8") };
}
const atWorktree = (root) => ({ files: new Set(lines(git(root, "ls-files", "-z"))), text: (f) => fs.readFileSync(path.join(root, f), "utf8") });

const declared = (envs) => ENVS.filter((env) => envs[env]).map((env) => [env, envs[env]]);

// 契約そのものの、環境どうしの重なりと、local だけの条件
function checkDeclared(name, envs, errs) {
  const list = declared(envs);
  for (const key of ["identifier", "backend", "updater"]) {
    const seen = {};
    for (const [env, e] of list) {
      if (!e[key]) continue;
      if (seen[e[key]]) errs.push(`${name}: ${seen[e[key]]} と ${env} が同じ ${key}（${e[key]}）です`);
      seen[e[key]] ??= env;
    }
  }
  for (const [env, e] of list) {
    if (e.backend && (e.backend === "local") !== (env === "local")) errs.push(`${name}: ${env} の backend が ${e.backend} です（local は local だけが向きます）`);
    if (env === "local" && e.updater) errs.push(`${name}: local の updater は null のはずが ${e.updater} です`);
  }
}

function checkEnv(repo, contract, name, kind, env, e, errs) {
  const confirmed = new Set();
  const foreign = foreignValues(contract, env);
  for (const ref of e.files ?? []) {
    let file, claims;
    try { file = open(repo, ref); claims = claimsOf(ref, file, kind); }
    catch (x) { errs.push(x.message); continue; }
    if (!claims.length) errs.push(`${ref}: 環境を示す値が 1 つも読めません`);
    for (const [key, got] of claims) {
      const url = key === "backend" || key === "urls" ? originOf(got) : null;
      if (url && e.urls?.includes(url)) { confirmed.add(`urls ${url}`); continue; }
      const want = key === "APP_VARIANT" ? env : e[key];
      if (key !== "urls" && got === want) confirmed.add(`${key} ${got}`);
      else errs.push(`${ref}: ${name} の ${env} の ${key} は ${show(want)} のはずが ${show(got)} です`);
    }
    for (const [key, value] of file.pairs) for (const f of foreign) if (f.re.test(value)) errs.push(`${ref}: ${name} の ${env} のファイルの ${key} に、${f.env} の値 ${f.value} があります`);
  }
  const values = [...["identifier", "backend", "updater"].filter((k) => e[k] !== undefined).map((k) => [k, e[k]]), ...(e.urls ?? []).map((u) => ["urls", u])];
  for (const [key, value] of values) {
    // local の向き先は git に入れない .env.local などに書くので、ファイルでは確かめない
    if (env === "local" && key === "backend") continue;
    if (!confirmed.has(`${key} ${value}`)) errs.push(`${name} の ${env} の ${key}（${show(value)}）は、契約の files のどれにも無く、確かめられません`);
  }
}

const show = (v) => v === undefined ? "（契約に無い）" : v === "" ? "（空）" : typeof v === "string" ? v : JSON.stringify(v);
const originOf = (v) => { try { return new URL(v).origin; } catch { return null; } };

// ほかの環境の値。com.example.app が com.example.app.dev に当たらないように、前後の区切りを見る
function foreignValues(contract, env) {
  const own = new Set(), out = new Map();
  for (const s of Object.values(contract.surfaces)) {
    if (Array.isArray(s.envs)) continue;
    for (const [other, e] of declared(s.envs)) {
      const values = [e.identifier, e.updater, e.backend === "local" ? null : e.backend, ...(e.urls ?? []).map((u) => u.replace(/^https?:\/\//, ""))].filter(Boolean);
      for (const v of values) other === env ? own.add(v) : out.set(v, { env: other, value: v, re: new RegExp(`(?<![\\w.-])${v.replace(/[.+?^${}()|[\]\\*]/g, "\\$&")}(?!${v === e.backend ? "[\\w-]" : "[\\w.-]"})`) });
    }
  }
  return [...out.values()].filter((f) => !own.has(f.value));
}

// --- ファイルを読む。"<path>#<a.b.c>" は JSON の中の a.b.c だけを指す
function open(repo, ref) {
  const [file, pointer] = ref.split("#");
  if (!repo.files.has(file)) throw new Error(`${file} は git に入っていません`);
  const base = path.basename(file);
  const text = readText(repo, file);
  if (/^\.env(\.|$)/.test(base)) {
    if (pointer) throw new Error(`${ref}: env ファイルに # は使えません`);
    return { base, value: null, pairs: dotenv(file, text) };
  }
  if (!/\.jsonc?$/.test(base)) throw new Error(`${ref}: 読み方が分かりません（読めるのは .env*、.json、.jsonc）`);
  const value = at(ref, jsonc(file, text), pointer);
  return { base, value, pairs: flatten(value) };
}

function readText(repo, file) {
  try { return repo.text(file); } catch { throw new Error(`${file} が読めません`); }
}

function dotenv(file, text) {
  const out = [];
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith("#")) continue;
    const m = /^\s*(?:export\s+)?([A-Za-z_]\w*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^#]*?))\s*(?:#.*)?$/.exec(line);
    if (!m) throw new Error(`${file}: 読めない行があります`);
    out.push([m[1], m[2] ?? m[3] ?? m[4]]);
  }
  return out;
}

// 文字列の中の // と , は残す
function jsonc(file, text) {
  const bare = text.replace(/"(?:[^"\\]|\\.)*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, (m) => (m[0] === '"' ? m : " "));
  try { return JSON.parse(bare.replace(/"(?:[^"\\]|\\.)*"|,(?=\s*[}\]])/g, (m) => (m[0] === '"' ? m : ""))); }
  catch { throw new Error(`${file}: JSON として読めません`); }
}

function at(ref, value, pointer) {
  for (const k of pointer?.split(".") ?? []) {
    if (value === null || typeof value !== "object" || !Object.hasOwn(value, k)) throw new Error(`${ref}: ${pointer} がありません`);
    value = value[k];
  }
  return value;
}

const flatten = (v, key = "") =>
  v !== null && typeof v === "object" ? Object.entries(v).flatMap(([k, x]) => flatten(x, key ? `${key}.${k}` : k)) : [[key, String(v)]];

// ファイルが名乗っている値: [契約のキー, 値]
function claimsOf(ref, { base, value, pairs }, kind) {
  const out = [];
  if (kind) for (const b of KINDS[kind].backends(pairs)) out.push(["backend", b]);
  for (const [key, v] of pairs) if (/(^|\.)APP_VARIANT$/.test(key)) out.push(["APP_VARIANT", v]);
  if (/^tauri(\.[\w-]+)?\.conf\.json$/.test(base)) {
    if (value.identifier !== undefined) out.push(["identifier", value.identifier]);
    const endpoints = value.plugins?.updater?.endpoints;
    if (endpoints !== undefined) out.push(["updater", !Array.isArray(endpoints) || endpoints.length > 1 ? endpoints : endpoints.length ? endpoints[0] : null]);
  }
  if (/^wrangler[\w.-]*\.jsonc?$/.test(base)) for (const [key, v] of pairs) if (/(^|\.)(route|routes\.\d+)(\.pattern)?$/.test(key)) out.push(["urls", `https://${v}`]);
  return out;
}

// --- 版
function checkVersion(repo, name, v, errs) {
  const want = versionAt(repo, v.source, errs);
  for (const c of v.copies ?? []) {
    const got = versionAt(repo, c, errs);
    if (want && got && got !== want) errs.push(`${name}: 版が揃っていません。正の ${v.source} は ${want}、${c} は ${got}`);
  }
  for (const f of v.ignore ?? []) if (!repo.files.has(f)) errs.push(`${f} は git に入っていません`);
}

function versionAt(repo, ref, errs) {
  try {
    const [file, pointer] = ref.split("#");
    if (!repo.files.has(file)) throw new Error(`${file} は git に入っていません`);
    const text = readText(repo, file);
    const found = /\.jsonc?$/.test(file) ? [at(ref, jsonc(file, text), pointer)] : file.endsWith(".toml") ? tomlValues(text, pointer) : jsValues(text, pointer);
    if (found.length !== 1 || typeof found[0] !== "string" || !found[0]) throw new Error(`${ref}: 版が 1 つに決まりません`);
    return found[0];
  } catch (e) { errs.push(e.message); return null; }
}

function tomlValues(text, pointer) {
  const keys = pointer.split("."), key = keys.pop(), out = [];
  let section = "";
  for (const line of text.split(/\r?\n/)) {
    const s = /^\s*\[([^[\]]+)\]\s*(?:#.*)?$/.exec(line);
    if (s) section = s[1].trim();
    const m = /^\s*([\w-]+)\s*=\s*"([^"]*)"/.exec(line);
    if (m && m[1] === key && section === keys.join(".")) out.push(m[2]);
  }
  return out;
}

const jsValues = (text, key) =>
  [...text.matchAll(/^\s*([\w-]+)\s*:\s*(["'])([^"']*)\2\s*,?\s*(?:\/\/.*)?$/gm)].filter((m) => m[1] === key).map((m) => m[3]);

// --- script の名前。名前を揃える（R-A4）までは警告だけ
const VERBS = ["build", "push", "release", "publish", "deploy", "submit"];
const ALIASES = { prod: "production", development: "dev", develop: "dev" };
function scriptWarnings(repo) {
  const out = [];
  for (const f of [...repo.files].filter((f) => path.basename(f) === "package.json")) {
    let scripts;
    try { scripts = JSON.parse(repo.text(f)).scripts ?? {}; } catch { out.push(`${f} が読めません`); continue; }
    for (const name of Object.keys(scripts)) {
      const p = name.split(":"), env = p.at(-1);
      if (p.length < 2 || !VERBS.includes(p[0]) || ENVS.includes(env)) continue;
      out.push(`${f} の ${name}: ${ALIASES[env] ? `環境の名前は ${ALIASES[env]} です` : "<動詞>:<面>:<環境> になっていません"}`);
    }
  }
  return out;
}
