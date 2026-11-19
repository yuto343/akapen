// LP のデモ動画（static/demo/）を作る。
// 撮影用のページ（src/demo-recording）を開発サーバーで開き、CSS アニメーションを 1 コマずつ止めて撮り、ffmpeg で mp4 にする。
// 使い方: pnpm -C apps/site record:demo（ffmpeg と Playwright の Chromium が要る）。--poster-only でポスターだけ撮り直す。
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const siteDirectory = fileURLToPath(new URL('..', import.meta.url));
const outputDirectory = fileURLToPath(new URL('../static/demo/', import.meta.url));
const port = 5281;
const width = 1280;
const height = 800;
const scale = 2;
const framesPerSecond = 30;
const durationSeconds = 18;
// ポスターには、赤枠とコメントが出そろった瞬間を使う。
const posterSeconds = 6.2;
const posterOnly = process.argv.includes('--poster-only');
const languages = [
  { code: 'en', path: '/' },
  { code: 'ja', path: '/ja/' }
];

/** 撮影用のページだけを持つ開発サーバーを立てる。 */
async function startServer() {
  const server = spawn('pnpm', ['exec', 'vite', 'dev', '--port', String(port), '--strictPort'], {
    cwd: siteDirectory,
    env: { ...process.env, AKAPEN_DEMO_RECORDING: '1' },
    stdio: ['ignore', 'pipe', 'inherit']
  });
  await new Promise((resolve, reject) => {
    server.on('exit', (code) => reject(new Error(`vite が終了した（${code}）`)));
    server.stdout.on('data', (chunk) => {
      if (String(chunk).includes(`${port}`)) {
        resolve(undefined);
      }
    });
  });
  return server;
}

/** ページ上のアニメーションをすべて止め、指定した時刻に合わせる。 */
async function seek(page, milliseconds) {
  await page.evaluate((time) => {
    for (const animation of document.getAnimations()) {
      animation.pause();
      animation.currentTime = time;
    }
  }, milliseconds);
}

/** 1 言語ぶんの動画とポスターを書き出す。 */
async function record(browser, language) {
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: scale,
    reducedMotion: 'no-preference'
  });
  await page.goto(`http://127.0.0.1:${port}${language.path}`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  // 再生ボタンはポスターに描き込まず、LP の DemoVideo.svelte が重ねる。
  await seek(page, posterSeconds * 1000);
  await page.screenshot({ path: `${outputDirectory}akapen-demo-${language.code}.jpg`, type: 'jpeg', quality: 88 });
  if (posterOnly) {
    await page.close();
    console.log(`${language.code}: ポスターを書き出した`);
    return;
  }

  const encoder = spawn('ffmpeg', [
    '-y',
    '-loglevel', 'error',
    '-f', 'image2pipe',
    '-framerate', String(framesPerSecond),
    '-c:v', 'png',
    '-i', '-',
    '-c:v', 'libx264',
    '-preset', 'slow',
    '-crf', '20',
    '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart',
    `${outputDirectory}akapen-demo-${language.code}.mp4`
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const finished = new Promise((resolve, reject) => {
    encoder.on('exit', (code) => (code === 0 ? resolve(undefined) : reject(new Error(`ffmpeg が失敗した（${code}）`))));
  });

  const frameCount = durationSeconds * framesPerSecond;
  for (let frame = 0; frame < frameCount; frame += 1) {
    await seek(page, (frame * 1000) / framesPerSecond);
    const image = await page.screenshot({ type: 'png' });
    if (!encoder.stdin.write(image)) {
      await new Promise((resolve) => encoder.stdin.once('drain', resolve));
    }
  }
  encoder.stdin.end();
  await finished;
  await page.close();
  console.log(`${language.code}: ${frameCount} コマを書き出した`);
}

await mkdir(outputDirectory, { recursive: true });
const server = await startServer();
const browser = await chromium.launch();
try {
  for (const language of languages) {
    await record(browser, language);
  }
} finally {
  await browser.close();
  server.kill();
}
