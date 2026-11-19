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
    <!-- 作者。X と GitHub のアカウントを「a.k.a.」でつなぐ。 -->
    <div class="author">
      <span class="made-by">{text.madeBy}</span>
      <div class="author-links">
        <a class="author-link" href={site.xUrl} target="_blank" rel="noopener" aria-label={text.xLabel}>
          <img class="author-avatar" src="/author-x-avatar.jpg" width="36" height="36" alt="" />
          <span class="author-label">{text.authorXHandle}</span>
          <svg class="x-mark" width="14" height="14" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" fill="currentColor" />
          </svg>
        </a>
        <span class="author-alias">{text.authorAlias}</span>
        <a class="author-link" href={site.authorGithubUrl} target="_blank" rel="noopener" aria-label={text.githubLabel}>
          <img class="author-avatar framed" src="/author-avatar.jpg" width="36" height="36" alt="" />
          <span class="author-label">{text.authorName}</span>
          <svg class="github-mark" width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-1.96c-3.2.7-3.87-1.54-3.87-1.54-.52-1.33-1.28-1.69-1.28-1.69-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.18 1.76 1.18 1.03 1.76 2.69 1.25 3.35.96.1-.74.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.18-3.09-.12-.29-.51-1.46.11-3.04 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.58.23 2.75.11 3.04.74.8 1.18 1.83 1.18 3.09 0 4.42-2.69 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5z" fill="currentColor" />
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
  </footer>
<style>
.site-footer {
  align-items: center;
  background-color: transparent;
  display: flex;
  flex-direction: column;
  gap: 28px;
  padding-inline: var(--spacing-shell);
  padding-top: var(--footer-top-space);
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

.author {
  align-items: center;
  display: flex;
  flex-direction: column;
  gap: var(--author-links-space);
  padding-top: var(--spacing-1);
}

.made-by {
  color: var(--color-steel);
  font-family: var(--font-mono);
  font-size: var(--author-caption-size);
  line-height: var(--author-caption-line-height);
  letter-spacing: var(--author-caption-tracking);
  text-transform: uppercase;
}

.author-links {
  align-items: center;
  display: flex;
  gap: var(--author-alias-gap);
  justify-content: center;
}

.author-link {
  align-items: center;
  background: var(--surface-white);
  border-radius: var(--radius-full);
  box-shadow: var(--shadow-white);
  color: var(--color-ink);
  display: flex;
  flex-shrink: 0;
  gap: var(--author-pill-gap);
  height: var(--author-pill-height);
  padding: 0 var(--author-pill-padding-end) 0 var(--author-pill-padding-start);
}

.author-avatar {
  border-radius: var(--radius-full);
  flex-shrink: 0;
  height: var(--author-avatar-size);
  object-fit: cover;
  width: var(--author-avatar-size);
}

/* GitHub 側のアイコン（コーヒー豆）は白地なので、細い縁で輪郭を出す。 */
.author-avatar.framed {
  box-shadow: var(--author-avatar-ring);
}

.author-label {
  font-size: var(--author-name-size);
  font-weight: 500;
  line-height: var(--author-name-line-height);
}

.x-mark,
.github-mark {
  flex-shrink: 0;
}

.x-mark {
  height: var(--author-x-mark-size);
  width: var(--author-x-mark-size);
}

.github-mark {
  height: var(--author-github-mark-size);
  width: var(--author-github-mark-size);
}

.author-alias {
  color: var(--color-steel);
  flex-shrink: 0;
  font-family: var(--font-mono);
  font-size: var(--text-label);
  letter-spacing: var(--author-caption-tracking);
  line-height: 16px;
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

.site-footer { padding-inline: var(--page-gutter); }
@media (max-width: 767px) {
  .support-links { flex-wrap: wrap; justify-content: center; }
}
/* 横に入らない幅では、「a.k.a.」を 2 つのピルの間の行に単独で置く。 */
@media (max-width: 479px) {
  .author-links { flex-direction: column; gap: var(--author-pill-gap); }
}
</style>
