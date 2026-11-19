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

## デモ動画

LP のデモは `static/demo/akapen-demo-{en,ja}.mp4`（ポスター画像は同名の `.jpg`）。クライアント JS を出さないため、自動再生はせず、動画を押すとブラウザ標準の仕組みで再生が始まる。中央の赤い再生ボタンは `DemoVideo.svelte` が CSS で重ねた見た目だけのもので、クリックは動画に通す。再生中かを CSS で見分けられるブラウザ（Safari）では止めている間だけ出し、それ以外（Chrome など）では一度押したら出し直さない。

元の絵とアニメーションは `src/lib/components/Demo.svelte`、文言は `src/lib/i18n.ts` にある。直したら `pnpm -C apps/site record:demo` で撮り直す（ffmpeg と Playwright の Chromium が要る）。このコマンドは、撮影用のページ `src/demo-recording/` を routes に差し替えた開発サーバー（`AKAPEN_DEMO_RECORDING=1`、127.0.0.1:5281）を立て、アニメーションを 1 コマずつ止めて撮る。`--poster-only` を付けると、ポスターだけを撮り直す。

## 手書き風のフォント

日本語ページのフッターの手書き風の文（`supportNote`）は Kiwi Maru（SIL OFL 1.1、`static/fonts/OFL-KiwiMaru.txt`）。使う字だけを抜き出したサブセット `static/fonts/kiwi-maru-hand.woff2` を置いている。文言を変えたら `pnpm -C apps/site subset:font` で作り直す（元の TTF は google/fonts から取得し、`node_modules/.cache` に置く）。英語ページは Caveat のまま。
