#!/usr/bin/env node
// e2e/specs/**/*.md の書式と、生成物（e2e/tests/Generated/**）との対応を確かめる（`make e2e-lint`）。
//
// 見るのは「生成に必要な形が揃っているか」と「md と生成物がずれていないか」だけで、
// 中身の良し悪しは planner と人のレビューの仕事。とくに **各シナリオに UI に依存しない
// 検証点があるか** を落とさない。これが無いと「画面にだけ反映されて、状態・画像・
// クリップボードは変わっていない」を素通りするテストが生成される。
//
// 使い方:
//   node e2e/check-specs.mjs               書式・検証点・生成物との対応をすべて確かめる
//   node e2e/check-specs.mjs --specs-only  書式と検証点だけを確かめる（生成物がまだ無い段階）
//   node e2e/check-specs.mjs --hash <md>   その md の SHA-256 を出力する（生成ファイルの先頭に入れる値）
//
// 問題があれば全部並べて、終了コード 1 で終わる。最後に spec の本数とシナリオの件数を 1 行で出す。
// 依存なし（Node の標準モジュールだけ）。
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const E2E = dirname(fileURLToPath(import.meta.url));
const ROOT = dirname(E2E);
const SPECS = join(E2E, "specs");
const GENERATED = join(E2E, "tests", "Generated");

/** md に、この順で並んでいなければならない節 */
const SECTIONS = ["## 概要", "## 前提", "## 目的", "## シナリオ"];

/** シナリオの分け方の見出し */
const GROUPS = ["### 正常系", "### 準正常系"];

/** UI に依存しない検証点と見なす書き出し（e2e/README.md「検証点」） */
const CHECKPOINTS = ["クリップボードに入った文章で、", "保存された画像で、", "アプリの状態で、"];

/** ファイル名とディレクトリ名に使ってよい形（ケバブケース） */
const KEBAB = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/** 区切り文字を / に揃えた、リポジトリの根からのパス */
function repoPath(path) {
  return relative(ROOT, path).split(sep).join("/");
}

/** ディレクトリの下のファイルを再帰で集める */
function walk(dir, accept) {
  if (!existsSync(dir)) {
    return [];
  }
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      return walk(path, accept);
    }
    return accept(name) ? [path] : [];
  });
}

/** 仕様の md（`_` で始まるひな形を除く） */
function specFiles() {
  return walk(SPECS, (name) => name.endsWith(".md") && !name.startsWith("_")).sort();
}

/** ケバブケースをパスカルケースにする（`copy-prompt` → `CopyPrompt`） */
function pascal(kebab) {
  return kebab
    .split("-")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join("");
}

/** md のパスから、対応する生成ファイルのパスとクラス名を決める */
function generatedFor(specPath) {
  const parts = relative(SPECS, specPath).split(sep);
  if (parts.length !== 2) {
    return null;
  }
  const [dir, file] = parts;
  const name = file.replace(/\.md$/, "");
  const className = `${pascal(dir)}${pascal(name)}Tests`;
  return { dir, name, className, path: join(GENERATED, dir, `${className}.swift`) };
}

/** md の内容の SHA-256（16 進の小文字） */
function sha256(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

/** md を見出しの単位で読み、書式の問題とシナリオ名の一覧を返す */
function inspectSpec(text) {
  const problems = [];
  const lines = text.split("\n");
  if (!text.startsWith("# ")) {
    problems.push("先頭が `# <機能名>` になっていない");
  }

  let cursor = -1;
  for (const section of SECTIONS) {
    const index = lines.findIndex((line) => line.trim() === section);
    if (index === -1) {
      problems.push(`\`${section}\` が無い`);
    } else if (index < cursor) {
      problems.push(`\`${section}\` の位置が順番どおりでない（${SECTIONS.join(" → ")}）`);
    } else {
      cursor = index;
    }
  }

  const scenarioStart = lines.findIndex((line) => line.trim() === "## シナリオ");
  if (!lines.some((line) => GROUPS.includes(line.trim()))) {
    problems.push("`### 正常系` も `### 準正常系` も無い");
  }

  const scenarios = [];
  let group = null;
  let current = null;
  lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.startsWith("### ") && !trimmed.startsWith("#### ")) {
      group = GROUPS.includes(trimmed) ? trimmed : null;
      if (!GROUPS.includes(trimmed)) {
        problems.push(`\`${trimmed}\` は使えない見出し（${GROUPS.join(" / ")} のどちらか）`);
      }
      current = null;
      return;
    }
    if (trimmed.startsWith("## ") || trimmed.startsWith("# ")) {
      current = null;
      return;
    }
    if (trimmed.startsWith("#### ")) {
      const name = trimmed.slice(5).trim();
      current = { name, line: index + 1, body: [] };
      scenarios.push(current);
      if (scenarioStart === -1 || index < scenarioStart) {
        problems.push(`「${name}」が \`## シナリオ\` の外にある`);
      }
      if (group === null) {
        problems.push(`「${name}」が \`### 正常系\` / \`### 準正常系\` の下にない`);
      }
      return;
    }
    if (current) {
      current.body.push(line);
    }
  });

  if (scenarios.length === 0) {
    problems.push("`####` のシナリオが 1 つも無い");
  }

  const seen = new Set();
  for (const scenario of scenarios) {
    if (scenario.name === "") {
      problems.push(`${scenario.line} 行目の \`####\` にシナリオ名が無い`);
      continue;
    }
    if (seen.has(scenario.name)) {
      problems.push(`「${scenario.name}」が同じファイルに 2 つある（シナリオ名は生成ファイルとの対応に使う）`);
    }
    seen.add(scenario.name);

    const body = scenario.body.map((line) => line.trim());
    const expected = body.indexOf("期待される結果:");
    const forbidden = body.indexOf("してはいけないこと:");
    if (expected === -1) {
      problems.push(`「${scenario.name}」に \`期待される結果:\` が無い`);
    }
    if (forbidden === -1) {
      problems.push(`「${scenario.name}」に \`してはいけないこと:\` が無い`);
    }
    if (expected !== -1 && forbidden !== -1 && forbidden < expected) {
      problems.push(`「${scenario.name}」の \`してはいけないこと:\` が \`期待される結果:\` より前にある`);
    }
    if (expected !== -1) {
      const end = forbidden > expected ? forbidden : body.length;
      const results = body.slice(expected + 1, end).filter((line) => line.startsWith("- "));
      if (results.length === 0) {
        problems.push(`「${scenario.name}」の \`期待される結果:\` に箇条書きが無い`);
      }
      if (!results.some((line) => CHECKPOINTS.some((checkpoint) => line.includes(checkpoint)))) {
        problems.push(
          `「${scenario.name}」の \`期待される結果:\` に UI に依存しない検証点が無い（${CHECKPOINTS.map((c) => `「${c}〜」`).join(" / ")} のどれか）`,
        );
      }
    }
    if (forbidden !== -1) {
      const items = body.slice(forbidden + 1).filter((line) => line.startsWith("- "));
      if (items.length === 0) {
        problems.push(`「${scenario.name}」の \`してはいけないこと:\` に箇条書きが無い`);
      }
    }
  }

  return { problems, scenarios: scenarios.map((scenario) => scenario.name) };
}

/** 生成ファイルが md と対応しているかを確かめる */
function inspectGenerated(specPath, target, scenarioNames) {
  const problems = [];
  const shown = repoPath(target.path);
  if (!existsSync(target.path)) {
    problems.push(`生成ファイル \`${shown}\` が無い（generator で作る）`);
    return problems;
  }

  const text = readFileSync(target.path, "utf8");
  const lines = text.split("\n");
  const expectedSpec = repoPath(specPath);
  const specLine = lines[0]?.match(/^\/\/ spec: (.+)$/);
  const hashLine = lines[1]?.match(/^\/\/ spec-sha256: ([0-9a-f]+)$/);
  if (!specLine) {
    problems.push(`\`${shown}\` の 1 行目が \`// spec: ${expectedSpec}\` になっていない`);
  } else if (specLine[1].trim() !== expectedSpec) {
    problems.push(`\`${shown}\` の \`// spec:\` が \`${specLine[1].trim()}\`（正しくは \`${expectedSpec}\`）`);
  }
  if (!hashLine) {
    problems.push(`\`${shown}\` の 2 行目が \`// spec-sha256: <md の SHA-256>\` になっていない`);
  } else if (hashLine[1] !== sha256(specPath)) {
    problems.push(`\`${shown}\` の \`// spec-sha256:\` が md の内容と合わない（md を直したあと再生成していない）`);
  }

  const classPattern = new RegExp(`\\bclass\\s+${target.className}\\s*:`);
  if (!classPattern.test(text)) {
    problems.push(`\`${shown}\` にクラス \`${target.className}\` が無い`);
  }

  const generatedNames = lines
    .map((line) => line.trim().match(/^\/\/ scenario: (.+)$/))
    .filter(Boolean)
    .map((match) => match[1].trim());
  const counts = new Map();
  for (const name of generatedNames) {
    counts.set(name, (counts.get(name) ?? 0) + 1);
  }
  for (const name of scenarioNames) {
    if (!counts.has(name)) {
      problems.push(`\`${shown}\` に \`// scenario: ${name}\` が無い`);
    }
  }
  for (const [name, count] of counts) {
    if (!scenarioNames.includes(name)) {
      problems.push(`\`${shown}\` の \`// scenario: ${name}\` に当たるシナリオが md に無い`);
    } else if (count > 1) {
      problems.push(`\`${shown}\` に \`// scenario: ${name}\` が ${count} つある（1 シナリオに 1 テスト）`);
    }
  }
  return problems;
}

function main(argv) {
  if (argv[0] === "--hash") {
    const path = argv[1];
    if (!path || !existsSync(path)) {
      console.log(`md が見つからない: ${path ?? "（パスが無い）"}`);
      process.exitCode = 1;
      return;
    }
    console.log(sha256(path));
    return;
  }

  const unknown = argv.filter((arg) => arg !== "--specs-only");
  if (unknown.length > 0) {
    console.log(`知らない引数: ${unknown.join(" ")}（--specs-only / --hash <md のパス>）`);
    process.exitCode = 1;
    return;
  }
  const specsOnly = argv.includes("--specs-only");

  const failures = [];
  const expectedGenerated = new Set();
  let specCount = 0;
  let scenarioCount = 0;

  for (const specPath of specFiles()) {
    specCount += 1;
    const problems = [];
    const target = generatedFor(specPath);
    if (target === null) {
      problems.push("置き場が `e2e/specs/<ディレクトリ>/<名前>.md` の深さになっていない");
    } else {
      expectedGenerated.add(target.path);
      if (!KEBAB.test(target.dir) || !KEBAB.test(target.name)) {
        problems.push("ディレクトリ名とファイル名はケバブケース（英小文字・数字・`-`）にする");
      }
    }

    const { problems: formatProblems, scenarios } = inspectSpec(readFileSync(specPath, "utf8"));
    scenarioCount += scenarios.length;
    problems.push(...formatProblems);

    if (!specsOnly && target !== null) {
      problems.push(...inspectGenerated(specPath, target, scenarios));
    }
    if (problems.length > 0) {
      failures.push([repoPath(specPath), problems]);
    }
  }

  if (!specsOnly) {
    const orphans = walk(GENERATED, (name) => name.endsWith(".swift")).filter((path) => !expectedGenerated.has(path));
    for (const orphan of orphans.sort()) {
      failures.push([repoPath(orphan), ["対応する md が無い生成ファイル（md を消したなら、生成ファイルも消す）"]]);
    }
  }

  for (const [file, problems] of failures) {
    console.log(`\n${file}`);
    for (const problem of problems) {
      console.log(`  - ${problem}`);
    }
  }
  if (failures.length > 0) {
    console.log(`\n${failures.length} 件のファイルに問題がある（e2e/README.md「md の書式」「spec と生成物の対応」）`);
    process.exitCode = 1;
  }
  const mode = specsOnly ? "書式と検証点のみ" : "書式・検証点・生成物との対応";
  const verdict = failures.length > 0 ? "NG" : "OK";
  console.log(`spec: ${specCount} 本 / シナリオ: ${scenarioCount} 件 / ${mode}: ${verdict}`);
}

main(process.argv.slice(2));
