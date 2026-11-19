<script lang="ts">
  import InstallTerminal from './InstallTerminal.svelte';
  import { messages, type Language } from '$lib/i18n';
  import { site } from '$lib/site';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
</script>

<!-- ダウンロードのボタンと、Homebrew で入れるコマンドを「or」で並べる節。ヘッダーの Download のリンクの行き先。 -->
<section id="download" class="download-section" aria-labelledby="download-heading">
  <h2 id="download-heading">{text.downloadHeading}</h2>
  {#if site.downloadUrl}
    <a class="download-button" href={site.downloadUrl}>
      {text.download}
      <span class="download-icon" aria-hidden="true">
        <svg width="16" height="16" viewBox="0 0 14 14"><path d="M7 2.5v6.5M4.2 6.4L7 9.2l2.8-2.8M3 11.5h8" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" /></svg>
      </span>
    </a>
  {:else}
    <span class="download-button unavailable" aria-disabled="true">{text.comingSoon}</span>
  {/if}
  <p class="separator">
    <span class="separator-line" aria-hidden="true"></span>
    {text.installSeparator}
    <span class="separator-line" aria-hidden="true"></span>
  </p>
  <InstallTerminal {language} />
  <p class="requirement">
    <span>{text.requirementPlatform}</span><span class="requirement-dot">{' · '}</span><span class="requirement-updates">{text.requirementUpdates}</span>
  </p>
</section>

<style>
.download-section { display: flex; flex-direction: column; align-items: center; gap: var(--download-gap); padding: 0 var(--page-gutter) var(--download-bottom-space); }
h2 { margin-bottom: var(--download-heading-space); color: var(--color-heading); font-size: var(--section-title-size); font-weight: 600; letter-spacing: var(--section-title-tracking); line-height: var(--section-title-line); text-align: center; }
.download-button { display: inline-flex; align-items: center; gap: var(--spacing-4); min-height: var(--hero-button-height); padding: var(--spacing-2) var(--spacing-2) var(--spacing-2) var(--spacing-8); background: var(--surface-ink); background-clip: padding-box; border: var(--hero-button-border) solid var(--color-white-border); border-radius: var(--radius-full); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: var(--text-base); font-weight: 600; line-height: 1; }
.unavailable { padding-right: var(--spacing-8); }
.download-icon { display: flex; align-items: center; justify-content: center; width: var(--hero-orb-size); height: var(--hero-orb-size); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: var(--shadow-red); }
.download-icon svg { transition: transform var(--motion-hover) var(--ease-out); }
.download-button:hover .download-icon svg { transform: translateY(var(--motion-arrow-shift)); }
.separator { display: flex; align-items: center; gap: var(--or-gap); color: var(--color-steel); font: var(--text-label)/16px var(--font-mono); letter-spacing: var(--or-tracking); text-transform: uppercase; }
.separator-line { width: var(--or-line-width); height: 1px; background: var(--color-line); }
.requirement { color: var(--color-steel); font: var(--text-label)/16px var(--font-mono); letter-spacing: var(--tracking-label); text-align: center; }
@media (max-width: 767px) {
  .requirement-dot { display: none; }
  .requirement-updates { display: block; }
}
</style>
