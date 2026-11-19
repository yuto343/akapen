<script lang="ts">
  import HeroLogo from './HeroLogo.svelte';
  import { messages, type Language } from '$lib/i18n';
  import { site } from '$lib/site';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
</script>

<section class="hero">
  <div class="logo-reveal"><HeroLogo label={text.brand} /></div>
  <div class="copy">
    <h1 aria-label={text.headline}>
      <span class="phrase">{#if text.headlineNoteStart}<span class="headline-note" aria-hidden="true">{text.headlineNoteStart}</span>{/if}{text.headlineStart}</span>{' '}
      <span class="phrase">{#if text.headlineNoteReturn}<span class="headline-note" aria-hidden="true">{text.headlineNoteReturn}</span>{/if}{text.headlineReturn} <span class="highlight">{text.headlineHighlight}</span> {text.headlineEnd}</span>
    </h1>
  </div>
  <div class="download">
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
    <p class="requirement">{text.requirement}</p>
  </div>
</section>

<style>
.hero { display: flex; flex-direction: column; align-items: center; gap: var(--spacing-10); padding: var(--hero-padding-top) var(--page-gutter) var(--hero-bottom-space); }
.logo-reveal { width: 100%; max-width: var(--hero-logo-width); }
.copy { padding-top: 0; }
h1 { color: var(--color-heading); font-size: var(--hero-title-size); font-weight: 600; letter-spacing: -.03em; line-height: var(--hero-title-line); text-align: center; }
.phrase { display: inline-block; position: relative; }
.headline-note { position: absolute; bottom: 100%; left: 0; width: 100%; padding-bottom: var(--spacing-3); font-size: var(--hero-note-size); font-weight: 600; letter-spacing: .04em; line-height: 1; color: var(--color-ink-2); }
:global(html:lang(ja)) .hero { --motion-button-delay: calc(var(--motion-note-delay) + var(--motion-stagger)); }
:global(html:lang(ja)) .copy { padding-top: var(--hero-note-space); }
.highlight { position: relative; isolation: isolate; }
.highlight::after { content: ''; position: absolute; z-index: -1; left: 0; right: 0; bottom: .08em; height: .42em; background: var(--color-marker); mix-blend-mode: multiply; rotate: -2deg; clip-path: polygon(0 9%, 96% 0, 100% 92%, 3% 100%); }
.download { display: flex; flex-direction: column; align-items: center; gap: var(--spacing-4); }
.download-button { display: inline-flex; align-items: center; gap: var(--spacing-4); min-height: var(--hero-button-height); padding: var(--spacing-2) var(--spacing-2) var(--spacing-2) var(--spacing-8); background: var(--surface-ink); background-clip: padding-box; border: var(--hero-button-border) solid var(--color-white-border); border-radius: var(--radius-full); box-shadow: var(--shadow-ink); color: var(--color-clean-bg); font-size: var(--text-base); font-weight: 600; line-height: 1; }
.unavailable { padding-right: var(--spacing-8); }
.download-icon { display: flex; align-items: center; justify-content: center; width: var(--hero-orb-size); height: var(--hero-orb-size); border-radius: var(--radius-full); background: var(--surface-red); box-shadow: var(--shadow-red); }
.download-icon svg { transition: transform var(--motion-hover) var(--ease-out); }
.download-button:hover .download-icon svg { transform: translateY(var(--motion-arrow-shift)); }
.requirement { color: var(--color-steel); font: var(--text-label)/16px var(--font-mono); letter-spacing: var(--tracking-label); text-align: center; }
@media (prefers-reduced-motion: no-preference) {
  .logo-reveal, .copy, .download { animation: hero-reveal var(--motion-reveal) var(--ease-out) both; }
  .copy { animation-delay: var(--motion-stagger); }
  .download { animation-delay: var(--motion-button-delay); }
  .highlight::after { animation: marker-reveal var(--motion-marker) var(--ease-out) var(--motion-marker-delay) both; }
  .headline-note { animation: hero-reveal var(--motion-reveal) var(--ease-out) var(--motion-note-delay) both; }
}
@media (max-width: 767px) {
  :global(html:lang(ja)) h1 { display: flex; flex-direction: column; gap: var(--hero-mobile-phrase-gap); }
}
</style>
