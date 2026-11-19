import type { Handle } from '@sveltejs/kit';

// 静的 HTML の生成時に言語を埋め込み、クライアント JS を使わない。
export const handle: Handle = ({ event, resolve }) => {
  const language = event.url.pathname === '/ja' || event.url.pathname.startsWith('/ja/') ? 'ja' : 'en';
  return resolve(event, {
    transformPageChunk: ({ html }) => html.replace('%lang%', language)
  });
};
