<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import { site, siteUrl } from '$lib/site';
  import Hero from './Hero.svelte';
  import SiteHeader from './SiteHeader.svelte';
  import DemoVideo from './DemoVideo.svelte';
  import DownloadSection from './DownloadSection.svelte';
  import SiteFooter from './SiteFooter.svelte';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
</script>

<svelte:head>
  <title>{text.title}</title>
  <meta name="description" content={text.description} />
  <meta property="og:title" content={text.title} />
  <meta property="og:description" content={text.description} />
  <meta property="og:image" content={siteUrl(site.ogImage)} />
  <meta property="og:type" content="website" />
  <meta property="og:locale" content={language === 'ja' ? 'ja_JP' : 'en_US'} />
  <link rel="alternate" hreflang="en" href={siteUrl('/')} />
  <link rel="alternate" hreflang="ja" href={siteUrl('/ja/')} />
  <link rel="alternate" hreflang="x-default" href={siteUrl('/')} />
</svelte:head>

<SiteHeader {language} />
<main>
  <Hero {language} />
  <DemoVideo {language} />
  <DownloadSection {language} />
</main>
<SiteFooter {language} />
