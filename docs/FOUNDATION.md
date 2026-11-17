# Foundation の引き継ぎ

## 公開 API（2026-11-18）

パスの基準は `Packages/AkapenKit/Sources/`。

| ファイル | 契約 |
| --- | --- |
| `AkapenCore/Session/Phase.swift` | `Phase`（`hidden / drawing / commenting / idle / listOpen / copied`） |
| `AkapenCore/Session/Annotation.swift` | `Annotation(id:imagePath:comment:rect:sourceAppName:createdAt:windowFrame:)`。`windowFrame` は撮影した時点のウィンドウ矩形 |
| `AkapenCore/Session/SessionEvent.swift` | `SessionEvent` |
| `AkapenCore/Session/SessionFailure.swift` | `SessionFailure`（`noWindowUnderFrame / captureFailed / imageSaveFailed / pasteboardFailed / settingsSaveFailed`） |
| `AkapenCore/Session/SessionModel.swift` | `@MainActor @Observable SessionModel`。`init(settingsStore:capturing:pasteboard:images:clock:) throws`（回の ID はこの Mac のタイムゾーン。依存を省けるのは撮影まで進まないテストのためで、撮影・置き場・時計のどれかがないドラッグ終了は `.captureFailed`、クリップボードがないコピーは `.pasteboardFailed`。読み込んだ設定と `settingsChanged` の日数は `imageRetentionDaysRange`（1〜365）に丸める）と、タイムゾーンを固定する `init(settingsStore:capturing:pasteboard:images:clock:timeZone:) throws`、`@discardableResult send(_:) -> Task<Void, Never>`（送った順に 1 つずつ処理。撮影の途中に送った入力は撮影のあとに処理する。待ちがなく同期で済む入力は呼び出しの中で処理を終える。`await model.send(...).value` で完了を待てる）、読み取り専用 `phase / annotations / draft / settings / lastDrawnRect / isToolbarVisible / lastCopiedCount / lastFailure / currentSessionID`（いまの回のフォルダ名。回を始めるまで nil）、状態が変わったときだけ呼ぶ `onChange`、起動時の掃除 `performStartupCleanup() throws`、定数 `minimumFrameSize`（4pt）・`copiedDisplayDuration`（2.5 秒） |
| `AkapenCore/Capture/` | `ScreenRect(x:y:width:height:)`、`ScreenDescriptor(id:frame:)`、`CaptureWindow(id:frame:appName:title:)`、`WindowPicker.pick(frame:from:)`（重なりの面積が最大のウィンドウ。同じ面積なら手前）、`FrameRenderer.render(png:windowFrame:frame:maxLongEdge:) throws -> Data`（赤枠 `#FF3E3E` を枠の外側に描き込み、長辺の上限を超えるときだけ縮小。既定の上限は `FrameRenderer.defaultMaxLongEdge` = 1568px） |
| `AkapenCore/Prompt/` | `PromptBuilder.build(settings:annotations:)` / `build(boilerplate:annotations:)`（DESIGN.md の例と同じ形。末尾に改行なし）、`Boilerplate.english / japanese / defaultText(for:) / defaults` |
| `AkapenCore/Storage/CacheLayout.swift` | `sessionID(for:timeZone:)`（`yyyyMMdd-HHmm`）、`fileName(index:)`（`01.png`…）、`date(fromSessionID:timeZone:)`、`sessionIDs(_:olderThan:timeZone:)`。Platform の `ImageStore` はこれで置き場を決める |
| `AkapenCore/Settings/` | `Settings()`（`setupCompleted` を含む。古い保存内容にキーがなくても読める）、`Settings.boilerplate(for:)`（書き換えていない言語は既定文。定型文を読むときはこれを使う）、`Settings.setBoilerplate(_:for:)`、`Language`、`ConfirmKey` |
| `AkapenCore/Input/` | `KeyboardShortcut(keyCode:modifiers:)`、`KeyModifiers`、`ConfirmKeyDecision`、`ConfirmKeyPolicy.decide(modifiers:isComposing:confirmKey:)`（`Enter` 確定: 修飾なしで確定・`Shift` で改行。`⌘Enter` 確定: `⌘` で確定・修飾なしで改行。変換中とそれ以外は passThrough） |
| `AkapenCore/Ports/WindowCapturing.swift` | `windows() async throws`（手前のウィンドウから順に返す） / `capture(window:) async throws -> Data`（PNG） |
| `AkapenCore/Ports/PromptPasteboard.swift` | `write(text:imageURLs:) throws` |
| `AkapenCore/Ports/SettingsStore.swift` | `load() throws -> Settings` / `save(_:) throws` |
| `AkapenCore/Ports/ImageStore.swift` | `save(png:sessionID:index:) throws -> URL` / `remove(at:) throws` / `removeSessions(before:) throws` |
| `AkapenCore/Ports/HotkeyRegistering.swift` | `register(_:handler:) throws` / `unregister()` |
| `AkapenCore/Ports/ScreenRecordingPermission.swift` | `isGranted` / `request() -> Bool` / `openSystemSettings()`（システム設定の「画面収録とシステムオーディオ録音」を開く） |
| `AkapenCore/Ports/LoginItem.swift` | `isEnabled` / `setEnabled(_:) throws` |
| `AkapenCore/Ports/Clock.swift` | `now` / `sleep(for:) async throws` |
| `AkapenCore/Ports/StateWriting.swift` | `write(_:) throws`（App から OS のファイル操作を分離） |
| `AkapenPlatform/CarbonHotkey.swift` | `CarbonHotkey`、`RegistrationError.status`。登録エラーは呼び出し元に返す。インスタンスごとに別のホットキー ID を持ち、自分の ID のイベントだけに反応する（「枠を描き始める」と「ボタン類の表示切り替え」を別インスタンスで同時に登録できる） |
| `AkapenPlatform/MemorySettingsStore.swift`、`AtomicStateWriter.swift` | `MemorySettingsStore`、`AtomicStateWriter(url:)` |
| `AkapenPlatform/Capture/ScreenCaptureKitCapturer.swift` | 本番の `WindowCapturing`。`init()`。`windows()` はレイヤー 0・画面上・akapen 以外・幅と高さ 40pt 以上（`minimumWindowSize`）を、`CGWindowListCopyWindowInfo` の並びで手前から返す。`capture(window:)` はそのウィンドウだけを実解像度（`pointPixelScale` 倍）で、カーソルと影なしで撮って PNG を返す。エラーは `CaptureError`（`permissionDenied / windowNotFound(id) / encodingFailed`） |
| `AkapenPlatform/Capture/FixtureCapturer.swift` | E2E・結合テスト用の `WindowCapturing`。`init(windows:scale:)`（`scale` 既定 2）。`windows()` は渡した配列をそのまま返す。`capture(window:)` は「ウィンドウの大きさ × scale」の決定的な PNG（明るい地・薄い格子・四隅の目印。赤い画素なし。R が G・B を超える画素を含まない）。大きさが 0 なら `FixtureError.emptyWindow` |
| `AkapenPlatform/Permission/` | `SystemScreenRecordingPermission()`（`CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`、システム設定を開く）、`FixedScreenRecordingPermission(isGranted:)`（`isGranted` は書き換え可。`request()` は今の値を返すだけ、`openSystemSettings()` は何もしない） |
| `AkapenPlatform/Pasteboard/SystemPromptPasteboard.swift` | `SystemPromptPasteboard(name:)`。`nil` で一般のクリップボード、名前ありでその名前のクリップボード。`write` は中身を置き換え、1 つ目の項目に文章、続く項目に画像ファイルの URL を入れる。失敗は `WriteError.rejected` |
| `AkapenPlatform/Settings/` | `UserDefaultsSettingsStore(defaults:)`（設定全体の JSON をキー `UserDefaultsSettingsStore.key` = `"settings"` にデータで保存）、`FileSettingsStore(url:)`（JSON ファイル。保存は原子的、親フォルダは自動で作る）。どちらも未保存なら `Settings()`、読めない内容は `SettingsStoreError.corrupted` |
| `AkapenPlatform/Storage/FileImageStore.swift` | `FileImageStore(root:timeZone:)`、`FileImageStore.defaultRoot()`（`~/Library/Caches/akapen/`）。`save` は `<root>/<回の ID>/<CacheLayout.fileName>` に原子的に書き、既存ファイルは上書きせず次の空き番号で保存して実際の URL を返す。`remove(at:)` は `root` の下のファイルだけ（`..`・シンボリックリンクで外に出るもの、フォルダは拒否）。`removeSessions(before:)` は `CacheLayout` で古いと判定された回のフォルダだけを消す（回の ID でない名前、ファイル、シンボリックリンクには触らない）。エラーは `StoreError` |
| `AkapenPlatform/Clock/` | `SystemClock()`、`FixedClock(now:)`（`now` は固定、`sleep` は実時間で待つ） |
| `AkapenPlatform/LoginItem/` | `SystemLoginItem()`（`SMAppService.mainApp`。`isEnabled` は `.enabled` のときだけ true）、`NoopLoginItem(isEnabled:)`（OS に触らず、値をメモリにだけ持つ） |
| `AkapenUI/Windows/` | `SessionWindows(model:)` / `render()` / `hide()`、`SessionViewState`（`failure` に `lastFailure` を持つ。枠を描く状態の撮影の失敗と、ボタン類だけ・一覧のときのコピーと設定の保存の失敗を、上端の案内の文言で知らせる。`DECISIONS.md` A9）、`ScreenCoordinates.rect(_:primaryTop:)`。設定とセットアップのウィンドウは、開くときにアプリを前面に出せなくても手前に出す（`orderFrontRegardless`） |
| `AkapenUI/MenuBar/` | `MenuBarController(model:)`（`NSStatusItem` と `NSMenu`）。`onOpenSettings` / `onQuitRequested`（自分では設定を開かず、終了もしない。コールバックがない項目は使えない状態）。件数（確定済みの注釈）と言語はメニューを開くたびに読み直す。`MenuBarStatus`、`MenuHeaderView`。`MainMenuController(language:)`（画面には出ないメインメニュー。`⌘Q`・`⌘,` と、入力欄の編集のキー `⌘Z`・`⇧⌘Z`・`⌘X`・`⌘C`・`⌘V`・`⌘A` を効かせる）、`install()`、`setLanguage(_:)`、`onOpenSettings` / `onQuitRequested` |
| `AkapenUI/QuitConfirm/` | `QuitConfirmController(model:)`。`show(annotationCount:)`（出ている間にもう一度呼んでも 1 つのまま、件数だけ新しくする）、`hide()`、`isShown`、`onResult`（`QuitConfirmResult.quit` / `.cancel`。`Return` で quit、`Esc` で cancel）。`QuitConfirmView` |
| `AkapenUI/Settings/` | `SettingsController(model:canUseHotkey:canUseToolbarShortcut:)`。`show()`（開いていれば前面に出すだけ）、`close()`、`isShown`、`onRecordingChanged`、`onClosed`、`refresh()`（ほかの所で変わった設定のうち、変わった項目だけを映す。記録を待っている記録欄には触らない）。変更はその場で `settingsChanged`。日数は 1〜365 に丸める |
| `AkapenUI/Setup/` | `SetupController(model:permission:canUseHotkey:)`。`show()`、`showPermission()`（2 ページ目を開く）、`isShowingPermission`、`close()`、`isShown`、`refresh()`（言語と、記録を待っていないときのホットキーを映す）、`onCompleted`、`onDismissed`、`onRecordingChanged`、`SetupController.defaultPollInterval`（1 秒）。2 ページ目の間だけ `isGranted` を確かめる。`Done` で `setupCompleted`、閉じただけでは送らない |
| `AkapenUI/Tokens.swift`、`Strings/` | `Tokens`、`UIStrings(language:)`（`subscript(StringKey)`、`plural(_:count:)`、`menuStatus(count:)`、`setupStep(current:total:)`、`failureMessage(_:)` など）、`UIStrings.text(_:language:)`。文言は `EnglishStrings` / `JapaneseStrings` の Swift の表にある（文字列カタログは使わない） |
| `AkapenApp/LaunchConfiguration.swift` | `LaunchConfiguration(environment:)`、`isE2E / stateDirectory / pasteboardName / capture / seedJSON / now / problems`。`AKAPEN_E2E` が `1` でなければ（本番）ほかの変数はすべて無視する。E2E で足りない・読めない値は `problems`（`invalidE2EFlag / missingStateDirectory / relativeStateDirectory / missingPasteboardName / invalidCapture / invalidNow`） |
| `AkapenApp/LaunchSeed.swift` | `AKAPEN_SEED` の JSON（下の「AKAPEN_SEED」）。`LaunchSeed.parse(_:) throws`（`ParseError.invalid`）、`json()`、`SettingsPatch.applied(to:)`、`fixtureWindows`、`defaultWindows` |
| `AkapenApp/AppEnvironment.swift` | `AppEnvironment.choose(_:) throws -> Choice`（OS に触らずに実装を選ぶ）、`AppEnvironment.make(_:) async throws`（依存一式と、seed の設定・古い回の掃除・seed の注釈と `open` まで）、`reportStartupFailure(_:configuration:)`。`configuration / choice / model / settingsStore / images / pasteboard / capturer / clock / permission / loginItem / hotkeys / startupCleanupError / stateWriteError`、`onModelChange`、`windowStatus`、`startWritingState()`、`writeState()`、`snapshot()`。`StartupError`（`invalidConfiguration / invalidSeed / seedSettingsNotSaved / seedAnnotationFailed / seedOpenFailed`） |
| `AkapenApp/HotkeyCoordinator.swift` | `HotkeyCoordinator(draw:toolbar:probe:onDraw:onToolbar:)`。`apply(_:)`（変わった役だけ登録し直す）、`setSuspended(_:by:)`（記録欄が記録を待つ間は両方外す）、`canUse(_:for:)`（記録欄に渡す判定。試しに登録して確かめる。`DECISIONS.md` A8）、`unregisterAll()`、`status`、`onRegistrationFailed`（前のキーに戻したときはそのキーを渡す） |
| `AkapenApp/AppController.swift`、`QuitPolicy.swift`、`PermissionCheckedCapturer.swift` | 画面のつなぎ（内部）。`QuitPolicy.pendingCount(_:)`（確定済みの件数 + 書きかけがあれば 1。0 なら確認なしで終了）。`PermissionCheckedCapturer(base:permission:)`（許可がなければ撮影を断る。偽の撮影を許可に従わせる） |
| `AkapenApp/SessionSnapshot.swift` | `state.json` v2 の中身（下の「state.json v2」） |
| `AkapenApp/AppDelegate.swift` | `AppDelegate()`。エントリから起動する組み立て役。`applicationShouldTerminate` で終了の確認を出すかを決める（メニュー・`⌘Q`・システムの終了の要求のどれも同じ判断） |
| `AkapenAXID/AXID.swift` | Toolbar、Draw（surface/hint/sizeLabel/frame）、Comment、List（row/edit/delete/field/comment/thumbnail/panel/empty/retention）、Copied、MenuBar（icon/status/settings/quit）、MainMenu（settings/quit/undo/redo/cut/copy/paste/selectAll）、QuitConfirm（panel/message/confirm/cancel）、Settings（window と各項目・選択肢・知らせ）、Setup（window/hotkey/hotkeyMessage/next/back/permission/requestPermission/done）、Sample の操作識別子 |

`SessionEvent` の入力は `hotkeyPressed / addTapped / escapePressed / dragEnded(rect:screen:) / commentConfirmed(text:) / commentCancelled / listToggled / annotationEdited(id:text:) / annotationDeleted(id:) / copyPromptTapped / copiedExpired / toolbarToggled / settingsChanged(_:) / setupCompleted`。

Core の座標は主画面左上を (0,0) とする全画面共通のポイント。左や上の画面は負座標。画面ごとのピクセル倍率とは別物。AppKit の変換は UI/Windows の境界だけで行う。

状態の遷移は `.director/core/brief.md` の決まりどおりに実装済み（撮影 → draft → コメント → 一覧 → コピー → 2.5 秒後に hidden、ボタン類の表示切り替え、設定の保存、失敗の記録）。組み立て（`AkapenApp`）がすべての依存を差すので、撮影せずに idle へ進む仮の挙動（`TODO(app)`）は消した。

## state.json v2

E2E（`AKAPEN_E2E=1`）のときだけ、`AKAPEN_STATE_DIR/state.json` に書き出す。書き出しを始めるのは、起動時の前提づくり（`AKAPEN_SEED`）と画面の組み立てを終えたあと（ファイルができた時点で起動が済んでいる）。そのあとは `SessionModel` の状態が変わるたびと、設定・セットアップ・終了の確認の出入り、キーの記録欄の記録の始まりと終わりで書き出す。原子的に置き換える（`AtomicStateWriter`）。失敗は `AppEnvironment.stateWriteError` に残す。

```json
{
  "schemaVersion": 2,
  "phase": "commenting",
  "isToolbarVisible": true,
  "annotations": [
    {"id": "UUID", "imagePath": "/…/images/20261118-1432/01.png", "comment": "…", "rect": {"x": 999, "y": 452, "width": 110, "height": 48},
     "sourceAppName": "Sample App", "createdAt": "2026-11-18T05:32:10Z", "windowFrame": {"x": 140, "y": 64, "width": 1000, "height": 660}}
  ],
  "draft": {"id": "UUID", "imagePath": "/…/images/20261118-1432/02.png", "comment": "", "rect": {…}, "sourceAppName": "Sample App", "createdAt": "…", "windowFrame": {…}},
  "lastDrawnRect": {"x": 100, "y": 200, "width": 180, "height": 110},
  "lastCopiedCount": 0,
  "lastFailure": null,
  "settings": {
    "language": "en",
    "hotkey": {"keyCode": 41, "modifiers": 1},
    "toolbarShortcut": null,
    "confirmKey": "enter",
    "boilerplates": {"en": "…", "ja": "…"},
    "imageRetentionDays": 7,
    "setupCompleted": true
  },
  "storage": {"imagesDirectory": "/…/images/", "sessionID": "20261118-1432", "sessionDirectory": "/…/images/20261118-1432/"},
  "windows": {"settings": false, "setup": false, "setupPage": null, "quitConfirm": false},
  "hotkeys": {"draw": {"keyCode": 41, "modifiers": 1}, "toolbar": null, "suspended": false, "failed": []}
}
```

- 値がないものは `null` として書く（キーを省かない）。矩形は画面全体を通した、左上が原点の pt。日付は ISO 8601。
- `phase`: `hidden / drawing / commenting / idle / listOpen / copied`。`isToolbarVisible` はボタン類を出すか（`hidden` と `copied` では常に false）。
- `annotations`: 確定済みの注釈（確定した順）。`draft`: 書きかけの注釈（撮影済みでコメントが未確定。`comment` は空）。なければ `null`。
- `lastFailure`: 直前の操作の失敗（`noWindowUnderFrame / captureFailed / imageSaveFailed / pasteboardFailed / settingsSaveFailed`）。次に何かの入力が成功すると `null`。
- `settings`: 設定。`toolbarShortcut` は未割り当てなら `null`。`boilerplates` は言語ごとの定型文で、書き換えていない言語も既定文を入れて全言語を書く。`modifiers` は `command=1 / shift=2 / option=4 / control=8` のビットの和。
- `storage`: 画像の置き場の根と、いまの回（`sessionID` は `yyyyMMdd-HHmm`。回を始めるまで `null`）。
- `windows`: 設定・セットアップ・終了の確認が出ているか。`setupPage` はセットアップの出ているページ（`hotkey` / `permission`。出ていなければ `null`）。
- `hotkeys`: 実際に登録しているグローバルなホットキー（`draw` は枠を描き始める、`toolbar` はボタン類の表示切り替え）。`suspended` はキーの記録欄が記録を待っている間 true（登録を外している）。`failed` は直前の登録に失敗した役。

v1 からの変更: `draft`・`lastFailure`・`storage`・`windows`・`hotkeys` を足した。`settings.toolbarShortcut` を省かずに `null` で書き、`settings.boilerplates` を全言語で書くようにした。

## AKAPEN_SEED

E2E の起動時の前提。JSON を環境変数にそのまま入れる（ファイルのパスではない。`LaunchConfiguration` を純粋に保ち、`AkapenApp` からファイルを読まないため）。E2E のときだけ読む。読めない・形が違う・知らないキーがあるときは起動エラー（E2E では `AKAPEN_STATE_DIR/startup-error.txt` に理由を書いて終了する）。

```json
{
  "settings": {"language": "ja", "hotkey": {"keyCode": 40, "modifiers": 12}, "toolbarShortcut": null, "confirmKey": "commandEnter",
               "boilerplates": {"en": "…"}, "imageRetentionDays": 3, "setupCompleted": true},
  "screenRecording": "granted",
  "windows": [{"frame": {"x": 140, "y": 64, "width": 1000, "height": 660}, "appName": "Sample App", "title": "Sample App"}],
  "annotations": [{"comment": "…", "rect": {"x": 999, "y": 452, "width": 110, "height": 48}}],
  "open": "list"
}
```

| キー | 意味 |
| --- | --- |
| `settings` | 設定の一部。保存済みの設定（起動し直したときは前の起動で保存された値、なければ既定値）に、書いた項目だけを重ねて `settingsChanged` で保存する。`toolbarShortcut: null` で未割り当て。`boilerplates` は書いた言語だけを書き換える。日数は 1〜365 に丸める |
| `screenRecording` | `granted`（既定）/ `denied`。偽の撮影のときだけ効く（`denied` なら撮影が失敗する） |
| `windows` | 偽の撮影が返すウィンドウ（手前から順）。省くと SampleTarget の既定の位置と大きさ（`140,64,1000,660`、`Sample App`） |
| `annotations` | 確定済みの注釈。起動時に、ホットキー（2 件目からは「+」）→ 枠 → コメントの確定を `SessionModel` に順に送って作る。画像は本来と同じ経路（偽の撮影 → 赤枠の描き込み → 置き場）で保存される。起動後はボタン類だけが出ている |
| `open` | `toolbar`（ボタン類だけが出ている。注釈 0 件でも）/ `list`（一覧を開いている）。`toolbarToggled` と `listToggled` を送って作る |

起動時の処理の順は、seed の設定 → 古い回の掃除（設定の日数で判定）→ seed の注釈 → `open` → 画面の組み立て → `state.json` の書き出しの開始。

## 依存の選び分け

| | 本番 | E2E（`AKAPEN_E2E=1`） |
| --- | --- | --- |
| 設定 | `UserDefaultsSettingsStore(.standard)` | `FileSettingsStore(AKAPEN_STATE_DIR/settings.json)` |
| 画像 | `FileImageStore(~/Library/Caches/akapen/)` | `FileImageStore(AKAPEN_STATE_DIR/images/)` |
| クリップボード | 一般のクリップボード | `AKAPEN_PASTEBOARD` の名前つき（なければ起動エラー） |
| 撮影と許可 | `ScreenCaptureKitCapturer`、`SystemScreenRecordingPermission` | `fixture`（既定）: `PermissionCheckedCapturer(FixtureCapturer)`、`FixedScreenRecordingPermission`。`live`: 本番と同じ |
| 時計 | `SystemClock` | `AKAPEN_NOW` があれば `FixedClock`、なければ `SystemClock` |
| ログイン時の起動 | `SystemLoginItem` | `NoopLoginItem` |
| `state.json` | 書かない | `AKAPEN_STATE_DIR/state.json` |

## 運用

`make e2e` は Live 以外（`Seed`、`Spike/SmokeTests`、`Generated/`）、`make e2e-live` は Live 配下のクラス（`LiveCaptureTests`）のみ。`ONLY` は選択範囲に存在するクラス名を指定する。`make e2e-lint` は、生成テストができるまで「生成ファイルが無い」で落ちる。

ロックはリポジトリの絶対パスのハッシュを名前にして OS の一時ディレクトリへ置く。`fcntl.flock` でプロセス終了時も解放され、待機中の実行は順番に進む。`make clean` でロックの inode が入れ替わらない。

## 受け入れ確認

- `make gen`: 成功。3 ターゲットを生成。
- `make build`: 成功。Swift 6、macOS 15.0、Sandbox なし、LSUIElement=true。
- `make test`: 成功。Swift Testing 6 件（Core 1、Platform 1、UI 2、App 2）。
- `make e2e`: 成功。Spike と Seed の 2 件、失敗 0。最終の全件ログは `build/logs/e2e-all.log` と `build/logs/e2e-all-summary.json`（所要 75.7 秒）。
- `cmp AGENTS.md .director/AGENTS.draft.md`: 一致。
- `git diff --check`: 成功。
- 最終 build と E2E 全件のログに `warning:` / `error:` なし。AppIntents を使用しないため、Xcode 内部のメタデータ抽出は `LM_SKIP_METADATA_EXTRACTION=YES`。
- `codesign -dvv`: Apple Development: <名前> (ZC8TW78G32)、TeamIdentifier G5564YSC93。アドホックへの切り替えなし。

検証 1〜6 の操作と結果は `ARCHITECTURE.md` の「確かめた結果」に記録。追加の AppKit パネル検証は `panelsFollowState`。GUI アプリへパス入り文章を貼って画像を読めるかは、このブリーフの範囲外なので未確認。

残す作業は、ブリーフのスコープ外である撮影・コメント・一覧・コピー・永続設定・セットアップ・終了確認と正式デザイン。E2E の仕様 md・README・lint・生成エージェントは今回作っていない。コミット・push・ブランチ変更もしていない。

最終の 1 行編集後の `make e2e ONLY=FoundationSpikeTests` は成功（1 件、54.0 秒）。最新の結果は `build/e2e.xcresult`、ログは `build/logs/test.log`。60 秒を大きく超えないため、実行とビルドの分離は追加していない。

## 組み立て（app-wiring）の受け入れ確認（2026-11-18）

- `make test`: 成功。Swift Testing 324 件（`AkapenAppTests` は 50 件: 一連の流れ・分岐・設定の選び分け・`AKAPEN_SEED`・`state.json`・ホットキーの登録）。
- `make build`: 成功。警告なし。
- `make e2e`: 成功。`Seed` 1 件と `Spike/SmokeTests` 3 件（ホットキー → 枠 → コメント → 一覧 → コピー、メニューバーから設定と終了の確認、初回のセットアップ）。所要 126 秒。
- `make e2e-lint`: 18 本すべて「生成ファイルが無い」だけで落ちる（`--specs-only` は OK）。
- `make e2e-live`: 落ちる。akapen に画面収録の許可がないため撮影に失敗し、akapen がセットアップの 2 ページ目（許可の案内）を開いた。許可のダイアログは出ない（`CGPreflightScreenCaptureAccess` だけを呼ぶ）。
- `make run`（本番の組み立て）: メニューバーにアイコンが出て、セットアップ（1 ページ目、既定の `⌘;`）が手前に出ることを画面の画像で確認。終了後、`defaults read com.yuto343.akapen` はドメインなし、`~/Library/Caches/akapen` はなし。ログイン時の起動は有効にしていない。
