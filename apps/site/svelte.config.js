import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

// デモ動画を撮るときだけ、撮影用のページ（src/demo-recording）を routes に差し替える。
const recordingDemo = process.env.AKAPEN_DEMO_RECORDING === '1';

/** @type {import('@sveltejs/kit').Config} */
export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    files: recordingDemo ? { routes: 'src/demo-recording' } : {}
  }
};
