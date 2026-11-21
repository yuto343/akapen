# akapen の LP

SvelteKit 2 / Svelte 5 のサイト。Cloudflare Workers（`@sveltejs/adapter-cloudflare`）で `https://akapen.yuto343.net` に出す。ページはすべて prerender した HTML。英語 `/`、日本語 `/ja/`。ブラウザの言語で自動転送しない。外部フォント・外部スクリプトは使わない。クライアント JS も出さない（`csr = false`、ハイドレーションなし）。例外は、Download 節のコマンドのコピーのボタンを動かす自前の小さなスクリプト `static/install-copy.js` だけで、JS が無い・クリップボードの API が使えないときはボタンを出さず、コマンドを選択してコピーできる表示だけにする。

ルートで `pnpm install` 後、以下を実行する。

- `pnpm dev:site` — 127.0.0.1:5280
- `pnpm build:site` — `apps/site/.svelte-kit/cloudflare/` に Worker と HTML を書き出す
- `pnpm deploy:site` — ビルドして Cloudflare Workers にデプロイする（`wrangler deploy`。wrangler にログインしておく）
- `pnpm -C apps/site typecheck` — 型とアクセシビリティの静的検査
- `pnpm -C apps/site preview` — ビルド結果を 127.0.0.1:5290 で配信

文言は `src/lib/i18n.ts`、色と余白は `src/app.css`。素材はルートの `brand/` から `static/` にコピーしてある。元素材を変更したらコピーも更新する。

ヒーローの下のデモ動画とフッターの間に「Download」節（`#download`、ヘッダーのリンクの行き先）がある。ダウンロードのボタンと、Homebrew のコマンド（`site.ts` の `brewInstallCommand`）をコピーできるターミナル風の枠を並べる。`src/lib/site.ts` の `downloadUrl` が `null` のあいだは「Coming soon」の無効なボタンを出す。URL を設定するとダウンロードリンクになる。`origin` は公開ドメイン（`https://akapen.yuto343.net`）で、OGP 画像と hreflang を絶対 URL にするのに使う。

支援先（GitHub Sponsors と Ko-fi）のユーザー名は `yuto343`。`src/lib/site.ts` の `supportUsername` と、ルートの `.github/FUNDING.yml` に書いてある。変えるときは両方を合わせる。

`wrangler.jsonc` は、SvelteKit が書き出す Worker（`.svelte-kit/cloudflare/_worker.js`）と、カスタムドメイン `akapen.yuto343.net` の設定。`workers.dev` の URL では出さない。

## デモ動画

LP のデモは `static/demo/akapen-demo-{en,ja}.mp4`（ポスター画像は同名の `.jpg`）。クライアント JS を出さないため、自動再生はせず、動画を押すとブラウザ標準の仕組みで再生が始まる。中央の赤い再生ボタンは `DemoVideo.svelte` が CSS で重ねた見た目だけのもので、クリックは動画に通す。再生中かを CSS で見分けられるブラウザ（Safari）では止めている間だけ出し、それ以外（Chrome など）では一度押したら出し直さない。

元の絵とアニメーションは `src/lib/components/Demo.svelte`、文言は `src/lib/i18n.ts` にある。直したら `pnpm -C apps/site record:demo` で撮り直す（ffmpeg と Playwright の Chromium が要る）。このコマンドは、撮影用のページ `src/demo-recording/` を routes に差し替えた開発サーバー（`AKAPEN_DEMO_RECORDING=1`、127.0.0.1:5281）を立て、アニメーションを 1 コマずつ止めて撮る。`--poster-only` を付けると、ポスターだけを撮り直す。
