<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import { site } from '$lib/site';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
  // 先頭（brew）を太く、オプション（--cask）を淡く見せるため、語ごとに分ける。
  const words = site.brewInstallCommand.split(' ');
</script>

<svelte:head>
  <!-- コピーのボタンを動かす小さなスクリプト。ハイドレーションはしない（csr = false のまま）。 -->
  <script src="/install-copy.js" defer></script>
</svelte:head>

<!--
  ターミナル風の枠。コピーのボタンは hidden で出しておき、static/install-copy.js が動いたときだけ見せる。
  広い幅ではコマンドの右、767px 以下ではタイトルバーの右端に置く（同じボタンをグリッドの位置だけで動かす）。
-->
<div class="terminal">
  <div class="title-bar" aria-hidden="true">
    <span class="dot red"></span>
    <span class="dot yellow"></span>
    <span class="dot green"></span>
    <span class="title">{text.terminalTitle}</span>
  </div>
  <div class="command-line">
    <div class="command-scroll">
      <span class="prompt" aria-hidden="true">$</span>
      <code id="install-command">{#each words as word, index}{#if index > 0}{' '}{/if}<span class:program={index === 0} class:option={word.startsWith('--')}>{word}</span>{/each}</code>
    </div>
  </div>
  <button class="copy-button" type="button" hidden data-copy-command={site.brewInstallCommand} aria-describedby="install-command">
    <svg class="copy-icon" width="14" height="14" viewBox="0 0 14 14" aria-hidden="true">
      <rect x="4.75" y="4.75" width="7.5" height="7.5" rx="1.6" fill="none" stroke="currentColor" stroke-width="1.5" />
      <path d="M9.25 4.75V3.4c0-.9-.7-1.6-1.6-1.6H3.4c-.9 0-1.6.7-1.6 1.6v4.25c0 .9.7 1.6 1.6 1.6h1.35" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
    </svg>
    <svg class="copied-icon" width="14" height="14" viewBox="0 0 14 14" aria-hidden="true">
      <path d="M2.75 7.4l2.8 2.8 5.7-6.1" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
    <span class="copy-label">{text.copyCommand}</span>
    <span class="copied-label">{text.commandCopied}</span>
  </button>
  <span class="status" role="status" aria-live="polite" data-copy-status data-message={text.commandCopied}></span>
</div>

<style>
.terminal { display: grid; grid-template-columns: minmax(0, 1fr) auto; width: min(100%, var(--terminal-width)); overflow: clip; border-radius: var(--terminal-radius); background: var(--terminal-surface); box-shadow: var(--terminal-shadow); }
.title-bar { position: relative; grid-area: 1 / 1 / 2 / 3; display: flex; align-items: center; gap: var(--terminal-dot-gap); height: var(--terminal-bar-height); padding: 0 var(--terminal-bar-padding-end) 0 var(--terminal-bar-padding-start); border-bottom: 1px solid var(--terminal-bar-border); }
.dot { flex-shrink: 0; width: var(--terminal-dot-size); height: var(--terminal-dot-size); border-radius: var(--radius-full); }
.red { background: var(--terminal-dot-red); }
.yellow { background: var(--terminal-dot-yellow); }
.green { background: var(--terminal-dot-green); }
.title { position: absolute; inset-inline: 0; color: var(--terminal-title-color); font: var(--text-label)/16px var(--font-mono); letter-spacing: var(--tracking-label); text-align: center; pointer-events: none; }
.command-line { position: relative; grid-area: 2 / 1 / 3 / 2; min-width: 0; }
.command-scroll { display: flex; align-items: center; gap: var(--terminal-prompt-gap); padding: var(--terminal-body-padding-block) var(--terminal-body-padding-end) var(--terminal-body-padding-block) var(--terminal-body-padding-start); overflow-x: auto; scrollbar-width: none; }
.command-scroll::-webkit-scrollbar { display: none; }
.prompt { flex-shrink: 0; color: var(--terminal-prompt-color); font: 500 var(--terminal-font-size)/var(--terminal-line-height) var(--font-mono); user-select: none; }
code { color: var(--terminal-text-color); font: var(--terminal-font-size)/var(--terminal-line-height) var(--font-mono); white-space: pre; }
.program { font-weight: 500; }
.option { color: var(--terminal-option-color); }
.copy-button { position: relative; z-index: 1; grid-area: 2 / 2 / 3 / 3; align-self: center; display: inline-flex; align-items: center; gap: var(--copy-button-gap); height: var(--copy-button-height); margin: 0 var(--terminal-body-padding-end) 0 0; padding: 0 var(--copy-button-padding-end) 0 var(--copy-button-padding-start); border: 0; border-radius: var(--radius-full); background: var(--surface-white); box-shadow: var(--shadow-copy); color: var(--color-ink); font: 600 var(--copy-label-size)/var(--copy-label-line) var(--font-sans); white-space: nowrap; cursor: pointer; transition: transform var(--motion-hover) var(--ease-out), box-shadow var(--motion-hover) var(--ease-out); }
.copy-button[hidden] { display: none; }
.copy-button svg { flex-shrink: 0; width: var(--copy-icon-size); height: var(--copy-icon-size); }
.copy-button:hover { transform: translateY(var(--motion-lift)); }
.copy-button:active { transform: scale(var(--motion-press-scale)); }
.copy-button:focus-visible { outline: 2px solid var(--color-accent); outline-offset: var(--spacing-1); }
/* コピー済みの印（data-copied）は static/install-copy.js が付け外しする。 */
.copied-icon, .copied-label { display: none; }
.copy-button:global([data-copied]) { background: var(--surface-red); box-shadow: var(--shadow-copy-done); color: var(--color-clean-bg); }
.copy-button:global([data-copied]) .copy-icon, .copy-button:global([data-copied]) .copy-label { display: none; }
.copy-button:global([data-copied]) .copied-icon, .copy-button:global([data-copied]) .copied-label { display: inline; }
.status { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
@media (max-width: 767px) {
  .title { display: none; }
  .command-line { grid-column: 1 / 3; }
  .command-line::after { content: ''; position: absolute; inset-block: 0; right: 0; width: var(--terminal-fade-width); background: var(--terminal-fade); pointer-events: none; }
  code { padding-right: var(--terminal-fade-width); }
  .copy-button { grid-area: 1 / 2 / 2 / 3; margin-right: var(--terminal-bar-padding-end); }
}
@media (prefers-reduced-motion: reduce) {
  .copy-button:hover, .copy-button:active { transform: none; }
}
</style>
