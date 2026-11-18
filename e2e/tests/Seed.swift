import XCTest
import AkapenAXID

/// generator と healer が書き方の見本として読むテスト。`make e2e` では起動のスモークテストを兼ねる。
///
/// 書き方の決まり（`e2e/README.md`・`.claude/agents/e2e-generator.md`）:
/// - 親は `AkapenUITestCase`。`setUp` は SampleTarget だけを起動する。akapen は各テストが `launch(...)` で前提を選んで起動する。
/// - 前提は UI 操作で作らず、`launch(...)` の引数で作る（セットアップ済みか、設定、確定済みの注釈、画面収録の許可）。
/// - 主題の操作は `Gestures.swift` のヘルパーと、`AkapenAXID` の識別子で引いた要素で行う。
/// - 期待される結果は、`Verify.swift` の検証のヘルパー（アプリの状態・クリップボード・保存された画像）で確かめる。
///   画面の表示（要素が出ているか）だけで済ませない。状態は非同期に変わるので、`waitForPhase` / `waitForState` で待つ。
final class Seed: AkapenUITestCase {
    func testShowToolbar() throws {
        // 前提: セットアップ済みで起動している。注釈は 0 件で、何も出ていない。
        launch(.setupDone)
        XCTAssertEqual(appState().phase, .hidden)
        XCTAssertFalse(isShown(AXID.Toolbar.list))

        // 操作: ホットキー（⌘;）を押す。
        pressHotkey()

        // 期待される結果: ボタン類が出て、枠を描く状態になる。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertNil(state.draft)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Toolbar.copyPrompt)
        waitForElement(AXID.Draw.surface)
    }
}
