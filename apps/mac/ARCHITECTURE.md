# akapen アーキテクチャ

以下の Mac アプリ内のパスとコマンドは `apps/mac/` を基準にする。ルートからも make ラッパーで実行できる。共通のエージェント定義はリポジトリルートの `.claude/agents/`、ブリーフは `.director/` にある。

`DESIGN.md`（何を作るか）に対して、どう組むかを決める文書。E2E を「md の仕様からテストコードを生成する」運用（ashvally の `e2e/` と同じ考え方）で回す前提で、ディレクトリ構成・モジュール分割・テスト用の切り口を定める。

2026-11-18 時点。部品（Core・Platform・UI）と組み立て（App）を実装済み。末尾の「確かめた結果」と `docs/FOUNDATION.md` に実機検証と公開 API・`state.json`・`AKAPEN_SEED` の形を記録する。

## 方針

- **アプリ本体は薄くし、中身はローカルの Swift パッケージに置く。** ロジックは `swift test` で Xcode を通さず速く回す。
- **OS に触る部分はすべてプロトコルの裏に置く。** 画面の撮影・クリップボード・ホットキー・ファイル置き場を差し替えられるようにし、E2E では決定的な実装に入れ替える。
- **状態の遷移は 1 か所に集める。** 「ボタン類が出ているか」「枠を描いているか」などを 1 つの状態機械で持ち、ウィンドウはその状態を映すだけにする。
- **E2E の仕様は md、テストコードは生成物。** 生成コードは直接編集しない。検証は決定的なコード（クリップボード・保存された画像・状態の書き出し）で行う。
- **UI の要素は識別子で指す。** アプリとテストが同じ識別子の一覧を共有し、文言・言語・配置が変わってもテストが落ちないようにする。

## ディレクトリ構成

```
akapen/
├── apps/
│   ├── site/                       # SvelteKit の静的 LP（英語・日本語）
│   └── mac/
│       ├── DESIGN.md
│       ├── ARCHITECTURE.md
│       ├── project.yml                     # XcodeGen の定義（.xcodeproj は生成物。コミットしない）
│       ├── Makefile                        # gen / build / run / test / e2e / e2e-live / e2e-lint / clean
│       ├── scripts/                        # e2e.py（E2E の実行と排他ロック）、xcode.sh（xcodebuild の呼び出し）
│       ├── docs/FOUNDATION.md              # 公開 API、state.json v3、AKAPEN_SEED の形
│       ├── App/                            # アプリのターゲット（エントリだけ。ロジックを置かない）
│       │   ├── main.swift                  # AkapenApp の AppDelegate を起こすだけ
│       │   └── Assets.xcassets             # AppIcon（メニューバーのアイコンは AkapenUI/Resources）
│       ├── Packages/AkapenKit/             # ローカルの Swift パッケージ
│       │   ├── Package.swift
│       │   ├── Sources/
│       │   │   ├── AkapenCore/             # 純粋なロジック。AppKit の UI に依存しない
│       │   │   ├── AkapenPlatform/         # OS に触る実装（プロトコルは Core 側）
│       │   │   ├── AkapenUI/               # SwiftUI の画面と AppKit のパネル
│       │   │   ├── AkapenApp/              # 組み立て（依存の注入）、起動時の設定の読み取り、AppDelegate
│       │   │   └── AkapenAXID/             # アクセシビリティ識別子の一覧（アプリと E2E が共有）
│       │   └── Tests/                      # すべて Swift Testing。swift test で走る
│       │       ├── AkapenCoreTests/        # 単体：ロジックと状態の遷移（依存は偽物）
│       │       ├── AkapenPlatformTests/    # 結合：OS に触る実装を 1 つずつ、実物の相手に当てる
│       │       ├── AkapenUITests/          # 結合：パネルの出し入れ、入力欄の確定キー、設定・セットアップ・終了確認・メニューの操作
│       │       └── AkapenAppTests/         # 結合：本物の組み立てで一連の流れを通す（画面は操作しない）
│       ├── e2e/
│       │   ├── README.md                   # 運用ルール（ファイルごとの扱い、md の書式、healer の制約）
│       │   ├── check-specs.mjs             # md の書式と、生成物との対応を確かめる（make e2e-lint）
│       │   ├── specs/                      # 人が読む仕様（ソース・オブ・トゥルース）
│       │   │   ├── _template.md
│       │   │   ├── draw/                   # 枠を描く（Paper: App 01）
│       │   │   ├── comment/                # コメントを書いて確定する（App 02）
│       │   │   ├── list/                   # 一覧で見返す・直す・消す（App 03）
│       │   │   ├── copy-prompt/            # プロンプトをコピーする（App 04）
│       │   │   ├── menu-bar/               # メニューバーと終了確認（App 05・09）
│       │   │   ├── settings/               # 設定ページ（App 06）
│       │   │   ├── setup/                  # 初回のセットアップ（App 07・08）
│       │   │   └── toolbar/                # ボタン類が出ているあいだのショートカット（⌘C / ⌘L）
│       │   ├── tests/                      # UI テストのターゲット（XCTest / XCUITest）
│       │   │   ├── Seed.swift              # 手で書く：generator / healer の起点
│       │   │   ├── Support/                # 手で書く：起動・前提づくり・検証のヘルパー
│       │   │   │   ├── AkapenUITestCase.swift
│       │   │   │   ├── Launch.swift
│       │   │   │   ├── Gestures.swift
│       │   │   │   └── Verify.swift
│       │   │   ├── Generated/              # generator / healer が書く：直接編集しない（spec 1 本につき 1 ファイル）
│       │   │   │   └── <機能>/<Dir><Name>Tests.swift   # 例: draw/DrawCaptureTests.swift
│       │   │   └── Live/                   # 手で書く：実際の画面収録を通す確認（手元だけ）
│       │   │       └── LiveCaptureTests.swift
│       │   └── sample-target/              # 撮影対象にする小さなアプリ「Sample App」のターゲット
│       │       └── main.swift、SampleDelegate / SampleLayout / SampleViews.swift、Localizable.xcstrings
├── brand/                          # 元素材（ロゴ・アイコン・LP 用の動画）
├── Makefile                        # apps/mac への転送
└── .claude/agents/
    ├── e2e-planner.md
    ├── e2e-generator.md
    └── e2e-healer.md
```

### プロジェクトの定義

- `.xcodeproj` は XcodeGen（`project.yml`）から生成し、コミットしない。ターゲットはディレクトリ単位でソースを拾うので、`Generated/` にファイルが増えても `make gen` を挟めばそのまま入る。`make e2e` は毎回 `make gen` を先に走らせる。
- ターゲットは 3 つ。`akapen`（アプリ）、`SampleTarget`（撮影対象のアプリ）、`AkapenE2E`（UI テスト。`AkapenAXID` をリンクする）。
- 単体テストは Xcode のターゲットにせず、パッケージの `swift test` で回す。
- 署名は Apple Development 証明書で固定する（手元に有効な証明書が 2 つある）。アドホック署名だとビルドのたびに画面収録の許可が外れるため。
- バンドル ID は仮に `com.yuto343.akapen`。
- 対応 OS は仮に macOS 15 以降。

## モジュール

依存は上から下への一方向。`AkapenCore` は他のどれにも依存しない。

```
App ──▶ AkapenApp ──▶ AkapenUI ──▶ AkapenCore
            │            └──────▶ AkapenAXID
            └───▶ AkapenPlatform ──▶ AkapenCore
e2e/tests ──▶ AkapenAXID（だけ）
```

### AkapenApp

組み立てをアプリのターゲットではなくパッケージに置く。アプリのターゲットにあるコードは `swift test` から呼べず、結合テストが E2E でしか書けなくなるため。

| ファイル | 役割 |
| --- | --- |
| `LaunchConfiguration.swift` | 起動引数・環境変数を読んで値にする。純粋な関数（`[String: String]` → 設定値）。E2E で足りない・読めない値を `problems` に集める |
| `LaunchSeed.swift` | `AKAPEN_SEED`（E2E の起動時の前提の JSON）を読む。純粋な関数 |
| `AppEnvironment.swift` | `LaunchConfiguration` から使う実装を選び（`choose`。OS に触らない）、依存一式（`SessionModel` と各プロトコルの実装、ホットキー）を組み立てる（`make`）。起動時の処理（seed の設定、古い回の掃除、seed の注釈）もここ。`state.json` を書き出す |
| `HotkeyCoordinator.swift` | グローバルなホットキー（ボタン類の表示のトグル）の登録を設定に合わせ続ける。記録欄が記録を待つ間は外す。記録欄に渡す「使えるか」の判定。ボタン類が出ているあいだの `⌘C` / `⌘L` / `⌘⌫` はグローバルには登録しない |
| `AppController.swift` | 画面（メニューバー・メインメニュー・浮く部品・設定・セットアップ・終了の確認）を依存一式につなぐ。状態の遷移は判断しない |
| `QuitPolicy.swift` | 終了の確認を出すか（確定済みの注釈か書きかけの注釈があるか）と、確認に出す件数 |
| `PermissionCheckedCapturer.swift` | 許可がなければ撮影を断る包み。E2E の偽の撮影を、本物と同じく許可に従わせる |
| `SessionSnapshot.swift` | `state.json`（v3）の中身 |
| `AppDelegate.swift` | `AppEnvironment` と `AppController` を作る。終了の要求（メニュー・`⌘Q`・システム）を `applicationShouldTerminate` で受ける |

`AppEnvironment.make(_:)` は、アプリの起動・E2E・結合テストのどれからも同じものを呼ぶ。結合テストが通した組み立てが、そのまま実物のアプリの組み立てになる。

起動の順: 環境変数を読む → 実装を選ぶ → `SessionModel` を作る → seed の設定 → 古い回の掃除 → seed の注釈と `open` → 画面をつなぐ → ホットキーを登録 → いまの状態を映す（セットアップが未完了ならセットアップを出す）→ `state.json` の書き出しを始める。組み立てに失敗したら、E2E では `AKAPEN_STATE_DIR/startup-error.txt` に理由を書いて終了する。

アプリとしての振る舞い（`AppController`）:

- 終了の要求は、確定済みの注釈か書きかけの注釈があれば終了の確認を出し（件数は確定済み + 書きかけ 1）、なければそのまま終了する（`DECISIONS.md` A4）。メニュー・`⌘Q`（メインメニュー）・システムの終了の要求のどれも `applicationShouldTerminate` を通る。
- 設定とセットアップのキーの記録欄が記録を待つ間は、ホットキーの登録を外す。設定が変わるたびに、変わった役だけ登録し直す。
- 画面収録の許可がないために撮影できなかったら、セットアップの 2 ページ目を開き、浮く部品を下げる入力（`dismissRequested`）を送る（画面全体を覆う面がセットアップのウィンドウを覆わないように）。
- メニューバー・`⌘,` から設定を開くときも、先に `dismissRequested` を送る。ボタン類が出ているあいだは面が画面全体を覆うので、そのままでは設定のウィンドウを操作できない。
- 起動時に `BackgroundCursor.enable()`（`AkapenPlatform`）を呼び、アクティブでないままカーソルを変えられるようにする（下の「確かめた結果」12）。
- 終了の確認を取りやめたら、キー入力を、いまの状態で受け取るべきパネル（覆う面・コメント欄・一覧）に戻す（`SessionWindows.restoreFocus()`）。
- セットアップを終えたら、ログイン時の起動を有効にする（失敗しても続ける。E2E では何もしない実装）。
- 状態が変わるたびに、浮く部品・開いている設定とセットアップ・メインメニューの文言を映し直す（言語の切り替えがすぐに効く）。メニューバーのメニューは開くたびに読み直す。
- 終了する直前に、ホットキーの登録を外す。

### AkapenCore

| ファイル | 役割 |
| --- | --- |
| `Session/SessionModel.swift` | 状態機械（下の「状態」）。`@MainActor @Observable` |
| `Session/Annotation.swift` | 注釈 1 件（画像のパス、コメント、枠の位置） |
| `Session/DraftAnnotation.swift` | 書きかけの注釈（枠を描き終えた時点で作る。画像のパス・アプリ名・撮った範囲は撮影と保存が終わってから入る） |
| `Capture/CaptureRegion.swift` | 描いた枠から撮る範囲を決める純粋な関数。枠内に見えている（手前のウィンドウに隠れていない部分の面積が枠の 5% 以上の）ウィンドウをまとめて囲む矩形、なければ枠の上下左右に 200pt 足した矩形を、枠を描いたディスプレイの中に切り詰める。一覧に出すアプリ名もここで決める |
| `Capture/FrameRenderer.swift` | 撮った範囲の画像に赤枠を描き込み、長辺の上限に合わせて縮小する（CoreGraphics）。撮った `CGImage` をそのまま受け取る入口と、PNG を受け取る入口がある |
| `Prompt/PromptBuilder.swift` | 定型文 +「パス → コメント」の文章を組み立てる |
| `Prompt/Boilerplate.swift` | 言語ごとの定型文の既定値 |
| `Settings/Settings.swift` | 設定の型（言語・ホットキー・確定キー・定型文・保存日数）。古い版が保存した `toolbarShortcut` のような知らないキーは無視して読む |
| `Storage/CacheLayout.swift` | 回ごとのフォルダ名とファイル名の決め方、古いフォルダの選び出し |
| `Input/ConfirmKeyPolicy.swift` | 押されたキー・修飾キー・変換中かどうかから「確定 / 改行 / 何もしない」を決める |
| `Ports/*.swift` | OS に触る部分のプロトコル（下の表） |

プロトコル（Ports）と実装の対応:

| プロトコル | 本番（AkapenPlatform） | E2E 用（AkapenPlatform） |
| --- | --- | --- |
| `WindowCapturing`（ウィンドウ一覧と、範囲の撮影） | `ScreenCaptureKitCapturer` | `FixtureCapturer`（固定のウィンドウ位置と、範囲の大きさ × 倍率の固定の画像を返す） |
| `PromptPasteboard` | `NSPasteboard.general` | 名前つきのクリップボード（手元のコピー内容を壊さない） |
| `SettingsStore` | `UserDefaults.standard` | テストごとの一時ディレクトリ |
| `ImageStore`（画像の保存と掃除） | `~/Library/Caches/akapen/` | テストごとの一時ディレクトリ |
| `HotkeyRegistering` | Carbon の `RegisterEventHotKey` | 同じ実装 + テスト用の入口（下の「テスト用の切り口」） |
| `ScreenRecordingPermission` | `CGPreflightScreenCaptureAccess` | 固定値（許可あり / なし）を返す |
| `LoginItem` | `SMAppService` | 何もしない |
| `Clock` | システムの時計 | 固定の時刻 |

外部ライブラリは入れない。ホットキーの登録は Carbon の薄い包みで足り、記録用の入力欄は Paper のデザインに合わせて自前で作る。

プロトコルの裏に置かないもの: `BackgroundCursor`（`AkapenPlatform`）。アクティブでないアプリのカーソルの変更を効かせるため、起動時に 1 回だけ、ウィンドウサーバーへの接続に `SetsCursorInBackground` を立てる（公開されていない関数を名前で探して呼び、見つからなければ何もしない）。`AppController.start()` が呼ぶ。

### AkapenUI

Paper の画面と 1 対 1 で対応させる。色・文字サイズ・角丸・余白は Paper の値を `Tokens.swift` に写し、画面のコードには数値や色を直接書かない。

| ディレクトリ・ファイル | 中身 | Paper |
| --- | --- | --- |
| `Toolbar/` | 画面端のボタン類（「すべて消す」「一覧」「copy prompt」。それぞれに `⌘` `L` / `⌘` `C` をキーのチップで添え、ツールチップでも示す。件数のバッジは「一覧」の右上の角に重ねる）。`ToolbarView` | App 01〜03 |
| `Draw/` | 案内の表示、赤枠、大きさの表示。`DrawHintView`・`RedFrameView`・`SizeLabelView`・`OverlayView` | App 01 |
| `Comment/` | 枠の横の入力欄。`CommentView`、複数行の入力欄 `GrowingTextController`（一覧と設定の定型文でも使う） | App 02 |
| `List/` | 注釈の一覧。`ListView`、サムネイルの切り抜き | App 03 |
| `Copied/` | コピー完了の表示（緑のチェックと `Prompt copied!`。件数は読み上げの文言にだけ入れる）。出入りの動き（ばねで出て、チェックの印を描き、文言が続く。消えるときは縮んでぼける）はこの部品が付け、パネルは動きが終わってから外す。`CopiedView` | App 04 |
| `MenuBar/` | メニューバーのアイコンとメニュー。制御役 `MenuBarController`、見出し `MenuHeaderView`。画面には出ないメインメニュー `MainMenuController`（`⌘Q`・`⌘,`・入力欄の編集のキー） | App 05 |
| `QuitConfirm/` | 終了・全削除の確認。共通の `ConfirmationController`・`ConfirmationView` が暗転・動き・キー処理を担当し、`ConfirmationPurpose` で文言と識別子を選ぶ。`QuitConfirmController` は終了用途の窓口 | App 09 |
| `Settings/` | 設定のウィンドウ。制御役 `SettingsController`、状態 `SettingsForm`、画面 `SettingsView` | App 06 |
| `Setup/` | 初回のセットアップ。制御役 `SetupController`、状態 `SetupFlow`、画面 `SetupView` | App 07・08 |
| `Common/` | 共通の部品。ボタンの見た目（`ControlButtonStyle`。ホバーの地の変化・押したときの縮み・指のカーソル）、ホバー中のカーソル（`hoverCursor(_:)`。`.activeAlways` の追跡領域で `NSCursor.set()` するので、アクティブでないパネルの上でも効く）、アイコン、文字のスタイルと影、キーの記録欄（`KeyRecorderModel` と、キー入力を受け取る `KeyCaptureView`。設定とセットアップで共通）、キーの表示（`ShortcutText`。キーボードの配列に従う）、小さなキーのチップと案内（`KeyChipsView` / `KeyHintView`。ボタン類・コメント入力・一覧の案内）、Paper の SVG のパスを描く `SVGPath` | — |
| `Windows/` | AppKit のパネルと通常のウィンドウ（下の「ウィンドウ」）。`SessionWindows`、`ContentWindow`、置き場所の計算 `PanelPlacement`、座標の変換 `ScreenCoordinates` | — |
| `Strings/` | 表示の文言の表（`EnglishStrings` / `JapaneseStrings`）と、引き方の `UIStrings`。言語はシステムではなく `Settings.language` で選ぶ。単数・複数は `PluralKey` で出し分ける | — |
| `Tokens.swift` | デザイントークン。動きは `Tokens.Motion`（出るときのばね、出始めの大きさ 0.96、消えるときの 0.15 秒、ホバーの 0.12 秒、押したときの 0.97、ページ送りのずらし） | — |
| `Resources/` | アプリのアイコン（タイル）とメニューバーのアイコン | — |

文言は文字列カタログ（`Localizable.xcstrings`）ではなく、Swift の表に置く。カタログは `swift test` ではコンパイルされず、`swift test` と `xcodebuild` で結果が変わるため。

#### 画面と制御役

メニューバー以外の画面（App 05〜09）は、次の 2 つに分ける。

- **SwiftUI の部品と状態**（`SettingsView` と `SettingsForm` など）。表示に要る値と、操作を受けるコールバックだけを持ち、`SessionModel` には触らない。
- **制御役**（`@MainActor` のクラス）。部品をウィンドウやパネルに載せ、`SessionModel` につなぐ。`AkapenApp` の組み立てはこの制御役を呼ぶ。

| 制御役 | 作り方 | 主な API |
| --- | --- | --- |
| `MenuBarController` | `init(model:)` | `onOpenSettings`・`onQuitRequested`（コールバック。自分では設定を開かず、終了もしない）。件数と言語はメニューを開くたびに `model` から読み直す |
| `QuitConfirmController` | `init(model:)`（言語だけを読む） | `show(annotationCount:)`、`hide()`、`isShown`、`onResult`（`.quit` / `.cancel`） |
| `SettingsController` | `init(model:canUseHotkey:)` | `show()`、`close()`、`isShown`、`onRecordingChanged`、`onClosed`、`refresh()`（ほかの所で変わった設定を映す）。変更はその場で `model.send(.settingsChanged(_:))` |
| `SetupController` | `init(model:permission:canUseHotkey:)` | `show()`、`showPermission()`（2 ページ目を開く）、`isShowingPermission`、`close()`、`isShown`、`refresh()`、`onCompleted`、`onDismissed`、`onRecordingChanged`。`Done` で `model.send(.setupCompleted)` |
| `MainMenuController` | `init(language:)` | `install()`、`setLanguage(_:)`、`onOpenSettings`・`onQuitRequested` |

`canUseHotkey` などの判定は、記録したキーを受け入れるかを組み立ての側が返す（実際に登録できるか）。false なら記録欄は元の値に戻り、`This shortcut is unavailable` を出す。`onRecordingChanged` が true の間は、組み立ての側でグローバルなホットキーの登録を外す（外さないと、いまのホットキーが記録欄に届かない）。

### AkapenAXID

識別子の一覧だけを持つ。アプリは `.accessibilityIdentifier(AXID.Toolbar.copyPrompt)` のように付け、テストは同じ定数で要素を引く。

```swift
public enum AXID {
    public enum Toolbar { public static let list = "toolbar.list", copyPrompt = "toolbar.copyPrompt" }
    public enum Draw    { public static let surface = "draw.surface", hint = "draw.hint" }
    public enum Comment { public static let field = "comment.field" }
    public enum List    { public static func row(_ i: Int) -> String { "list.row.\(i)" } /* … */ }
    // Settings / Setup / MenuBar / QuitConfirm
}
```

generator はこの一覧にある識別子だけを使う。足りないときは、テスト側でラベルや位置を頼りに探さず、識別子の追加を求めて止まる。

## 状態

`SessionModel` が 1 つの `phase` を持つ。`hidden / drawing / commenting / listOpen / copied` の 5 つ。

- **ボタン類が出ている ⇔ `drawing`・`commenting`・`listOpen`。** 出ているあいだは、画面全体を覆う透明のパネルがマウスを受け、カーソルは十字（下のアプリは操作できない）。枠を描くのは `drawing` のときだけ。
- 注釈は `hidden` に戻っても消えない。回は `copy prompt` で終わる（注釈が空になる）まで続く。

```
                  ホットキー（注釈があれば同じ回を続ける）
        ┌───────────────────────────────────────────┐
        │                                           ▼
     hidden ◀── ホットキー / Esc ─────────────── drawing ◀─────── 確定 / 取り消し / Esc ────┐
        ▲  ◀── ホットキー ── listOpen ◀─ 一覧 ─▶  │  ドラッグ終了（撮影）                     │
        │                    （閉じる / Esc で drawing）└─────────────────────────────▶ commenting
        │                                           │ copy prompt（drawing / listOpen から）
        └──────────────（一定時間）───── copied ◀────┘
                                          │ ホットキー: 新しい回で drawing
```

遷移の表（書いていない組み合わせは何もしない）:

| 状態 | ホットキー | `Esc` | ドラッグ終了 | 確定 / 取り消し | 一覧 | copy prompt | `dismissRequested` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `hidden` | `drawing`（注釈が 1 件以上なら回の ID と画像の番号を引き継ぐ。0 件なら新しい回） | — | — | — | — | — | — |
| `drawing` | `hidden`（注釈は残す） | `hidden`（注釈は残す） | 撮る範囲を決め、撮影を裏で始めてすぐ `commenting`（一覧を取れない・小さすぎる枠は `drawing` のまま） | — | `listOpen` | 注釈があれば `copied` | `hidden` |
| `commenting` | 何もしない（書きかけを失わない） | 書きかけを捨てて `drawing` | — | 確定: `drawing`（空のコメントは何もしない。撮影の完了前なら、完了を待ってから一覧に入れる）/ 取り消し: 書きかけを捨てて `drawing` | — | — | 書きかけを捨てて `hidden` |
| `listOpen` | `hidden` | `drawing`（編集中なら編集の取りやめだけ。`DECISIONS.md` A1。`SessionWindows` の入力欄が受ける） | — | — | `drawing` | 注釈があれば `copied` | `hidden` |
| `copied` | 新しい回で `drawing` | — | — | — | — | — | — |

- 入力は `send(_ event:)` の 1 本にまとめる（`hotkeyPressed` / `dragEnded(rect, screen)` / `commentConfirmed(text)` / `commentCancelled` / `escapePressed` / `listToggled` / `annotationEdited` / `annotationDeleted` / `annotationsCleared` / `copyPromptTapped` / `copiedExpired` / `dismissRequested` / `settingsChanged` / `setupCompleted`）。`annotationEdited` と `annotationDeleted` は `listOpen` のときだけ効く。`annotationsCleared` は注釈がある `drawing` / `listOpen` で注釈と画像を消し、状態を保つ。
- `dismissRequested` は、設定やセットアップのウィンドウを開くときに組み立ての側が送る（画面全体を覆う面がウィンドウを隠さないように）。
- 撮影・保存・クリップボードへの書き込みは、注入されたプロトコル越しに `SessionModel` が呼ぶ。だから一連の流れは `swift test` で、偽の実装を差して最後まで確かめられる。
- **枠を描き終えてから入力欄が出るまでを待たせない。** 流れは次のとおり。
  - `drawing` に入るたびに（ホットキー、コメントの確定のあと、一覧を閉じたあと、など）、ウィンドウの一覧（`WindowCapturing.windows()`）を取り始めておく。隠したら捨てる。取れなかった一覧は使い回さず、次のドラッグで取り直す。
  - ドラッグ終了では、先に取った一覧（まだ取れていなければ、取れるまで待つ）と、枠を描いたディスプレイ（`dragEnded` の `screen`）から、`CaptureRegion.resolve` で撮る範囲を決める。ウィンドウがなくても範囲は決まる（枠のまわり）ので、小さすぎる枠と一覧を取れないときを除き、必ず `commenting` に進む。
  - 書きかけ（`DraftAnnotation`。画像のパスはまだない）を作ってすぐ `commenting` に移り、撮影（`capture(region:on:)` が範囲を 1 回撮った `CGImage` を返す）→ 赤枠の描き込みと PNG への書き出し（メインアクターの外）を裏で進める。
  - 撮影の完了は、待ち行列の中の内部の入力として処理する。保存して、書きかけに画像のパス・アプリ名（枠内に見えているウィンドウのアプリ名を、見えている面積の大きい順に `, ` でつなぐ）・撮った範囲（`windowFrame`）を入れる。撮影か保存に失敗したら、書きかけを捨てて `drawing` に戻り、`captureFailed` / `imageSaveFailed` を出す。
  - 撮影の完了前に確定したら、その確定は撮影の完了を待ってから一覧に入れて `drawing` に戻る（待つあいだ、後の入力は処理しない）。撮影の完了前に `Esc` などで書きかけを捨てたら、その撮影の結果は保存しない。撮影には世代を付け、古い撮影の完了が新しい書きかけを書き換えないようにする。
  - 本番の `ScreenCaptureKitCapturer` は、`windows()` で取った `SCDisplay` と akapen 自身の `SCRunningApplication` を覚えておき、`capture(region:on:)` で `SCShareableContent` を取り直さない。撮影は、そのディスプレイから akapen 自身のアプリだけを外した絞り込み（`SCContentFilter(display:excludingApplications:exceptingWindows:)`）で、範囲を `sourceRect`（ディスプレイの左上を原点にした pt）に指定して `SCScreenshotManager.captureImage` を 1 回呼ぶ。大きさはディスプレイの実解像度（Retina なら 2 倍）、カーソルは写さない。ほかのウィンドウの影とデスクトップの壁紙は、画面に見えているとおりに写る。
  - akapen が画面にウィンドウを出していないと、`SCShareableContent.excludingDesktopWindows(_:onScreenWindowsOnly: true)` の `applications` に akapen が載らない。そのときは、画面に出ていないものも含めた一覧（100ms ほど）から探して覚える（`windows()` の中で行い、撮影を待たせない）。
- `isToolbarVisible` は `phase` から決まる（`drawing`・`commenting`・`listOpen` で true）。

## ウィンドウ

`phase` を見て出し入れするだけで、判断は持たない（どのパネルを出すかは `PanelPlan`）。

| ウィンドウ | 種類 | 出ている間 |
| --- | --- | --- |
| 覆う面 | 画面全体を覆う枠なしのパネル。マウスを受け取り、カーソルを十字にする | ボタン類が出ているあいだ（`drawing`・`commenting`・`listOpen`）。枠を描くのは `drawing` だけで、キーになれるのも `drawing` だけ（`Esc`・`⌘C`・`⌘L`・`⌘⌫` を受ける）。`commenting` では書きかけの赤枠を描く |
| ボタン類 | 手前に浮く、アクティブ化しないパネル | `drawing`・`commenting`・`listOpen` |
| コメント入力 | キー入力を受け取れる、アクティブ化しないパネル | `commenting` |
| 一覧 | 手前に浮く、キー入力を受け取れるパネル（`Esc`・`⌘C`・`⌘L` を受ける。編集中の `⌘C` は入力欄の文字のコピー） | `listOpen` |
| コピー完了の表示 | マウスを受け取らないパネル | `copied` |
| 設定 / セットアップ | 通常のウィンドウ（`ContentWindow`。タイトルバーは透明で、信号ボタンだけシステムが描く）。開くとアプリを前面に出してキー入力を受け取る（前面に出せなくても、ウィンドウは手前に出す） | 開いている間 |
| 全削除確認 | 終了確認と共通の暗転・キー入力を受けるパネル | `ConfirmationController.show` から答えが出るまで。ボタン類が隠れたとき・注釈が 0 件になったときは取り下げる |
| 終了確認 | メニューバーより下の画面全体を暗くする、キー入力を受け取れるアクティブ化しないパネル（`.modalPanel`。覆う面より手前） | `QuitConfirmController.show` から答えが出るまで |
| メニュー | 標準の `NSStatusItem` と `NSMenu`（見出しだけカスタムビュー） | アイコンは常に。メニューは開いている間 |
| メインメニュー | `NSApp.mainMenu`（LSUIElement なので画面には出ない）。`⌘Q`・`⌘,`・入力欄の編集のキーを効かせる | 常に |

パネルの出し入れの決まり（前の中身が一瞬見えないように）:

- 隠し終えたら（フェードの終わり）、中身を空に戻す。覆う面は赤枠も案内もない表示に、ほかのパネルは中身を見えない状態（`PanelPresentation.isPresented = false`）にする。
- 出すときは、見えない状態のまま中身を描き終えてから前に出し、そのあとで出る動き（ばね）を始める。窓の不透明度は 1 のまま出し、動きは SwiftUI の中身が受け持つ。
- 赤枠の出入りには動きを付けない（付けると前の枠が薄く残って見える）。動きを付けるのは上端の案内だけ。
- `SessionWindows` の `fadeDuration` が 0 なら動きを付けない（テスト用）。システムの「視差効果を減らす」は SwiftUI の `accessibilityReduceMotion` で読み、拡大縮小とずらしをやめる。

撮影は akapen 自身のアプリを外して行うので、akapen 自身のパネル（覆う面・赤枠・入力欄）は写り込まない。

## E2E の仕組み

### 流れ

```
DESIGN.md / Paper ──(planner)──▶ e2e/specs/**/*.md ──(generator)──▶ e2e/tests/Generated/**
                                   ▲ 人がレビュー                        │ make e2e
                                   └──── 落ちたら (healer) ◀──────────────┘
```

### ファイルごとの扱い

| パス | 変更方法 |
| --- | --- |
| `e2e/specs/**/*.md` | 直接編集（人・エージェントのどちらでも）。仕様変更は必ずここから。人がレビューして取り込む |
| `e2e/tests/Seed.swift` / `Support/**` / `Live/**` | 直接編集 |
| `e2e/tests/Generated/**` | **直接編集しない。** generator / healer 経由のみ |
| `Packages/AkapenKit/Sources/AkapenAXID/**` | 直接編集。識別子の追加はアプリ側の変更と同時に行う |
| `.claude/agents/e2e-*.md` | 直接編集 |

### 対応の規則

- md の書式は ashvally と同じ（`概要 / 前提 / 目的 / シナリオ`、`### 正常系` / `### 準正常系`、`####` 1 つがテスト 1 つ、`期待される結果:` と `してはいけないこと:`）。
- `specs/<dir>/<name>.md` → `tests/Generated/<dir>/<Dir><Name>Tests.swift`（例: `specs/draw/frame.md` → `Generated/draw/DrawFrameTests.swift`、クラス名も `DrawFrameTests`）。ファイル名にディレクトリ名を含めるのは、同じターゲットに同名の Swift ファイルを置けないため。
- 生成ファイルの先頭に、対応する spec のパスと、その md の内容のハッシュを入れる。各テスト関数の直前には、`####` のシナリオ名をそのままコメントで入れる。

```swift
// spec: e2e/specs/draw/frame.md
// spec-sha256: 3f9a…
// このファイルは生成物。直接編集しない。

final class DrawFrameTests: AkapenUITestCase {
    // scenario: 枠を描くと、その枠のあるウィンドウが画像として残る
    func testFrameCapturesWindow() throws { … }
}
```

- `check-specs.mjs` は次を確かめる。書式が揃っているか／各シナリオに UI に依存しない検証点があるか／各 md に生成ファイルがあるか／ハッシュが一致するか（md を直したのに再生成していない状態を落とす）／md のシナリオ名と生成ファイルの `// scenario:` が 1 対 1 か。

### 検証点（UI に依存しないもの）

ashvally の「保存されたデータ」に当たるものは 3 つ。各シナリオの `期待される結果:` に最低 1 つ入れる。

| 検証点 | `Support/Verify.swift` のヘルパー |
| --- | --- |
| クリップボードに入った文章 | `copiedPrompt()` — 定型文と「パス → コメント」の並びに分解して返す |
| 保存された画像 | `savedImage(at:)` — ファイルの有無、大きさ、赤枠の位置（赤い画素の外接矩形を、描いた枠と許容誤差つきで比べる） |
| アプリが持っている状態 | `appState()` — `state.json` を型のある値（`AppState`）で返す。`phase`、注釈、書きかけの注釈、設定、いまの回のフォルダ、出ている画面、登録しているホットキー。変わるまで待つのは `waitForPhase(_:)` / `waitForState(_:_:)` |

`appState()` は、テスト起動のときだけアプリが一時ディレクトリに書き出す `state.json`（v3。形は `docs/FOUNDATION.md`）を読む（状態が変わるたびに書き出す）。

### テスト用の切り口

すべて `AkapenApp/LaunchConfiguration.swift` の 1 か所で読み、依存の選び分けに使う。画面やロジックの中では「テスト中かどうか」を見ない。

| 環境変数 | 効果 |
| --- | --- |
| `AKAPEN_E2E=1` | E2E 用の依存に切り替える。`state.json` の書き出しを有効にする。これがないとき（本番）は、下の変数をすべて無視する |
| `AKAPEN_STATE_DIR=<dir>` | 設定（`settings.json`）・画像（`images/`）・`state.json` の置き場。テストごとに新しい一時ディレクトリ。E2E では必須 |
| `AKAPEN_PASTEBOARD=<name>` | 名前つきのクリップボードを使う。E2E では必須（一般のクリップボードに落とさない） |
| `AKAPEN_CAPTURE=fixture \| live` | 撮影の実装。既定は `fixture` |
| `AKAPEN_SEED=<json>` | 起動時の前提（設定の一部、画面収録の許可の有無、偽の撮影のウィンドウ、確定済みの注釈、ボタン類・一覧を出しておくか）。JSON をそのまま入れる。形は `docs/FOUNDATION.md`「AKAPEN_SEED」 |
| `AKAPEN_NOW=<ISO8601>` | 時計を固定する（フォルダ名と、古いフォルダの掃除の判定） |

E2E で必須の変数がない・値が読めない・seed が読めないときは、起動エラーにする（`AKAPEN_STATE_DIR/startup-error.txt` に理由を書いて終了する）。

本番ビルドでもこの読み取りは残す（自分専用のあいだは問題にしない）。配布を始めるときに、デバッグビルド限定にするかを決める。

### 起点と前提づくり

- `Support/AkapenUITestCase.swift` — すべてのテストの親。`setUp` で一時ディレクトリとテストごとのクリップボードの名前を用意し、`SampleTarget` を決まった位置と大きさ（等倍の `140,64,1000,660`）で起動する。**akapen は起動しない**（各テストが前提を選んで `launch(...)` で起動する）。`tearDown` で両方を終了し、一時ディレクトリを消し、クリップボードを手放す。失敗したときは画面の画像・要素ツリー・`state.json`・`AKAPEN_SEED`・クリップボード・画像の一覧を結果に添付する。要素は `element(_:)` / `sampleElement(_:)` で識別子から引く。
- `Support/Launch.swift` — 前提の指定と起動。`launch(.setupDone)`、`launch(.firstRun)`、`launch(.setupDone, settings: LaunchSettings(…))`、`launch(.setupDone, annotations: SeedAnnotation.samples(2))`、`launch(.setupDone, open: .toolbar / .list)`（ボタン類が出ている状態・一覧を開いている状態。省くと注釈があっても何も出ていない状態）、`launch(.setupDone, screenRecording: .denied)`、`relaunch()`（同じ置き場のまま起動し直す）、`placeOldSession(daysBeforeNow:)`（起動前に古い回を置く）。時刻は既定で固定する。注釈が既にある状態は UI を操作して作らず、`AKAPEN_SEED` で入れる。起動は `state.json` が書き出されるまで待つ。
- `Support/Gestures.swift` — 識別子だけでは書きにくい操作。ホットキー（`pressHotkey`・`startDrawing`）、枠（`drawFrame(around:)`・`drawFrame(_:)`・`dragBarely(on:)`）、コメント（`startCommenting`・`typeComment`・`newLineInComment`・`confirmComment`・`writeComment`）、ボタン類・一覧・メニューバー・設定・セットアップ・終了の確認の操作、ボタン類が出ているあいだのショートカット（`pressToolbarShortcut(.copyPrompt / .list)`）、キーの記録欄（`recordShortcut`）、ウィンドウを閉じる。
- `Support/Verify.swift` — 検証点。`copiedPrompt()`・`putOnPasteboard(_:)`、`savedImage(at:)`・`imageFiles()`・`assertImage(at:showsFrame:)`、`appState()`・`waitForPhase(_:)`・`waitForState(_:_:)`・`assertStateStays(_:_:)`・`waitForAppToQuit()`。待ちは `state.json` を 0.1 秒おきに読み直す（`XCTNSPredicateExpectation` は使わない）。
- `Seed.swift` — セットアップ済みで起動し、ホットキーを押してボタン類が出たところで終わるテスト。generator が書き方の見本として読み、`make e2e` では起動のスモークテストを兼ねる。

`SampleTarget` は Paper の「Sample App」に合わせた小さなウィンドウ（入力欄 3 つと Cancel / Submit）。Submit を押した回数を表示するので、「ボタン類を隠したあと下のアプリを操作できる」「ボタン類が出ているあいだは下のアプリに届かない」を確かめられる。

### エージェント

Playwright の MCP のように「実物を操作しながら書く」ことはできないので、generator と healer は「書く → 1 本だけ走らせる → 結果を読んで直す」を繰り返す。

| エージェント | 入力 | 出力 | 制約 |
| --- | --- | --- | --- |
| `e2e-planner` | DESIGN.md、Paper の画面、既存の specs | `specs/**/*.md` の下書き・抜け漏れの指摘 | 操作手順・文言・配置を書かない。検証点を各シナリオに最低 1 つ |
| `e2e-generator` | md 1 本、`Seed.swift`、`Support/**`、`AkapenAXID` | `Generated/**` の 1 ファイル | `Support` のヘルパーと `AXID` だけを使う。足りなければ止まって報告する。`make e2e ONLY=<クラス名>` が通るまで直す |
| `e2e-healer` | 落ちたテストの名前、結果（失敗の内容・画像・要素ツリー） | 直した生成ファイル、または不具合の報告 | 直してよいのは要素の引き方と待ち方だけ。アサーションの緩和・削除は禁止。満たせなければ `XCTSkip` で止め、不具合として報告する |

### 走らせ方

| コマンド | 内容 |
| --- | --- |
| `make test` | `swift test`（単体テスト） |
| `make e2e-lint` | `node e2e/check-specs.mjs` |
| `make e2e` | `make gen` → `xcodebuild test`（`Live/` 以外。`Seed` と `Generated/`。撮影は `fixture`） |
| `make e2e ONLY=DrawFrameTests` | 1 クラスだけ走らせる（generator / healer が使う） |
| `make e2e-live` | `Live/` だけを、実際の画面収録で走らせる（手元だけ。画面収録の許可が要る） |

CI は当面置かない。置くときは `make test`・`make e2e-lint`・`make e2e` を流すだけで、AI は使わない。

### 仕様の対象外

`specs/` に書かないもの。

- 画面収録の許可ダイアログそのもの。許可の有無による akapen 側の表示までを対象にし、有無は `AKAPEN_SEED` で作る
- 実際の画面が正しく写るか。`Live/` の手書きテストで見る
- 日本語変換中の `Enter`。`ConfirmKeyPolicy` の単体テストで見る
- ホバーで出る一時的な表示が写るかどうか
- ログイン時の自動起動
- 見た目が Paper と一致するか。実装のときに画面を撮って Paper と見比べる

## テストの分担

| 層 | 道具 | 見るもの |
| --- | --- | --- |
| 単体 | `AkapenCoreTests` | 状態の遷移、プロンプトの組み立て、撮る範囲の決め方、赤枠の描き込みと縮小、フォルダの掃除、確定キーの判定。依存はすべて偽物 |
| 結合（実装 1 つずつ） | `AkapenPlatformTests` | 画像の保存と掃除（一時ディレクトリの実ファイル）、設定の読み書き（専用の UserDefaults）、クリップボード（名前つき）、偽の撮影の実装 |
| 結合（画面と状態） | `AkapenUITests` | `phase` を変えたときにどのパネルが出て、どれが外れるか。隠したパネルの中身が空に戻り、出し直した直後に前の中身が見えないか。`⌘C` / `⌘L` がどの状態で受け付けられるか。入力欄でのキー入力が正しいイベントになるか。設定・セットアップ・終了確認・メニューの操作が、正しい `SessionEvent` とコールバックになるか。キーの記録欄。文言の表。見比べ用の PNG の書き出し（`build/ui-snapshots/`。画素の一致は確かめない） |
| 結合（一連の流れ） | `AkapenAppTests` | `AppEnvironment.make` で組んだ本物の依存に、イベントを順に送る。最後にクリップボードの文章と、ディスク上の画像と赤枠の位置を確かめる。環境変数ごとの依存の選び分けもここで見る |
| E2E（生成） | XCUITest + 偽の撮影 | 実物のアプリで、操作が状態・画像・クリップボードまで正しくつながっているか |
| E2E（手書き・手元だけ） | XCUITest + 実際の撮影 | ScreenCaptureKit で `SampleTarget` が写り、赤枠が正しい位置に入るか |

結合テストは md から生成せず、手で書く。E2E と同じ検証（クリップボード・画像・状態）を、画面の操作なしで数秒のうちに確かめられるので、流れの分岐（取り消し、0 件での `Esc`、削除後のコピーなど）の網羅はこちらで行い、E2E は代表的な流れに絞る。

`swift test` から確かめられないもの（E2E か `Live/` に任せる）:

- 実際の画面収録（`ScreenCaptureKitCapturer`）。テストを走らせる側のプロセスに画面収録の許可が要るため
- グローバルホットキーの登録が実際にキー入力を拾うか
- ドラッグ・クリック・キー入力が、実物のウィンドウを通ってイベントになるか

## 確かめた結果

2026-11-18、macOS 26.2 / Xcode 26.2 / XcodeGen 2.47.0、2 画面の実機で検証。1〜6 は foundation の段階のスパイク（当時の `FoundationSpikeTests`）、7〜11 は組み立て（app-wiring）の段階（当時の `Spike/SmokeTests`）で確かめた。どちらのテストも、生成テスト（`Generated/`）に置き換えて消した。いまは `Seed` と `Generated/` が `make e2e` で走る。以下は検証したときの記録で、秒数や件数はその時点のもの。

1. **Carbon ホットキー: 確認済み。** SampleTarget をアクティブにし、XCUITest の `typeKey(";", modifierFlags: .command)` を送ると `drawing` になった。E2E 専用の迂回入口は不要なので追加していない。`Seed` でも確認。
2. **非アクティブパネルと LSUIElement: 確認済み。** Toolbar の 3 ボタンを AkapenAXID で取得できた。描画後に `toolbar.add` をクリックして `drawing` に戻ることも確認（当時。「+」はのちに ux-revise でなくした）。
3. **座標ドラッグ: 確認済み。** SampleTarget のボタンの位置を基準に 180×110 pt を描き、state.json の x/y/width/height がそれぞれ 4 pt 以内で一致。描画面を外した後の下のボタンへのクリックで回数が 1 に増えた。Esc で hidden に戻った。最初の試行は下のアプリを宛先にドラッグし、XCTest の割り込み処理がアプリを再アクティブ化して失敗した。座標を描画面の要素へ変換して入力するよう修正。完全透明な面のヒットテストも避けるため、背景に 1% の alpha を設定した。
4. **AXID のリンク: 確認済み。** UI テストはパッケージ製品のうち AkapenAXID だけをリンクし、`import AkapenAXID` でビルド・実行できた。
5. **反復時間: 確認済み。** 当時の最終のテストコード 1 行編集後の `make e2e ONLY=FoundationSpikeTests` は 54.0 秒（テスト本体 24.8 秒）。その前の修正後の試行は 58.3 秒だった。60 秒を大きく超えないため build-for-testing / test-without-building の分離は現時点では追加しない。初回の全 2 件はコンパイルと失敗を含め 99.5 秒だった。
6. **GUI アプリへパス入り文章を貼って画像を読めるか: 未確認。** 元の設計の検証課題として残す。読まれない場合は PromptPasteboard に画像ファイルも入れる。
7. **ホットキーの押下が約 10 秒かかる問題: 解消済み。** 当初は `sample.typeKey(";", modifierFlags: .command)` が約 10 秒かかってから戻った。グローバルなホットキーは OS に横取りされて SampleTarget に届かず、XCTest が送り先のアプリのキー受け取りを待ちきるまで戻らなかったため。いまは `pressHotkey(_:)`（`e2e/tests/Support/Gestures.swift`）が、akapen がそのキーを登録しているとき（`state.json` の `hotkeys`）は akapen を、登録していないときは SampleTarget を送り先にして押す。詳しくは `e2e/README.md`「走らせ方」。
8. **`XCTNSPredicateExpectation` の待ちは当てにならなかった。** `state.json` が条件を満たしてから数秒あっても一致を拾わず時間切れになった（終了の確認）。`Support` の待ちは、`state.json` を 0.1 秒おきに読み直すポーリング（`poll`）にした。
9. **`XCUIApplication.terminate()` は確認を出さずに止める。** 注釈が残っていても `applicationShouldTerminate` を通らずに終了する（後始末と `relaunch()` が終了の確認で止まらない）。メニューの終了・`⌘Q`・Apple Event の quit は `applicationShouldTerminate` を通る。
10. **アクティブにならない起動。** `make run`（`open`）で起動すると、ほかのアプリが使われている最中なので `NSApp.activate()` が断られ、セットアップのウィンドウがほかのウィンドウの後ろに出た。設定とセットアップのウィンドウは、開くときに `orderFrontRegardless()` で手前に出すようにした。
11. **浮く部品は XCTest から「割り込みのダイアログ」に見える。** 枠を描く面へのドラッグの前に、XCTest がボタン類のパネルを割り込みとして扱い、akapen をアクティブにしてから続ける。ドラッグはそのまま通る。

12. **十字のカーソルにならないことがある問題: 原因を確認し、解消済み（2026-11-18、ux-revise）。** akapen はアクティブにならないアプリ（LSUIElement + アクティブ化しないパネル）なので、macOS は `NSCursor.set()` とカーソル矩形を無視する。十字になるのは、マウスが動いて `.activeAlways` の追跡領域が `mouseMoved` を受けたときだけで、出した直後にマウスを動かさないと矢印のまま残る（本番で 12 回中 7 回、1.5 秒たっても矢印のまま）。同じ作りの実験アプリで、出し方を変えて `NSCursor.currentSystem` を 0.1 秒おきに読んで比べた。窓の不透明度を 1 にして出す・何度も `set()` し直す、はどれも効かなかった。アプリをアクティブにする（撮影対象のタイトルバーが非アクティブの色になる）か、接続に `SetsCursorInBackground` を立てると毎回すぐ十字になった。後者を `BackgroundCursor` として入れ、出した直後と少しあと（0.05・0.15・0.3 秒）に、カーソルが覆う面の上にあれば十字を当てる。直したあとの本番の組み立てで同じ測り方をすると、12 回中 12 回、最初の読み取り（0.0 秒）から十字になり、隠すと矢印に戻った。一覧を閉じた直後も 0.1 秒のうちに十字になった。

13. **範囲の撮影（ScreenCaptureKit）: 実機で確認（2026-11-19、region-capture）。** 本番の `ScreenCaptureKitCapturer`・`CaptureRegion`・`FrameRenderer` をそのまま組み込んだ単独のプログラムで、外部ディスプレイ（5120×1440、倍率 1）と内蔵の Retina（1470×956、倍率 2）を撮った。画像の大きさはどちらも「範囲 × 倍率」ちょうど（例: 502×462pt → 502×462px / 1004×924px）で、縦横比は範囲と一致した。2 つのウィンドウの境目をまたぐ枠では両方を囲む範囲が撮れ、範囲に入ったほかのウィンドウとその影も画面のとおりに写った。`excludingDesktopWindows(true)` で取った `SCDisplay` の絞り込みでも、デスクトップの壁紙は写る（Dock と壁紙の持ち主以外を外して確かめた）。自分のアプリのウィンドウ（不透明のマゼンタ）は、自分のアプリを外した撮影で 0 画素、外さない撮影で 120000 画素だった。akapen が画面にウィンドウを出していないと `onScreenWindowsOnly: true` の一覧の `applications` に載らず、画面外も含めた一覧（約 100ms）には載る。1 回の撮影は 130〜300ms（範囲が広いほど長い）。

追加の検証: `make test` の `PanelTests` で NSApplication.shared を初期化し、AppKit の NSPanel を実際に生成して、状態ごとの表示・非表示、覆う面がマウスを受けるか・キーになれるか、隠したあとに中身が空に戻ること、nonactivatingPanel を確認している。テスト後はパネルを外す。画面のあるローカルセッションが必要で、ヘッドレス CI の保証はしていない。

## 実装の境界

- 公開 API と JSON の形（`state.json` v3、`AKAPEN_SEED`）は `docs/FOUNDATION.md` と各型の日本語ドキュメントコメントを参照。
- 本番の設定は `UserDefaults.standard` のキー `settings`（JSON）。書き出しは `StateWriting` → `AtomicStateWriter`。App が JSON を組み立て、Platform がファイルに原子的に保存する。
- 注釈はメモリにだけ持つ（起動し直すと 0 件。画像ファイルは日数による掃除まで残る）。
- Apple Development 証明書で署名。チーム G5564YSC93。プロファイル要求・認証ダイアログはなく、アドホックへの切り替えなし。
- E2E は Python 標準の fcntl.flock で同一リポジトリを排他制御し、Live 配下かどうかでクラスを選ぶ。全ログは build/logs、結果バンドルは build/e2e.xcresult。

2026-11-19: `annotationsCleared` は drawing / listOpen で確定済みの注釈と画像を消し、phase は維持する。全削除の要求は `SessionWindows.onClearRequested` から `AppController` に渡し、確認の確定時だけモデルへ送る。確認はボタン類が隠れたとき・注釈が 0 件になったときに取り下げる。`SessionSnapshot.Windows.clearConfirm` に表示状態を出す。

2026-11-20: 定型文は `Settings.customBoilerplate: String?` に 1 つだけ保持する。nil は言語の既定文への追従。`effectiveBoilerplate` からプロンプトを組み立て、空または現在の既定文の入力で nil に戻す。旧 `boilerplates` は保存言語の文だけを移行する。LaunchSeed は新旧両形式と明示的な null を受け付ける。`state.json` は `customBoilerplate`（null 可）と、互換用の `boilerplates`（en/ja の実効文）を両方出す。
