# akapen の LP

SvelteKit 2 / Svelte 5 の静的サイト。英語 `/`、日本語 `/ja/`。ブラウザの言語で自動転送しない。クライアント JS・外部フォント・外部スクリプトは使わない。

ルートで `pnpm install` 後、以下を実行する。

- `pnpm dev:site` — 127.0.0.1:5280
- `pnpm build:site` — `apps/site/build/` に HTML を書き出す
- `pnpm -C apps/site typecheck` — 型とアクセシビリティの静的検査
- `pnpm -C apps/site preview` — ビルド結果を 127.0.0.1:5290 で配信

文言は `src/lib/i18n.ts`、色と余白は `src/app.css`。素材はルートの `brand/` から `static/` にコピーしてある。元素材を変更したらコピーも更新する。

`src/lib/site.ts` の `downloadUrl` が `null` のあいだは「Coming soon / 近日公開」の無効なボタンを出す。URL を設定するとダウンロードリンクになる。公開ドメインは未定なので `origin` も `null` にしてある。公開前に設定すると OGP 画像と hreflang を絶対 URL にできる。

支援先 `yuto343` は仮の値。決まったら `src/lib/site.ts` のユーザー名と、ルートの `.github/FUNDING.yml` を差し替える。

`wrangler.jsonc` は静的アセットのみの設定。アカウント・ドメインは指定していない。このタスクではデプロイしない。
