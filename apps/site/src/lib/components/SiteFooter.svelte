<script lang="ts">
  import { messages, type Language } from '$lib/i18n';
  import { site } from '$lib/site';
  let { language }: { language: Language } = $props();
  const text = $derived(messages[language]);
</script>

<footer class="site-footer">
    <!-- Support -->
    <div class="support-links">
      <a class="sponsors-link" href={site.githubSponsorsUrl} target="_blank" rel="noopener">
        <svg width="18" height="18" viewBox="0 0 24 24">
          <path d="M12 20.5s-7.5-4.6-9.3-9.2C1.4 8 3.4 4.5 7 4.5c2.1 0 3.6 1.2 5 3 1.4-1.8 2.9-3 5-3 3.6 0 5.6 3.5 4.3 6.8-1.8 4.6-9.3 9.2-9.3 9.2z" fill="none" stroke="#DB61A2" stroke-width="2" stroke-linejoin="round" />
        </svg>
        <div class="sponsors-label">{text.sponsors}</div>
      </a>
      <a class="kofi-link" href={site.kofiUrl} target="_blank" rel="noopener">
        <svg width="20" height="18" viewBox="0 0 26 22">
          <path d="M3 4h15v8.5a6 6 0 0 1-6 6H9a6 6 0 0 1-6-6z" fill="none" stroke="#121214" stroke-width="2" stroke-linejoin="round" />
          <path d="M18 6.5h2.2a3.3 3.3 0 0 1 0 6.6H18" fill="none" stroke="#121214" stroke-width="2" />
          <path d="M10.5 13.2s-3-1.8-3-3.7c0-1 .8-1.8 1.7-1.8.6 0 1 .3 1.3.8.3-.5.7-.8 1.3-.8.9 0 1.7.8 1.7 1.8 0 1.9-3 3.7-3 3.7z" fill="#FF3E3E" />
        </svg>
        <div class="kofi-label">{text.kofi}</div>
      </a>
    </div>
    <!-- 作者と作者の SNS -->
    <div class="author-row">
      <img class="author-avatar" src="/author-avatar.jpg" width="40" height="40" alt="" />
      <div class="author-name">
        <span class="made-by">{text.madeBy}</span>
        <span class="author-label">{text.authorName}</span>
      </div>
      <div class="social-links">
        <a class="x-link" href={site.xUrl} target="_blank" rel="noopener" aria-label={text.xLabel}>
          <svg width="15" height="15" viewBox="0 0 24 24">
            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" fill="#121214" />
          </svg>
        </a>
        <a class="github-link" href={site.authorGithubUrl} target="_blank" rel="noopener" aria-label={text.githubLabel}>
          <svg width="17" height="17" viewBox="0 0 24 24">
            <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-1.96c-3.2.7-3.87-1.54-3.87-1.54-.52-1.33-1.28-1.69-1.28-1.69-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.74.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.18-3.09-.12-.29-.51-1.46.11-3.04 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.58.23 2.75.11 3.04.74.8 1.18 1.83 1.18 3.09 0 4.42-2.69 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5z" fill="#121214" />
          </svg>
        </a>
      </div>
    </div>
    <!-- 区切り線と著作権 -->
    <div class="copyright-section">
      <div class="copyright-row">
        <div class="copyright-label">{text.copyright}</div>

      </div>
    </div>
    <!-- Handwritten note（支援ボタンの左上に、矢印でボタンを指す） -->
    <div class="support-note">
      <div class="note-text">
        {#each text.supportNote.split('\n') as line}
          <span class="note-line">{line}</span>
        {/each}
      </div>
      <svg width="90" height="52" viewBox="0 0 90 52" class="note-arrow">
        <path class="arrow-curve" pathLength="1" d="M6 6c10 26 34 38 70 36" fill="none" stroke="var(--color-accent)" stroke-width="2.4" stroke-linecap="round" />
        <path class="arrow-head" pathLength="1" d="M66 32l11 10-12 8" fill="none" stroke="var(--color-accent)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </div>
  </footer>
<style>
.site-footer {
  align-items: center;
  background-color: transparent;
  display: flex;
  flex-direction: column;
  gap: 28px;
  overflow: clip;
  padding-inline: var(--spacing-shell);
  padding-top: 120px;
  position: relative;
}

.support-links {
  align-items: center;
  display: flex;
  gap: var(--spacing-3);
}

.sponsors-link {
  align-items: center;
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-full);
  background: var(--surface-white);
  box-shadow: var(--shadow-white);
  display: flex;
  gap: 10px;
  height: 52px;
  padding-inline: 22px;
}

.sponsors-label {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: 15px;
  font-weight: 500;
  line-height: 18px;
}

.kofi-link {
  align-items: center;
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-full);
  background: var(--surface-white);
  box-shadow: var(--shadow-white);
  display: flex;
  gap: 10px;
  height: 52px;
  padding-inline: 22px;
}

.kofi-label {
  color: var(--color-ink);
  font-family: var(--font-sans);
  font-size: 15px;
  font-weight: 500;
  line-height: 18px;
}

.author-row {
  align-items: center;
  display: flex;
  justify-content: center;
  gap: var(--spacing-3);
  padding-top: 0;
}

.author-avatar {
  border-radius: var(--radius-full);
  box-shadow: var(--shadow-white);
  border: var(--avatar-border) solid var(--color-clean-bg);
  width: var(--avatar-size);
  height: var(--avatar-size);

}

.author-name {
  display: flex;
  flex-direction: column;
  gap: var(--author-name-gap);
}

.made-by {
  color: var(--color-steel);
  font-family: var(--font-mono);
  font-size: var(--author-caption-size);
  line-height: var(--author-caption-line-height);
  letter-spacing: var(--author-caption-tracking);
  text-transform: uppercase;
}

.author-label {
  color: var(--color-ink);
  font-size: var(--author-name-size);
  font-weight: 500;
  line-height: var(--author-name-line-height);
}

.social-links {
  align-items: center;
  display: flex;
  gap: var(--spacing-2);
  margin-left: var(--spacing-2);
}

.x-link {
  align-items: center;
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-full);
  background: var(--surface-white);
  box-shadow: var(--shadow-white);
  display: flex;
  height: 40px;
  justify-content: center;
  width: 40px;
}

.github-link {
  align-items: center;
  background-color: var(--color-clean-bg);
  border-radius: var(--radius-full);
  background: var(--surface-white);
  box-shadow: var(--shadow-white);
  display: flex;
  height: 40px;
  justify-content: center;
  width: 40px;
}

.copyright-section {
  align-items: center;
  align-self: stretch;
  display: flex;
  flex-direction: column;
  gap: 112px;
  padding-top: var(--spacing-6);
}

.copyright-row {
  align-items: center;
  align-self: stretch;
  border-top: 1px solid var(--color-line);
  display: flex;
  height: 64px;
  justify-content: space-between;
}

.copyright-label {
  color: var(--color-steel);
  font-family: var(--font-mono);
  font-size: var(--text-label);
  line-height: 16px;
}

.support-note {
  height: 110px;
  left: calc(50% - 395px);
  position: absolute;
  top: 38px;
  width: 240px;
}

.note-text {
  color: var(--color-accent);
  font-family: var(--font-hand);
  font-size: 28px;
  font-weight: 600;
  left: 0px;
  line-height: 30px;
  position: absolute;
  rotate: -6deg;
  top: 0px;
  transform-origin: 0% 0%;
  white-space: pre;
}

.note-line {
  display: block;
  width: fit-content;
}

/* 同じタイムラインで、2 行の文字から矢印へ順に書く。 */
@supports (animation-timeline: view()) {
  @media (prefers-reduced-motion: no-preference) {
    .site-footer {
      view-timeline-name: --support-writing;
      view-timeline-axis: block;
    }

    .note-line,
    .note-arrow path {
      animation: write-first-line 1s linear both;
      animation-timeline: --support-writing;
      animation-range: entry 10% entry 100%;
    }

    .note-line:nth-child(2) { animation-name: write-second-line; }
    .note-arrow .arrow-curve { animation-name: draw-curve; stroke-dasharray: 1; }
    .note-arrow .arrow-head { animation-name: draw-head; stroke-dasharray: 1; }

    @keyframes write-first-line {
      0% { clip-path: inset(0 100% 0 0); }
      35%, 100% { clip-path: inset(0 0 0 0); }
    }

    @keyframes write-second-line {
      0%, 35% { clip-path: inset(0 100% 0 0); }
      70%, 100% { clip-path: inset(0 0 0 0); }
    }

    @keyframes draw-curve {
      0%, 70% { stroke-dashoffset: 1; }
      90%, 100% { stroke-dashoffset: 0; }
    }

    @keyframes draw-head {
      0%, 90% { stroke-dashoffset: 1; }
      100% { stroke-dashoffset: 0; }
    }
  }
}

.note-arrow {
  left: 150px;
  top: 58px;
  position: absolute;
}
.site-footer { padding-inline: var(--page-gutter); }
.support-note { left: calc(50% - 395px); }
.note-text { white-space: pre; }
:global(html:lang(ja)) .note-text { font-weight: 400; font-size: var(--note-ja-size); }
:global(html:lang(ja)) .support-note { left: calc(50% - var(--note-ja-offset)); }
:global(html:lang(ja)) .note-arrow { left: var(--note-ja-arrow-offset); }
@media (max-width: 767px) {
  .site-footer { padding-top: var(--spacing-10); }
  .support-note { position: relative; left: auto; top: auto; width: 100%; height: auto; order: -1; }
  .note-text { position: static; text-align: center; rotate: -6deg; font-size: 28px; white-space: pre; transform-origin: center; }
  :global(html:lang(ja)) .note-text { font-size: var(--note-mobile-ja-size); }
  :global(html:lang(ja)) .support-note { left: auto; }
  .note-line { margin-inline: auto; }
  .support-note svg { display: none; }
  .support-links { flex-wrap: wrap; justify-content: center; }
}
</style>
