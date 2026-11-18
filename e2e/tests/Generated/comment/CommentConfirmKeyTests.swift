// spec: e2e/specs/comment/confirm-key.md
// spec-sha256: 53f57591ab30d1dcbce4eb9af96eb5a3174dc3d847ad653f3fca4c5f61459704
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class CommentConfirmKeyTests: AkapenUITestCase {
    // scenario: Enter で確定する設定では、Enter で確定し、Shift+Enter で改行が入る
    func testEnterConfirmsAndShiftEnterBreaksLine() throws {
        // 前提: 確定キーは Enter。注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .enter))
        XCTAssertEqual(appState().settings.confirmKey, .enter)
        startCommenting()

        // 操作: 1 行目を書いて Shift+Enter を押す。
        typeComment("First line")
        pressReturnInComment(modifiers: .shift)

        // 期待される結果: Shift+Enter のあとも入力欄は出たまま。
        // してはいけないこと: Shift+Enter で確定され、1 行目だけの注釈になる。
        assertStateStays("Shift+Enter ではコメントを書いている状態のまま", for: 0.5) { state in
            state.phase == .commenting && state.annotations.isEmpty
        }
        XCTAssertTrue(isShown(AXID.Comment.field))

        // 操作: 2 行目を書いて Enter を押す。
        typeComment("Second line")
        pressReturnInComment(modifiers: [])

        // 期待される結果: Enter を押すと入力欄が消える。
        // してはいけないこと: Enter を押しても確定されず、改行が入る。
        let state = waitForPhase(.drawing)
        waitForElementToDisappear(AXID.Comment.field)

        // 期待される結果: アプリの状態で、注釈が 1 件でき、そのコメントは Shift+Enter を押した位置で改行された 2 行になっている。
        XCTAssertEqual(state.comments, ["First line\nSecond line"])
    }

    // scenario: ⌘Enter で確定する設定では、⌘Enter で確定し、Enter で改行が入る
    func testCommandEnterConfirmsAndEnterBreaksLine() throws {
        // 前提: 確定キーは ⌘Enter。注釈は 0 件で、コメントの入力欄が出ている。
        launch(.setupDone, settings: LaunchSettings(confirmKey: .commandEnter))
        XCTAssertEqual(appState().settings.confirmKey, .commandEnter)
        startCommenting()

        // 操作: 1 行目を書いて Enter を押す。
        typeComment("First line")
        pressReturnInComment(modifiers: [])

        // 期待される結果: Enter のあとも入力欄は出たまま。
        // してはいけないこと: Enter だけで確定され、1 行目だけの注釈になる。
        assertStateStays("Enter ではコメントを書いている状態のまま", for: 0.5) { state in
            state.phase == .commenting && state.annotations.isEmpty
        }
        XCTAssertTrue(isShown(AXID.Comment.field))

        // 操作: 2 行目を書いて ⌘Enter を押す。
        typeComment("Second line")
        pressReturnInComment(modifiers: .command)

        // 期待される結果: ⌘Enter を押すと入力欄が消える。
        // してはいけないこと: ⌘Enter で改行が入るだけで、確定されない。
        let state = waitForPhase(.drawing)
        waitForElementToDisappear(AXID.Comment.field)

        // 期待される結果: アプリの状態で、注釈が 1 件でき、そのコメントは Enter を押した位置で改行された 2 行になっている。
        XCTAssertEqual(state.comments, ["First line\nSecond line"])
    }

    // scenario: 設定で確定キーを切り替えると、次のコメントからその確定キーで確定する
    func testSwitchingConfirmKeyAppliesToNextComment() throws {
        // 前提: 確定キーは既定（Enter で確定）。注釈は 0 件。
        launch(.setupDone)
        XCTAssertEqual(appState().settings.confirmKey, .enter)

        // 操作: 設定で確定キーを ⌘Enter に切り替える。
        openSettingsFromMenuBar()
        chooseConfirmKey(.commandEnter)

        // 期待される結果: アプリの状態で、設定の確定キーが ⌘Enter になっている。
        // してはいけないこと: 設定の画面では切り替わって見えるのに、アプリの状態の確定キーが元のまま。
        let switched = waitForState("確定キーが ⌘Enter になる") { $0.settings.confirmKey == .commandEnter }
        XCTAssertEqual(switched.settings.confirmKey, .commandEnter)
        closeSettings()

        // 操作: 起動し直さずに、枠を描いてコメントを書く。Enter で改行し、⌘Enter で確定する。
        startCommenting()
        typeComment("First line")
        pressReturnInComment(modifiers: [])
        assertStateStays("Enter ではコメントを書いている状態のまま", for: 0.5) { state in
            state.phase == .commenting && state.annotations.isEmpty
        }
        typeComment("Second line")
        pressReturnInComment(modifiers: .command)

        // 期待される結果: アプリの状態で、切り替えたあとに描いた枠のコメントは、Enter で改行され、⌘Enter で確定した注釈になっている。
        // してはいけないこと: 切り替えが、アプリを起動し直すまで効かない。
        let state = waitForPhase(.drawing)
        XCTAssertEqual(state.comments, ["First line\nSecond line"])
        XCTAssertEqual(state.settings.confirmKey, .commandEnter)
    }
}
