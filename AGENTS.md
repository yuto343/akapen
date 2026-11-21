# akapen — エージェント向けの決まり

画面の上に赤枠とコメントを重ねていき、最後にまとめて AI へ渡すための macOS 向けツール。Swift のネイティブアプリ。

## 先に読むもの

- `apps/mac/DESIGN.md` — 何を作るか（操作の流れ、仕様、やらないこと）
- `apps/mac/ARCHITECTURE.md` — どう組むか（ディレクトリ構成、モジュール、状態、E2E の仕組み、テストの分担）
- `apps/mac/e2e/README.md` — E2E の運用（md の仕様からテストコードを生成する）

この 3 つと食い違う実装をしない。食い違いに気づいたら、実装を合わせるか、報告に書く。

## コマンド

| コマンド | 内容 |
| --- | --- |
| `make gen` | `apps/mac/project.yml` から `akapen.xcodeproj` を生成する（XcodeGen） |
| `make build` | アプリをビルドする |
| `make run` | ビルドして起動する |
| `make test` | 単体テストと結合テスト（`swift test`） |
| `make e2e` | E2E（XCUITest。撮影は偽物） |
| `make e2e ONLY=<クラス名>` | E2E を 1 クラスだけ走らせる |
| `make e2e-live` | 実際の画面収録を通す E2E（手元だけ。画面収録の許可が要る） |
| `make e2e-lint` | `apps/mac/e2e/specs/**/*.md` の書式と、生成物との対応を確かめる |

- `xcodebuild` を直接呼ぶときは、必ず `-derivedDataPath build/DerivedData`（`apps/mac` で実行） を付ける（リポジトリの外に生成物を置かない）。
- **E2E の実行中は、この Mac のマウスとキーボードがテストに取られる。** `make e2e` は排他ロックを取るので、ほかの担当が走らせている間は待たされる。待たされても異常ではない。E2E を `make` を通さずに走らせない。

ルートの make は `apps/mac/Makefile` への転送。Mac アプリのコマンド・相対パスは `apps/mac` を基準にする（同ディレクトリで直接実行もできる）。生成物は `apps/mac/build/` と `apps/mac/akapen.xcodeproj`。

## リリースのコマンド（pnpm）

| コマンド | 内容 |
| --- | --- |
| `pnpm release:mac <x.y.z> [--skip-notarize]` | 配布の成果物（Developer ID で署名・公証した zip、`appcast.xml`、Homebrew の cask）を `apps/mac/build/release/x.y.z/` に揃える。公開はしない。公証のプロファイル（環境変数 `AKAPEN_NOTARY_PROFILE`、既定 `akapen`）がなければ止まる。`--skip-notarize` で公証を飛ばせる（手元の確認用）。手順は `apps/mac/docs/RELEASE.md` |
| `pnpm publish:mac <x.y.z>` | GitHub Release と Homebrew の tap に公開する。**ユーザーだけが走らせる。エージェントは走らせない** |

## site のコマンドと決まり

- `pnpm install` — ルートで依存を入れる（pnpm 10）。
- `pnpm dev:site` — LP の開発サーバー（127.0.0.1:5280）。
- `pnpm build:site` — Cloudflare Workers 向けに `apps/site/.svelte-kit/cloudflare/` へ書き出す（`@sveltejs/adapter-cloudflare`。ページは prerender した HTML）。
- `pnpm -C apps/site typecheck` — Svelte と TypeScript の型検査。
- 文言は `apps/site/src/lib/i18n.ts`、色・余白は `apps/site/src/app.css` の CSS 変数に置く。
- 外部の script や外部フォントを読まない。クライアント JS は出さない（`csr = false`）。例外は、Download 節のコピーのボタンを動かす自前の小さなスクリプト `apps/site/static/install-copy.js` だけ（ハイドレーションはしない）。
- `pnpm deploy:site` — ビルドして Cloudflare Workers（`akapen-site`、`https://akapen.yuto343.net`）にデプロイする。**ユーザーに頼まれたときだけ走らせる。**

## コードの決まり（Mac アプリ）

- Swift 6 の言語モード。警告を残さない。外部ライブラリは入れない。例外は Sparkle（アプリ内の更新。ユーザーが導入を頼んだ）だけで、依存は `AkapenPlatform` にだけ付け、`import Sparkle` は `AkapenPlatform/Update/` の中だけに置く。ほかのライブラリは引き続き入れない。
- モジュールの依存は一方向（`apps/mac/ARCHITECTURE.md` の図）。`AkapenCore` はほかのモジュールに依存しない。
- **OS に触るコードは `AkapenPlatform` にだけ置く。** 画面の撮影、クリップボード、ホットキー、ファイルの置き場、UserDefaults、時計、ログイン時の起動、更新の確認（Sparkle）。使う側は `AkapenCore/Ports` のプロトコル越しに呼ぶ。
- **「テスト中かどうか」を見るのは `AkapenApp` の `LaunchConfiguration` と `AppEnvironment` だけ。** 画面やロジックの中で環境変数や起動引数を読まない。
- **状態の遷移は `SessionModel` にだけ書く。** ウィンドウや画面は `phase` を映すだけで、次にどの状態へ行くかを判断しない。
- **操作できる UI の要素には、必ず `AkapenAXID` の識別子を付ける。** 識別子の文字列をアプリ側やテスト側に直接書かない。
- 座標は、`AkapenCore` の中ではすべて「画面全体を通した、左上が原点の座標」（Quartz / ScreenCaptureKit と同じ向き）で持つ。AppKit の左下原点との変換は `AkapenUI/Windows` と `AkapenPlatform` の端でだけ行う。
- 表示の文言は画面のコードに直接書かず、`AkapenUI/Strings/` の文言の表（`EnglishStrings` / `JapaneseStrings`）に置き、`UIStrings` で引く。言語はシステムではなく `Settings.language` で選ぶ。単数・複数は `PluralKey` で出し分ける。既定は英語。
- 1 行に 1 つの文。`;` で文をつながない。宣言・`case`・プロパティを 1 行に詰め込まない。型と型、メソッドとメソッドの間は 1 行空ける。
- 識別子（型名・関数名・ファイル名）は英語。コメントとドキュメントは日本語。公開の型と関数にはドキュメントコメントを書く。
- 色・文字サイズ・角丸・余白は `AkapenUI/Tokens.swift` の値を使う。画面の中に数値や色を直接書かない。

## テストの決まり

- パッケージのテスト（`apps/mac/Packages/AkapenKit/Tests`）は Swift Testing で書く。XCTest を使うのは `e2e/tests` だけ。
- どの層に書くかは `apps/mac/ARCHITECTURE.md` の「テストの分担」に従う。流れの分岐の網羅は結合テストで行い、E2E は代表的な流れに絞る。
- テストは、流した時刻・画面の大きさ・ディスプレイの枚数・手元の設定に結果が左右されないように書く。実際のクリップボード、実際の `~/Library/Caches/akapen`、実際の UserDefaults に触らない。
- **`apps/mac/e2e/tests/Generated/**` は直接編集しない。** `apps/mac/e2e/specs` の md を直して、generator / healer（`.claude/agents/e2e-*.md`）経由で作り直す。
- テストを通すためにアサーションを弱めない・消さない。満たせないなら、不具合として報告する。

## ディレクターから依頼されたとき

`.director/<slug>/brief.md` を読んで実装する、という形で依頼が来る。

- ブリーフの「触ってよい場所」の外のファイルを変えない。外を変えないと進めない場合は、変えずに報告する（公開している型や関数を少し足すだけ、のような最小限の変更は、理由を報告に書けばしてよい）。
- **ほかの担当が同じ作業ツリーで同時に作業していることがある。** 自分の範囲の外のファイルでコンパイルエラーが出たら、直さずに 1〜2 分待ってやり直す。5 分続いたら、その旨を報告して止まる。自分が書いていないファイルを消さない・戻さない。
- git のコミット・push・ブランチの切り替え・`git stash`・`git checkout -- <file>`・`git clean` をしない。デプロイや公開もしない。
- `.director/` の中は読むだけにする（ブリーフが書くように求めているファイルを除く）。
- 受け入れ条件は、コマンドを実際に流して確かめる。流していないものを「通った」と書かない。

終わったら、次の形で報告する。

```markdown
## 結果
完了 / 一部未完 / 中断（どれか）

## 変えたファイル
- `path` — 何をしたか

## 受け入れ条件ごとの結果
- [x] <条件> — どう確かめたか
- [ ] <条件> — できなかった理由

## 流したコマンドと結果
- `make test` — 通った（テスト n 件）

## ブリーフから外れた点・自分で決めたこと
- ...

## 残した課題・気づいたこと
- ...
```
