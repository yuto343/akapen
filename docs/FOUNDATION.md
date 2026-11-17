# Foundation の引き継ぎ

## 公開 API（2026-11-18）

パスの基準は `Packages/AkapenKit/Sources/`。

| ファイル | 契約 |
| --- | --- |
| `AkapenCore/Session/Phase.swift` | `Phase`（`hidden / drawing / commenting / idle / listOpen / copied`） |
| `AkapenCore/Session/Annotation.swift` | `Annotation(id:imagePath:comment:rect:sourceAppName:createdAt:windowFrame:)`。`windowFrame` は撮影した時点のウィンドウ矩形 |
| `AkapenCore/Session/SessionEvent.swift` | `SessionEvent` |
| `AkapenCore/Session/SessionFailure.swift` | `SessionFailure`（`noWindowUnderFrame / captureFailed / imageSaveFailed / pasteboardFailed / settingsSaveFailed`） |
| `AkapenCore/Session/SessionModel.swift` | `@MainActor @Observable SessionModel`。`init(settingsStore:capturing:pasteboard:images:clock:) throws`、`@discardableResult send(_:) -> Task<Void, Never>`（送った順に 1 つずつ処理。`await model.send(...).value` で完了を待てる）、読み取り専用 `phase / annotations / draft / settings / lastDrawnRect / isToolbarVisible / lastCopiedCount / lastFailure`、更新後通知 `onChange` |
| `AkapenCore/Capture/` | `ScreenRect(x:y:width:height:)`、`ScreenDescriptor(id:frame:)`、`CaptureWindow(id:frame:appName:title:)` |
| `AkapenCore/Settings/` | `Settings()`（`setupCompleted` を含む。古い保存内容にキーがなくても読める）、`Language`、`ConfirmKey` |
| `AkapenCore/Input/` | `KeyboardShortcut(keyCode:modifiers:)`、`KeyModifiers`、`ConfirmKeyDecision`、`ConfirmKeyPolicy.decide(modifiers:isComposing:confirmKey:)`（仮実装） |
| `AkapenCore/Ports/WindowCapturing.swift` | `windows() async throws`（手前のウィンドウから順に返す） / `capture(window:) async throws -> Data`（PNG） |
| `AkapenCore/Ports/PromptPasteboard.swift` | `write(text:imageURLs:) throws` |
| `AkapenCore/Ports/SettingsStore.swift` | `load() throws -> Settings` / `save(_:) throws` |
| `AkapenCore/Ports/ImageStore.swift` | `save(png:sessionID:index:) throws -> URL` / `remove(at:) throws` / `removeSessions(before:) throws` |
| `AkapenCore/Ports/HotkeyRegistering.swift` | `register(_:handler:) throws` / `unregister()` |
| `AkapenCore/Ports/ScreenRecordingPermission.swift` | `isGranted` / `request() -> Bool` |
| `AkapenCore/Ports/LoginItem.swift` | `isEnabled` / `setEnabled(_:) throws` |
| `AkapenCore/Ports/Clock.swift` | `now` / `sleep(for:) async throws` |
| `AkapenCore/Ports/StateWriting.swift` | `write(_:) throws`（App から OS のファイル操作を分離） |
| `AkapenPlatform/CarbonHotkey.swift` | `CarbonHotkey`、`RegistrationError.status`。登録エラーは呼び出し元に返す |
| `AkapenPlatform/MemorySettingsStore.swift`、`AtomicStateWriter.swift` | `MemorySettingsStore`、`AtomicStateWriter(url:)` |
| `AkapenUI/Windows/` | `SessionWindows(model:)` / `render()` / `hide()`、`ScreenCoordinates.rect(_:primaryTop:)` |
| `AkapenUI/MenuBar.swift`、`Tokens.swift`、`UIStrings.swift` | `MenuBar()`、`Tokens`、`UIStrings.text(_:)` |
| `AkapenApp/LaunchConfiguration.swift` | `LaunchConfiguration(environment:)`、`isE2E / stateDirectory / pasteboardName / capture / seedJSON / now` |
| `AkapenApp/AppEnvironment.swift`、`SessionSnapshot.swift` | `AppEnvironment.make(_:) throws`、`model / hotkey / stateWriteError`、`writeState()`、`SessionSnapshot(model:)` |
| `AkapenApp/AppDelegate.swift` | `AppDelegate()`。エントリから起動する組み立て役 |
| `AkapenAXID/AXID.swift` | Toolbar、Draw、Comment、List（row/edit/delete）、Copied、MenuBar、QuitConfirm、Settings、Setup、Sample の操作識別子 |

`SessionEvent` の入力は `hotkeyPressed / addTapped / escapePressed / dragEnded(rect:screen:) / commentConfirmed(text:) / commentCancelled / listToggled / annotationEdited(id:text:) / annotationDeleted(id:) / copyPromptTapped / copiedExpired / toolbarToggled / settingsChanged(_:) / setupCompleted`。

Core の座標は主画面左上を (0,0) とする全画面共通のポイント。左や上の画面は負座標。画面ごとのピクセル倍率とは別物。AppKit の変換は UI/Windows の境界だけで行う。

骨組みでは `hidden → drawing → idle` と drawing 中の Esc だけ実装した。撮影、draft の生成、コメント以降の入力、設定変更は `TODO(core)` で未実装。未接続の Ports は nil を許す。後続担当はこれらを AppEnvironment で注入する。起動設定のうち E2E と保存先のみ有効で、残りは読み取りまで。seed は未確定スキーマを勝手に固定しないため JSON 文字列として保持する。

## state.json v1

```json
{
  "schemaVersion": 1,
  "phase": "idle",
  "annotations": [],
  "settings": {
    "language": "en",
    "hotkey": {"keyCode": 41, "modifiers": 1},
    "confirmKey": "enter",
    "boilerplates": {"en": "…", "ja": "…"},
    "imageRetentionDays": 7,
    "setupCompleted": false
  },
  "lastDrawnRect": {"x": 100, "y": 200, "width": 180, "height": 110},
  "isToolbarVisible": true,
  "lastCopiedCount": 0
}
```

`toolbarShortcut` は未割り当てなら省略、割り当て済みなら hotkey と同型。`lastDrawnRect` は未描画なら明示的な null。注釈は `{id: UUID文字列, imagePath: 絶対パス, comment: 文字列, rect: 矩形, sourceAppName: 文字列, createdAt: ISO 8601 の文字列, windowFrame: 矩形}`。`isToolbarVisible` はボタン類を出すか（`phase` が `hidden` なら常に false）、`lastCopiedCount` は直前にコピーした注釈の件数。未実装の撮影・確定が入るまで annotations は空。

E2E だけ初期状態と各 send 後に atomic 書き出し。E2E で保存先がなければ起動エラー。ファイル I/O は Platform の StateWriting 実装に任せる。エラーは `stateWriteError` に残す。

## 運用

`make e2e` は Live 以外、`make e2e-live` は Live 配下のクラスのみ。`ONLY` は選択範囲に存在するクラス名を指定する。Live のテストは今回の範囲外のため、未追加の間は明示的に失敗する。`make e2e-lint` も後続担当のスクリプトができるまでは失敗する。

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
