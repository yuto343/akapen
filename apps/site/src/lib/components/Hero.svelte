<script lang="ts">
  import HeroLogo from './HeroLogo.svelte';
  import { messages, type Language } from '$lib/i18n';
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
</section>

<style>
.hero { display: flex; flex-direction: column; align-items: center; gap: var(--spacing-10); padding: var(--hero-padding-top) var(--page-gutter) var(--hero-bottom-space); }
.logo-reveal { width: 100%; max-width: var(--hero-logo-width); }
.copy { padding-top: 0; }
h1 { color: var(--color-heading); font-size: var(--hero-title-size); font-weight: 600; letter-spacing: -.03em; line-height: var(--hero-title-line); text-align: center; }
.phrase { display: inline-block; position: relative; }
.headline-note { position: absolute; bottom: 100%; left: 0; width: 100%; padding-bottom: var(--spacing-3); font-size: var(--hero-note-size); font-weight: 600; letter-spacing: .04em; line-height: 1; color: var(--color-ink-2); }
:global(html:lang(ja)) .copy { padding-top: var(--hero-note-space); }
.highlight { position: relative; isolation: isolate; }
.highlight::after { content: ''; position: absolute; z-index: -1; left: 0; right: 0; bottom: .08em; height: .42em; background: var(--color-marker); mix-blend-mode: multiply; rotate: -2deg; clip-path: polygon(0 9%, 96% 0, 100% 92%, 3% 100%); }
@media (prefers-reduced-motion: no-preference) {
  .logo-reveal, .copy { animation: hero-reveal var(--motion-reveal) var(--ease-out) both; }
  .copy { animation-delay: var(--motion-stagger); }
  .highlight::after { animation: marker-reveal var(--motion-marker) var(--ease-out) var(--motion-marker-delay) both; }
  .headline-note { animation: hero-reveal var(--motion-reveal) var(--ease-out) var(--motion-note-delay) both; }
}
@media (max-width: 767px) {
  :global(html:lang(ja)) h1 { display: flex; flex-direction: column; gap: var(--hero-mobile-phrase-gap); }
}
</style>
