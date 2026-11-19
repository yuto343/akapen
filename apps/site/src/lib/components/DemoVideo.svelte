<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
  // 動画は scripts/record-demo.mjs が Demo.svelte から書き出す。
  const source = $derived(`/demo/akapen-demo-${language}.mp4`);
  const poster = $derived(`/demo/akapen-demo-${language}.jpg`);
</script>

<div class="demo-section">
  <div class="demo-frame">
    <!-- 自動再生はせず、再生ボタンで始める。クライアント JS を出さないため、再生そのものはブラウザ標準の動画の操作に任せる。 -->
    <video class="demo-video" controls playsinline preload="metadata" {poster} aria-label={text.demoLabel} width="1280" height="800">
      <source src={source} type="video/mp4" />
      {text.demoFallback}
    </video>
    <!-- 見た目だけの再生ボタン。クリックは下の動画に通す。 -->
    <span class="play-overlay" aria-hidden="true">
      <span class="play-button">
        <svg viewBox="0 0 24 24"><path d="M8 5.5v13l10.5-6.5Z" fill="currentColor" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" /></svg>
      </span>
    </span>
  </div>
</div>

<style>
.demo-section { padding: 0 var(--page-gutter) var(--demo-bottom-space); }
.demo-frame {
  --demo-unit: calc(100cqw / 1280);
  --demo-radius: calc(32 * var(--demo-unit));
  position: relative;
  width: 100%;
  max-width: 1280px;
  margin-inline: auto;
  container-type: inline-size;
  cursor: pointer;
}
.demo-video {
  display: block;
  width: 100%;
  height: auto;
  aspect-ratio: 1280 / 800;
  border-radius: var(--demo-radius);
  outline: calc(8 * var(--demo-unit)) solid var(--color-white-border);
  background: var(--surface-desktop);
  box-shadow: var(--shadow-desktop);
  object-fit: cover;
}
.demo-video:focus-visible { outline-color: var(--color-accent); }
.play-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--demo-radius);
  background: var(--color-poster-dim);
  pointer-events: none;
  /* 一度隠したら出し直さない（再生中に重ならないように、戻りの遷移を事実上止める）。 */
  transition: opacity var(--motion-hover) var(--ease-out) var(--play-overlay-return), visibility 0s linear var(--play-overlay-return);
}
.play-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: clamp(56px, calc(112 * var(--demo-unit)), 112px);
  aspect-ratio: 1;
  border: clamp(2px, calc(4 * var(--demo-unit)), 4px) solid var(--color-white-border);
  border-radius: var(--radius-full);
  background: var(--surface-red);
  box-shadow: var(--shadow-red), var(--shadow-play);
  color: var(--color-clean-bg);
  transition: transform var(--motion-hover) var(--ease-spring), box-shadow var(--motion-hover) var(--ease-out);
}
.play-button svg { width: 40%; height: 40%; margin-left: 6%; }
.demo-frame:hover .play-button { transform: scale(var(--motion-play-hover-scale)); box-shadow: var(--shadow-red), var(--shadow-play-hover); }
.demo-frame:active .play-button { transform: scale(var(--motion-press-scale)); }
/* 動画を押す（フォーカスが動画に移る）と、再生が始まるので隠す。 */
.demo-frame:has(.demo-video:focus) .play-overlay {
  opacity: 0;
  visibility: hidden;
  transition: opacity var(--motion-hover) var(--ease-out), visibility 0s linear var(--motion-hover);
}
/* 再生中かどうかを CSS で見分けられるブラウザ（Safari など）では、止めている間だけ出す。 */
@supports selector(video:paused) {
  .play-overlay { transition: opacity var(--motion-hover) var(--ease-out), visibility 0s; }
  .demo-frame:has(.demo-video:focus) .play-overlay { opacity: 1; visibility: visible; }
  .demo-frame:has(.demo-video:playing) .play-overlay {
    opacity: 0;
    visibility: hidden;
    transition: opacity var(--motion-hover) var(--ease-out), visibility 0s linear var(--motion-hover);
  }
}
@media (prefers-reduced-motion: reduce) {
  /* 動きは止めても、一度隠した再生ボタンを出し直さない仕組みは残す。 */
  .play-overlay { transition: visibility 0s linear var(--play-overlay-return) !important; }
  .demo-frame:has(.demo-video:focus) .play-overlay { transition: visibility 0s !important; }
}
@media (prefers-reduced-motion: reduce) {
  @supports selector(video:paused) {
    .play-overlay, .demo-frame:has(.demo-video:focus) .play-overlay { transition: none !important; }
  }
}
</style>
