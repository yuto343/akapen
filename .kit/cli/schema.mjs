// JSON Schema の手書きの検査。使うキーワードは type、required、properties、additionalProperties、
// enum、pattern、items、uniqueItems だけ（ADR-005: ajv を入れると install 前に動かせなくなる）。
const typeOf = (v) => (Array.isArray(v) ? "array" : v === null ? "null" : typeof v);

export function validate(schema, value, at = "") {
  const errs = [];
  const here = at || "(ルート)";
  if (schema.type && typeOf(value) !== schema.type) return [`${here}: ${schema.type} のはずが ${typeOf(value)} です`];
  if (schema.enum && !schema.enum.includes(value)) errs.push(`${here}: ${JSON.stringify(value)} は ${schema.enum.join(" / ")} のどれでもありません`);
  if (schema.pattern && typeof value === "string" && !new RegExp(schema.pattern).test(value)) errs.push(`${here}: ${JSON.stringify(value)} が形に合いません（${schema.pattern}）`);
  if (typeOf(value) === "object") {
    for (const k of schema.required ?? []) if (!(k in value)) errs.push(`${here}: ${k} がありません`);
    for (const [k, v] of Object.entries(value)) {
      const sub = schema.properties?.[k] ?? (typeof schema.additionalProperties === "object" ? schema.additionalProperties : null);
      if (sub) errs.push(...validate(sub, v, `${at}.${k}`));
      else if (schema.additionalProperties === false) errs.push(`${here}: ${k} は知らないキーです`);
    }
  }
  if (typeOf(value) === "array") {
    if (schema.uniqueItems && new Set(value.map((x) => JSON.stringify(x))).size !== value.length) errs.push(`${here}: 重複があります`);
    if (schema.items) value.forEach((x, i) => errs.push(...validate(schema.items, x, `${at}[${i}]`)));
  }
  return errs;
}

// kit.config.json の、スキーマでは書けない条件
export function configRules(cfg) {
  const errs = [];
  if ((cfg.skills ?? []).length && !(cfg.receive ?? []).includes("skills")) errs.push("skills を受け取るには receive に \"skills\" が要ります");
  if ((cfg.receive ?? []).includes("ci") && !cfg.runtime) errs.push("receive に \"ci\" があるときは runtime が要ります");
  if (cfg.release) errs.push(...releaseRules(cfg.release));
  return errs;
}

function releaseRules(rel) {
  const errs = [];
  if (!rel.surfaces.length) errs.push("release.surfaces が空です");
  if (!rel.tagPattern.includes("{version}")) errs.push("release.tagPattern に {version} がありません");
  if (rel.surfaces.length > 1 && !rel.tagPattern.includes("{surface}")) errs.push("面が 2 つ以上あるときは、release.tagPattern に {surface} が要ります");
  if (rel.records?.split("/").includes("..")) errs.push("release.records はリポジトリの中に置きます");
  if (rel.prod.confirm === false) errs.push("release.prod の確認は外せません");
  for (const env of ["dev", "prod"]) {
    const steps = rel[env].steps, at = `release.${env}.steps`;
    if (new Set(steps.map((s) => s.name)).size !== steps.length) errs.push(`${at} の name に重複があります`);
    for (const s of steps) {
      for (const x of s.surfaces ?? []) if (!rel.surfaces.includes(x)) errs.push(`${at} の ${s.name}: ${x} は release.surfaces にありません`);
      if (/(^|\s)--skip-/.test(s.run)) errs.push(`${at} の ${s.name}: --skip-* は書けません（飛ばしたものを配らないため）`);
    }
    for (const x of rel.surfaces) if (!steps.some((s) => !s.surfaces || s.surfaces.includes(x))) errs.push(`${at} に ${x} の step がありません`);
  }
  return errs;
}

// verify.config.json の、スキーマでは書けない条件
export function verifyRules(cfg) {
  const errs = [];
  if (!cfg.checks.length) errs.push("checks が空です");
  if (new Set(cfg.checks.map((c) => c.name)).size !== cfg.checks.length) errs.push("checks の name に重複があります");
  for (const c of cfg.checks) {
    if (!c.paths.length) errs.push(`${c.name}: paths が空です`);
    if (["kit-check", "setup"].includes(c.name)) errs.push(`${c.name} は kit が使う名前です`);
  }
  return errs;
}

export const ENVS = ["local", "dev", "production"];

// env.contract.json の、スキーマでは書けない条件
export function envRules(contract) {
  const errs = [];
  if (!Object.keys(contract.surfaces).length) errs.push("surfaces が空です");
  for (const [name, s] of Object.entries(contract.surfaces)) {
    if (Array.isArray(s.envs)) {
      if (!s.envs.length) errs.push(`${name}: envs が空です`);
      if (s.kind !== undefined) errs.push(`${name}: envs が名前だけの面に kind は書きません`);
      continue;
    }
    if (typeOf(s.envs) !== "object") { errs.push(`${name}: envs は環境の名前の配列か、環境ごとの値です`); continue; }
    const used = new Set(Object.values(s.envs).flatMap((e) => Object.keys(e ?? {})));
    if (used.has("backend") !== (s.kind !== undefined)) errs.push(`${name}: kind と backend は両方書くか、両方書きません`);
    for (const [env, e] of Object.entries(s.envs)) {
      if (e === null) continue;
      if (typeOf(e) !== "object" || !Object.keys(e).length) { errs.push(`${name}.${env}: 値を書くか、その環境が無いなら null にします`); continue; }
      if (e.updater !== undefined && e.updater !== null && typeof e.updater !== "string") errs.push(`${name}.${env}: updater は URL か null です`);
      for (const k of ["identifier", "backend", "updater"]) if (used.has(k) && e[k] === undefined) errs.push(`${name}.${env}: ${k} がありません（ほかの環境にはあります）`);
    }
  }
  return errs;
}
