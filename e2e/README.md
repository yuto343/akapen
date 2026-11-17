# E2E テスト

akapen の E2E は、「抽象的な md のシナリオ」を仕様として置き、テストコード（XCUITest）はエージェント（planner / generator / healer）に生成・修復させる。細かい UI の変更では落ちず、本質的な不具合は確実に見つけることがゴール。考え方は ashvally の `e2e/` と同じで、道具が Playwright から XCUITest に替わる。

設計の正は `ARCHITECTURE.md`（「E2E の仕組み」「テストの分担」「確かめた結果」）。この README はその運用ルールを書く。食い違いに気づいたら `ARCHITECTURE.md` に合わせる。

## 原則

- **読んで直すのは `specs/` の md。** どの要素をクリックするかは書かず、前提・目的・期待される結果・してはいけないことを書く。人が書いてもエージェントが書いてもよいが、**人が読んで納得できる仕様であること**が条件。エージェントが書き足した分は、生成テストと同じ重さでレビューして取り込む。
- **生成コードは直接編集しない。** `tests/Generated/**` を直したいときは、md を直して generator で作り直す。
- **操作は AI、検証は決定的なコード。** 要素の引き方と待ち方は generator / healer に任せ、期待される結果は `tests/Support/` の検証のヘルパー（クリップボード・保存された画像・アプリの状態）で確かめる。
- **CI では AI を使わない。** CI を置くときは、生成済みのテストを `make e2e` で走らせるだけにする（いまは CI を置いていない）。
- **healer はテストを弱めない。** 要素の引き方と待ち方の修正は許可、アサーションの緩和・削除は禁止。満たせない場合は `XCTSkip` で止め、不具合として扱う。

## 構成と、ファイルごとの扱い

```
e2e/
├── README.md                 # この運用ルール
├── check-specs.mjs           # md の書式と、生成物との対応を確かめる（make e2e-lint）
├── specs/                    # 人が読む仕様（ソース・オブ・トゥルース）
│   ├── _template.md
│   ├── draw/                 # 枠を描く（Paper: App 01）
│   ├── comment/              # コメントを書いて確定する（App 02）
│   ├── list/                 # 一覧で見返す・直す・消す（App 03）
│   ├── copy-prompt/          # プロンプトをコピーする（App 04）
│   ├── menu-bar/             # メニューバーと終了確認（App 05・09）
│   ├── settings/             # 設定ページ（App 06）
│   └── setup/                # 初回のセットアップ（App 07・08）
├── tests/                    # UI テストのターゲット AkapenE2E（XCTest / XCUITest）
│   ├── Seed.swift            # 手で書く：generator / healer の起点、起動のスモークテスト
│   ├── Support/              # 手で書く：起動・前提づくり・操作・検証のヘルパー
│   ├── Generated/            # generator / healer が書く：直接編集しない
│   ├── Spike/                # 手で書く：foundation の検証。正式な生成テストに置き換えるまで make e2e に含める
│   └── Live/                 # 手で書く：実際の画面収録を通す確認（手元だけ）
└── sample-target/            # 撮影対象にする小さなアプリ「Sample App」（ターゲット SampleTarget）
```

| パス | 変更方法 |
| --- | --- |
| `e2e/specs/**/*.md` | 直接編集（人・エージェントのどちらでも）。仕様変更は必ずここから。人がレビューして取り込む |
| `e2e/tests/Seed.swift` / `Support/**` / `Live/**` | 直接編集 |
| `e2e/tests/Generated/**` | **直接編集しない。** generator / healer 経由のみ |
| `Packages/AkapenKit/Sources/AkapenAXID/**` | 直接編集。識別子の追加はアプリ側の変更と同時に行う |
| `.claude/agents/e2e-*.md` | 直接編集 |
| `e2e/tests/Spike/**`、`e2e/sample-target/**`、`e2e/check-specs.mjs` | 直接編集 |

## spec と生成物の対応

- **パスはミラーする。** `specs/<dir>/<name>.md` → `tests/Generated/<dir>/<Dir><Name>Tests.swift`。`<Dir><Name>` はケバブケースをパスカルケースにしたもの。クラス名もファイル名と同じ。
  - `specs/draw/capture.md` → `Generated/draw/DrawCaptureTests.swift`（`DrawCaptureTests`）
  - `specs/copy-prompt/copy.md` → `Generated/copy-prompt/CopyPromptCopyTests.swift`（`CopyPromptCopyTests`）
  - ファイル名にディレクトリ名を含めるのは、同じターゲットに同名の Swift ファイルを置けないため。
- md は `specs/<dir>/<name>.md` の深さに置く（それより深くしない）。ディレクトリ名とファイル名はケバブケース。
- **生成ファイルの 1 行目と 2 行目**に、対応する spec のパスと、その md の内容の SHA-256 を入れる。ハッシュは `node e2e/check-specs.mjs --hash <md のパス>` の出力。md を直したのに作り直していない状態を、lint がハッシュの不一致で落とす。
- **各テスト関数の直前**に、md の `####` のシナリオ名を 1 文字も変えずに `// scenario:` で入れる。md のシナリオと 1 対 1（足りない・余る・重なるはどれも lint が落とす）。

```swift
// spec: e2e/specs/draw/capture.md
// spec-sha256: 3f9a…
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class DrawCaptureTests: AkapenUITestCase {
    // scenario: 枠を描いて離すと、枠のあるウィンドウが赤枠入りの画像として残る
    func testFrameCapturesWindow() throws { … }
}
```

- md を消したら、対応する生成ファイルも消す（対応する md の無い生成ファイルは lint が落とす）。

## md の書式

1 ファイル 1 機能。`概要 / 前提 / 目的 / シナリオ` の順で書き、シナリオは `### 正常系` と `### 準正常系` に分け、その下に `#### <シナリオ名>` を並べる。各シナリオに `期待される結果:` と `してはいけないこと:` を箇条書きで書く。ひな形は `specs/_template.md`。

### 書き方のルール

- **`####` 1 つがテスト 1 つ。** 1 つの見出しに複数の目的を詰め込まない（落ちたときに何が壊れたか分からなくなる）。主題が違うものは別ファイルに分ける。1 ファイルあたり 2〜7 件を目安にする。
- **ボタン名・ラベルの文言・要素の位置・操作の手順を書かない。** パネルかウィンドウか、押せない状態になるのか押しても何も起きないのかは「実装の選択」であって仕様ではない。キーの組み合わせ（ホットキー、確定キー、`Esc`）は `DESIGN.md` が決めている振る舞いなので書いてよい。
- **期待される結果には、UI に依存しない検証点を最低 1 つ入れる**（下の「検証点」）。偽陽性を防ぐ核。
- **どのヘルパー・どの関数で確かめるかは書かない。** 「アプリの状態で、〜」まで書けば、検証の手段は generator が `tests/Support/` から選ぶ。
- **「してはいけないこと」に、成功したように見えて実は失敗している状態を書く。** とくに「画面では成功して見えるのに、状態・画像・クリップボードは変わっていない」を考える。
- **前提は起動時に用意できる状態として書く**（下の「前提づくり」）。シナリオごとに前提が違うときは、`## 前提` に「〜のシナリオでは〜」と書き分ける。
- **流す時刻に結果が左右される前提を置かない。** 時刻は固定される。古い回は「固定した時刻の 5 日前の回」のように、固定した時刻からの相対で書く。
- **画面の大きさ・ディスプレイの枚数・手元の設定に左右される前提を置かない。**
- **決まっていない挙動を書かない。** `DESIGN.md` に定めがないものは、`.director/design/DECISIONS.md` と `.director/core/brief.md`（状態の遷移の決まり）に合わせる。それでも決まらないものは仕様に書かず、決めてもらう。
- 流れの分岐の網羅は結合テスト（`AkapenAppTests`）で行い、E2E は代表的な流れに絞る（`ARCHITECTURE.md`「テストの分担」）。

## 検証点（UI に依存しないもの）

各シナリオの `期待される結果:` に、次の 3 つのどれかを最低 1 つ入れる。**書き出しをこの形にそろえる**（`make e2e-lint` がこの書き出しを探す）。

| 書き出し | 何を見るか | 確かめ方（generator が Support から選ぶ） |
| --- | --- | --- |
| 「クリップボードに入った文章で、〜」 | コピーしたプロンプト。定型文と「パス → コメント」の並び、パスの指す先 | テストごとの名前つきのクリップボード（`AKAPEN_PASTEBOARD`）を読み、定型文と「パス → コメント」の組に分けて比べる |
| 「保存された画像で、〜」 | 画像の置き場のファイル。有無、枚数、大きさと縦横の比、赤枠の位置 | テストごとの置き場（`AKAPEN_STATE_DIR` の下）の実ファイルを読む。赤枠は赤い画素の外接矩形を、描いた枠と許容誤差つきで比べる |
| 「アプリの状態で、〜」 | アプリが持っている状態。いまの状態、注釈の件数・順番・コメント・画像のパス、書きかけの注釈、設定値、プロセスが動いているか | テスト起動のときだけアプリが書き出す `state.json`（状態が変わるたびに書き出す）と、プロセスの状態 |

### spec の言葉とアプリの状態

spec では次の言葉を使う。generator はこの表で `state.json` の値に読み替える（`state.json` の形は `docs/FOUNDATION.md`）。

| spec の言葉 | アプリの状態 |
| --- | --- |
| 何も出ていない状態 | `phase` が `hidden` |
| 枠を描く状態 | `phase` が `drawing` |
| コメントを書いている状態 | `phase` が `commenting`（書きかけの注釈がある） |
| ボタン類だけが出ている状態 | `phase` が `idle` で、ボタン類が出ている |
| 一覧を開いている状態 | `phase` が `listOpen` |
| コピーを終えた状態 | `phase` が `copied`、またはコピー完了の表示が消えたあとの `hidden`。どちらでも、注釈は 0 件でボタン類は出ていない |
| ボタン類が出ている / 出ていない | `isToolbarVisible` |
| 注釈（件数・順番・コメント・画像のパス） | `annotations`。確定済みのものだけで、書きかけは含まない。順番は確定した順 |
| 書きかけの注釈 | コメントを書いている間の、撮影済みでコメントが未確定の注釈（`draft`） |
| 最後に描いた枠 | `lastDrawnRect` |
| 直前にコピーした件数 | `lastCopiedCount` |
| 設定の〜（言語・ホットキー・ボタン類の表示を切り替えるキー・確定キー・定型文・画像を残す日数） | `settings` の各値。定型文は言語ごと |
| セットアップ済み / セットアップは終わっていない | `settings.setupCompleted` |
| akapen のプロセスが動いている / 終了している | テストから見たアプリのプロセスの状態（終了したあとは `state.json` が書き出されないため） |
| この回のフォルダ | 画像の置き場の下の、いまの回のフォルダ（名前は固定した時刻から決まる） |
| 撮影対象のアプリ | SampleTarget（下の「撮影対象のアプリ」） |

## 前提づくり

前提までを UI 操作でやらせると、本題と無関係な箇所で落ちる。前提は起動時の環境変数で作り、検証は決定的なコードで行う。

- **前提は UI 操作で作らない。** akapen を起動するときの環境変数で決める。読むのは `AkapenApp/LaunchConfiguration.swift` の 1 か所だけで、画面やロジックの中では「テスト中かどうか」を見ない。

| 環境変数 | 効果 |
| --- | --- |
| `AKAPEN_E2E=1` | E2E 用の依存に切り替える。`state.json` の書き出しを有効にする |
| `AKAPEN_STATE_DIR=<dir>` | 設定・画像・`state.json` の置き場。テストごとに新しい一時ディレクトリ。実際の `~/Library/Caches/akapen` と UserDefaults には触らない |
| `AKAPEN_PASTEBOARD=<name>` | 名前つきのクリップボードを使う。手元のコピー内容を壊さない |
| `AKAPEN_CAPTURE=fixture \| live` | 撮影の実装。`make e2e` は `fixture`（偽物）、`make e2e-live` は `live` |
| `AKAPEN_SEED=<json>` | 起動時の状態。セットアップ済みか、設定値（言語・ホットキー・確定キー・定型文・日数など）、画面収録の許可の有無、確定済みの注釈 |
| `AKAPEN_NOW=<ISO8601>` | 時計を固定する。回のフォルダ名と、古いフォルダの掃除の判定に効く |

- **注釈が既にある状態は `AKAPEN_SEED` で入れる。** 枠を描いてコメントを確定する操作で作らない（それが本題のシナリオを除く）。
- **時刻は `AKAPEN_NOW` で固定する。** テストの中で現在時刻を読まない。古い回は、固定した時刻から逆算した名前のフォルダを、起動前に置き場へ置いておく。
- **撮影は偽物（`fixture`）。** 偽の撮影（`FixtureCapturer`）は、決まったウィンドウの位置と決まった画像を返す。spec の「撮影対象のウィンドウ」は、このウィンドウが SampleTarget のウィンドウ（`SAMPLE_FRAME`）と同じ位置・大きさであることを前提にしている。実際の画面が正しく写るかは `Live/` で見る。
- 前提の組み立ては `tests/Support/` が持つ（どんな前提を指定できるかは、Support を読む）。`AKAPEN_SEED` の JSON の形は Support と `LaunchConfiguration` が決めるもので、spec には書かない。
- テストごとに一時ディレクトリを作り、終わったら消す。失敗したときは、画面の画像と要素ツリーが結果に添付される。

### 撮影対象のアプリ（SampleTarget）

Paper の「Sample App」（`.director/design/sample-app.md`）に近い構成の小さなアプリ。E2E では、枠を描く相手と、「確定したあと下のアプリを操作できる」を確かめる相手を兼ねる。

- 構成: タイトルバー、左にサイドバー（項目 4 つ）、右にフォーム（見出し、入力欄 3 つ、区切り線、`Cancel` / `Submit`）。`Submit` を押した回数をボタンの行の左端に出す（絵にはないが E2E で使う）。`Cancel` は 3 つの入力欄を空にする。
- 識別子: `AXID.Sample.*`。`button`（`Submit`）と `count`（押した回数。値は回数の数字だけ）は `AXID.swift`、それ以外（`window`、`sidebar`、`sidebarItem(_:)`、`form`、`heading`、`firstField`、`secondField`、`thirdField`、`cancel`）は `SampleAXID.swift`。
- 位置と大きさ: 環境変数 `SAMPLE_FRAME=<x>,<y>,<幅>,<高さ>` で、ウィンドウ全体の位置と大きさを指定する（主画面の左上が原点。タイトルバーを含む）。無いときは資料どおりの `140,64,1000,660`。OS に位置を直させず、動かせないウィンドウにしてあるので、毎回同じ位置・同じ大きさで出る。
- 配置: 中身は資料の座標（タイトルバーの下の 1000×608）で固定。ウィンドウの中身がそれより小さいときは、全体を同じ比率で縮めて収める（いまの `AkapenUITestCase` は `160,180,500,320` を渡すので、約 0.44 倍で出る）。大きいときは等倍で左上に寄せる。どちらでも、同じ `SAMPLE_FRAME` なら毎回同じ配置になる。
- 枠は SampleTarget の要素を基準に描く。座標を数値で決め打ちしない。

## 仕様の対象外

`specs/` に書かないものと、それぞれをどこで見るか。

| 対象外 | どこで見るか |
| --- | --- |
| 画面収録の許可ダイアログそのもの | 見ない（OS の画面）。許可の有無による akapen 側の表示までを E2E の対象にし、有無は `AKAPEN_SEED` で作る |
| 実際の画面が正しく写るか | `tests/Live/` の手書きテスト（`make e2e-live`。手元だけ） |
| 日本語変換中の `Enter` | `ConfirmKeyPolicy` の単体テスト（`AkapenCoreTests`）と、入力欄が変換中かどうかを正しく渡すかの結合テスト（`AkapenUITests`） |
| ホバーで出る一時的な表示が写るかどうか | 見ない（`DESIGN.md` の制約） |
| ログイン時の自動起動 | 見ない（E2E では何もしない実装に差し替える） |
| 見た目が Paper と一致するか | 実装のときに画面を撮って Paper と見比べる（`AkapenUITests` の画像の書き出し） |

このほか、E2E では代表的な流れだけを見て、細かい分岐は下の層に任せる。

| 内容 | 層 |
| --- | --- |
| 状態の遷移の全組み合わせ、撮影・保存・コピーの失敗、撮影の途中の入力の順序 | 単体（`AkapenCoreTests`）、結合（`AkapenAppTests`） |
| 複数のウィンドウにかかる枠の対象の選び方、赤枠の太さと縮小 | 単体（`WindowPicker` / `FrameRenderer`） |
| 回のフォルダ名、古いフォルダの選び方の境目 | 単体（`CacheLayout`） |
| 状態に対してどのパネルが出入りするか、置き場所の計算 | 結合（`AkapenUITests`） |
| 複数のディスプレイでの出し場所 | 結合（`AkapenUITests`。ディスプレイの枚数に左右されないように偽の画面で） |

## 走らせ方

| コマンド | 内容 |
| --- | --- |
| `make e2e` | `make gen` → `xcodebuild test`。`Live/` 以外（`Seed`、`Spike/`、`Generated/`）を、偽の撮影で走らせる |
| `make e2e ONLY=<クラス名>` | 1 クラスだけ走らせる（例: `make e2e ONLY=DrawCaptureTests`）。generator / healer が使う |
| `make e2e-lint` | `node e2e/check-specs.mjs`。md の書式・検証点と、生成物との対応を確かめる |
| `make e2e-live` | `Live/` だけを、実際の画面収録で走らせる（手元だけ。画面収録の許可が要る） |

- **実行中は、この Mac のマウスとキーボードがテストに取られる。** 走らせている間は触らない。
- **`make e2e` / `make e2e-live` は排他ロックを取る。** ほかの担当（人・エージェント）が走らせている間は `Waiting for E2E lock...` のまま待たされる。待たされても異常ではない。E2E を `make` を通さずに（`xcodebuild` を直接）走らせない。ロックが効かなくなり、2 つのテストが同じマウスを取り合って両方壊れる。
- 結果: ログは `build/logs/test.log`、まとめは `build/logs/e2e-summary.json`、結果バンドルは `build/e2e.xcresult`。失敗したテストの画面の画像と要素ツリーは、結果バンドルの添付から取り出す。

```bash
xcrun xcresulttool get test-results tests --path build/e2e.xcresult                     # テストの一覧と失敗の内容
xcrun xcresulttool export attachments --path build/e2e.xcresult --output-path <dir>   # 画面の画像と要素ツリー
```

### check-specs.mjs

```bash
node e2e/check-specs.mjs                 # すべて確かめる（make e2e-lint）
node e2e/check-specs.mjs --specs-only    # 書式と検証点だけ（生成物がまだ無い段階）
node e2e/check-specs.mjs --hash <md>     # その md の SHA-256（生成ファイルの 2 行目に入れる値）
```

確かめること（問題を全部並べ、1 つでもあれば終了コード 1。最後に spec の本数とシナリオの件数を 1 行で出す）:

1. 書式: 先頭の `# `、4 つの節（順番どおり）、`### 正常系` か `### 準正常系`、`####` が 1 つ以上、各シナリオに `期待される結果:` と `してはいけないこと:`、同じファイルでシナリオ名が重ならない、置き場の深さとケバブケース
2. 各シナリオの `期待される結果:` に、UI に依存しない検証点の書き出しがある
3. 各 md に対応する生成ファイルとクラスがある
4. 生成ファイルの 1 行目の `// spec:` が md のパスと一致し、2 行目の `// spec-sha256:` が md の内容の SHA-256 と一致する
5. md の `####` のシナリオ名と、生成ファイルの `// scenario:` が 1 対 1 で一致する
6. `tests/Generated/` に、対応する md の無い生成ファイルが残っていない

`--specs-only` は 1・2 だけを見る。生成物ができるまでは、`make e2e-lint`（すべて確かめる）は全 md について「生成ファイルが無い」で落ちる。

## エージェントの使い方

定義は `.claude/agents/e2e-*.md`。Playwright の MCP のように実物を操作しながら書くことはできないので、generator と healer は「書く → 1 本だけ走らせる → 結果を読んで直す」を繰り返す。

| エージェント | 渡すもの | 返ってくるもの | 制約 |
| --- | --- | --- | --- |
| `e2e-planner` | 書きたい機能、または「抜け漏れを見て」。`DESIGN.md` と既存の specs を自分で読む | `specs/**/*.md` の下書き、または抜け漏れ・ルール違反の指摘と、決まっていない挙動の一覧 | 操作手順・文言・配置を書かない。検証点を各シナリオに最低 1 つ。決まっていない挙動は書かずに報告する |
| `e2e-generator` | md 1 本のパス | `Generated/**` の 1 ファイルと、`make e2e ONLY=<クラス名>` の結果 | `Support/` のヘルパーと `AkapenAXID` の識別子だけを使う。足りなければ、文言や位置で探さずに止まって報告する。通るまで「書く → 走らせる → 読む → 直す」を繰り返す |
| `e2e-healer` | 落ちたテストの名前と結果（失敗の内容・画面の画像・要素ツリー。無ければ `build/` から自分で取る） | 直した生成ファイル、または `XCTSkip` で止めたうえでの不具合の報告 | 直してよいのは要素の引き方と待ち方だけ。アサーションの緩和・削除は禁止 |

### 運用の流れ

**新しい機能を足したとき**

1. `DESIGN.md` に機能を書く。
2. `specs/<機能>/<名前>.md` を書く（planner に下書きさせてもよい）。人がレビューする。
3. `node e2e/check-specs.mjs --specs-only` で書式と検証点を確かめる。
4. generator に「`e2e/specs/<機能>/<名前>.md` からテストを生成して」と依頼する。generator が `make e2e ONLY=<クラス名>` で通るまで直す。
5. 差分をレビューする。見るのは「md の期待される結果と、してはいけないことが、すべてアサーションになっているか」。
6. `make e2e-lint` が通ることを確かめ、md と生成テストを同じコミットに入れる。

**テストが落ちたとき** — healer が直せるかどうかで、「UI の変化」か「機能の不具合」かを切り分ける。

1. healer に、落ちたテストの名前を渡す。
2. healer が直して通った → UI の変化への追従。差分にアサーションの変更が無いことを確かめて取り込む。
3. healer が `XCTSkip` で止めた → 機能の不具合。アプリを直し、直ったら `XCTSkip` を外す（generator で作り直してもよい）。

**仕様を変えたとき** — 生成テストではなく md を先に直し、generator で作り直して、md の差分とテストの差分を一緒にレビューする。md を直して作り直さないと、`make e2e-lint` がハッシュの不一致で落とす。

## 仕様の一覧

| spec | シナリオ |
| --- | --- |
| `draw/start.md` | 3 |
| `draw/capture.md` | 2 |
| `draw/cancel.md` | 3 |
| `comment/confirm.md` | 5 |
| `comment/cancel.md` | 2 |
| `comment/confirm-key.md` | 3 |
| `list/review.md` | 2 |
| `list/edit.md` | 2 |
| `list/delete.md` | 2 |
| `copy-prompt/copy.md` | 6 |
| `menu-bar/settings.md` | 2 |
| `menu-bar/quit.md` | 3 |
| `settings/language.md` | 2 |
| `settings/hotkey.md` | 2 |
| `settings/toolbar-shortcut.md` | 3 |
| `settings/boilerplate.md` | 2 |
| `settings/retention.md` | 3 |
| `setup/first-run.md` | 7 |

2026-11-18 時点で 18 本・54 件。生成テスト（`tests/Generated/`）と `Support/` のヘルパーはまだ無い（あとの作業で作る）。
