<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import { site } from '$lib/site';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
</script>

<header class="site-header">
  <div class="header-links">
    <nav aria-label={text.languageLabel}>
  <a href="/" lang="en" hreflang="en" aria-current={language === 'en' ? 'page' : undefined}>{text.english}</a>
  <a href="/ja/" lang="ja" hreflang="ja" aria-current={language === 'ja' ? 'page' : undefined}>{text.japanese}</a>
</nav>
    <a class="header-github" href={site.githubUrl} target="_blank" rel="noopener" aria-label={text.githubLabel}>
      <svg width="17" height="17" viewBox="0 0 24 24">
          <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-1.96c-3.2.7-3.87-1.54-3.87-1.54-.52-1.33-1.28-1.69-1.28-1.69-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.74.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.18-3.09-.12-.29-.51-1.46.11-3.04 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.58.23 2.75.11 3.04.74.8 1.18 1.83 1.18 3.09 0 4.42-2.69 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5z" fill="currentColor" />
        </svg>
    </a>
  </div>
</header>

<style>
.site-header { display: flex; align-items: center; justify-content: flex-end; padding: var(--spacing-6) var(--page-gutter) 0; }
.header-links { display: flex; align-items: center; gap: var(--spacing-6); }
nav { display: flex; padding: var(--spacing-1); background: var(--surface-glass); box-shadow: var(--shadow-white); backdrop-filter: blur(var(--glass-blur)); border-radius: var(--radius-full); color: var(--color-ink-2); font-size: var(--text-label); white-space: nowrap; }
nav a { padding: var(--header-language-padding) var(--spacing-3); border-radius: var(--radius-full); }
nav [aria-current='page'] { background: var(--surface-white); box-shadow: var(--shadow-white); color: var(--color-ink); text-decoration: none; }
.header-github { display: flex; align-items: center; justify-content: center; width: var(--header-control-height); height: var(--header-control-height); border-radius: var(--radius-full); background: var(--surface-white); box-shadow: var(--shadow-white); }
@media (max-width: 540px) {
    .header-links { gap: var(--spacing-3); }
}
</style>
