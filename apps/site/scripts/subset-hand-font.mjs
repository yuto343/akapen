// 日本語ページの手書き風の文（フッターの supportNote）に使う Kiwi Maru を、使う文字だけのサブセット（woff2）にする。
// 使い方: pnpm -C apps/site subset:font（文言を変えたら流し直す）
// 元の TTF（約 5MB）はリポジトリに入れず、google/fonts から取得して node_modules/.cache に置く。
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';
import { messages } from '../src/lib/i18n.ts';

const sourceUrl = 'https://raw.githubusercontent.com/google/fonts/main/ofl/kiwimaru/KiwiMaru-Regular.ttf';
const licenseUrl = 'https://raw.githubusercontent.com/google/fonts/main/ofl/kiwimaru/OFL.txt';
const sourceSha256 = 'b0c3103b2639f690c1fcb44e060058383174bfd2eb72e6635bc9869b374dee87';
const cacheDirectory = fileURLToPath(new URL('../node_modules/.cache/akapen-fonts/', import.meta.url));
const outputDirectory = fileURLToPath(new URL('../static/fonts/', import.meta.url));
const outputName = 'kiwi-maru-hand.woff2';

/** 元のフォントを取得する。取得済みならキャッシュを使う。 */
async function loadSource() {
  const cachePath = `${cacheDirectory}KiwiMaru-Regular.ttf`;
  let font = await readFile(cachePath).catch(() => null);
  if (font === null) {
    const response = await fetch(sourceUrl);
    if (!response.ok) {
      throw new Error(`フォントを取得できなかった（${response.status}）`);
    }
    font = Buffer.from(await response.arrayBuffer());
    await mkdir(cacheDirectory, { recursive: true });
    await writeFile(cachePath, font);
  }
  const hash = createHash('sha256').update(font).digest('hex');
  if (hash !== sourceSha256) {
    throw new Error(`元のフォントが想定と違う（sha256: ${hash}）。中身を確かめてから sourceSha256 を更新する。`);
  }
  return font;
}

// 手書き風のフォントで出す日本語の文言。改行は字形が要らないので除く。
const text = messages.ja.supportNote.replace(/\s/g, '');
const characters = [...new Set(text)].sort().join('');

const subset = await subsetFont(await loadSource(), characters, { targetFormat: 'woff2' });
await mkdir(outputDirectory, { recursive: true });
await writeFile(`${outputDirectory}${outputName}`, subset);
const license = await fetch(licenseUrl).then((response) => response.text());
await writeFile(`${outputDirectory}OFL-KiwiMaru.txt`, license);
console.log(`${outputName}: ${characters.length} 文字, ${subset.length} バイト`);
console.log(characters);
