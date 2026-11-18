// spec: e2e/specs/setup/first-run.md
// spec-sha256: 4e482992e357c9f02a39e5940058e721f53d507ff61a4a984fb753b64094d8d3
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SetupFirstRunTests: AkapenUITestCase {
    /// セットアップで割り当てる、既定と違うホットキー（⌃⌥K）。
    private let changedHotkey = Shortcut(key: "k", modifiers: [.control, .option])

    // scenario: 初めての起動でセットアップが出る
    func testFirstLaunchShowsSetup() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。
        launch(.firstRun)

        // 期待される結果: 起動すると、セットアップのウィンドウが出る。
        // してはいけないこと: 何も案内せずに、裏で常駐し始める。
        waitForElement(AXID.Setup.window)
        let shown = waitForState("セットアップのウィンドウが出る") { $0.windows.setup }
        XCTAssertEqual(shown.windows.setupPage, .hotkey)

        // 期待される結果: アプリの状態で、セットアップは終わっていない。
        // してはいけないこと: セットアップのウィンドウが出ただけで、セットアップ済みになる。
        let stayed = assertStateStays("セットアップは終わっていないまま") { $0.windows.setup && !$0.settings.setupCompleted }
        XCTAssertFalse(stayed.settings.setupCompleted)
    }

    // scenario: セットアップを終えると、次の起動では出ない
    func testFinishedSetupIsNotShownAgain() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。
        launch(.firstRun)
        waitForElement(AXID.Setup.window)
        XCTAssertFalse(appState().settings.setupCompleted)

        // 操作: セットアップを最後まで進めて終える。
        continueSetup()
        finishSetup()

        // 期待される結果: アプリの状態で、セットアップを終えた直後にセットアップ済みになっている。
        let finished = waitForState("セットアップ済みになる") { $0.settings.setupCompleted }
        XCTAssertTrue(finished.settings.setupCompleted)
        XCTAssertFalse(finished.windows.setup)

        // 操作: 同じ設定の置き場のまま、起動し直す。
        relaunch()

        // 期待される結果: 起動し直すとセットアップのウィンドウは出ず、アプリの状態でもセットアップ済みのまま。
        // してはいけないこと: 終えたのに、次の起動でもう一度セットアップが出る。
        // してはいけないこと: 起動し直すと、セットアップ済みの記録が消えている。
        let relaunched = assertStateStays("起動し直してもセットアップは出ない") { !$0.windows.setup && $0.settings.setupCompleted }
        XCTAssertTrue(relaunched.settings.setupCompleted)
        XCTAssertFalse(relaunched.windows.setup)
        XCTAssertFalse(isShown(AXID.Setup.window), "起動し直したら、セットアップのウィンドウが出た")
    }

    // scenario: 既定の ⌘⇧6 のままセットアップを終えると、⌘⇧6 で枠を描き始められる
    func testDefaultHotkeyWorksAfterSetup() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。撮影対象のアプリ（Sample App）が出ている。
        launch(.firstRun)
        waitForElement(AXID.Setup.window)

        // 期待される結果: セットアップに、既定のホットキーとして ⌘⇧6 が示されている。
        // （キーの文字はキーボードの配列で変わるので、修飾キーの記号と、キーが 1 つであることを見る。キーそのものはアプリの状態で見る）
        let shown = recorderText(AXID.Setup.hotkey)
        let parts = shown.split(separator: " ").map(String.init)
        XCTAssertEqual(parts.count, 3, "既定のホットキーの表示が ⌘⇧6 の形でない: \(shown)")
        XCTAssertEqual(Array(parts.prefix(2)), ["⇧", "⌘"], "既定のホットキーの表示が ⌘⇧6 の形でない: \(shown)")
        XCTAssertEqual(appState().settings.hotkey, .defaultHotkey)

        // 操作: ホットキーを変えずに、セットアップを終える。
        continueSetup()
        finishSetup()

        // 期待される結果: アプリの状態で、セットアップを終えたあと、設定のホットキーが ⌘⇧6 になっている。
        // してはいけないこと: 何も変えていないのに、ホットキーが ⌘⇧6 以外になっている。
        let finished = waitForState("セットアップ済みになる") { $0.settings.setupCompleted }
        XCTAssertEqual(finished.settings.hotkey, .defaultHotkey)
        XCTAssertEqual(finished.hotkeys.draw, .defaultHotkey)

        // 操作: ⌘⇧6 を押す。
        bringSampleToFront()
        pressHotkey(.defaultHotkey)

        // 期待される結果: アプリの状態で、⌘⇧6 を押すと枠を描く状態になる。
        // してはいけないこと: セットアップを終えても、⌘⇧6 で描き始められない。
        waitForPhase(.drawing)
        waitForElement(AXID.Draw.surface)
    }

    // scenario: セットアップで変えたホットキーで、枠を描き始められる
    func testChangedHotkeyWorksAfterSetup() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。撮影対象のアプリ（Sample App）が出ている。
        launch(.firstRun)
        waitForElement(AXID.Setup.window)

        // 操作: セットアップでホットキーを ⌃⌥K に変えて、セットアップを終える。
        recordShortcut(changedHotkey, in: AXID.Setup.hotkey)
        continueSetup()
        finishSetup()

        // 期待される結果: アプリの状態で、セットアップを終えたあと、設定のホットキーが変えた組み合わせになっている。
        // してはいけないこと: セットアップでの表示だけが変わり、アプリの状態のホットキーは ⌘⇧6 のまま。
        let finished = waitForState("セットアップ済みになる") { $0.settings.setupCompleted }
        XCTAssertEqual(finished.settings.hotkey, changedHotkey)
        XCTAssertEqual(finished.hotkeys.draw, changedHotkey)

        // 操作: ⌘⇧6 を押す。
        bringSampleToFront()
        pressHotkey(.defaultHotkey)

        // 期待される結果: アプリの状態で、⌘⇧6 を押しても何も出ていない状態のまま。
        // してはいけないこと: 変えた組み合わせと ⌘⇧6 の両方で、枠を描き始められる。
        let stayed = assertStateStays("⌘⇧6 では何も出ていない状態のまま", for: 2) { $0.phase == .hidden && !$0.isToolbarVisible }
        XCTAssertEqual(stayed.phase, .hidden)

        // 操作: 変えた組み合わせを押す。
        pressHotkey(changedHotkey)

        // 期待される結果: アプリの状態で、変えた組み合わせを押すと枠を描く状態になる。
        waitForPhase(.drawing)
        waitForElement(AXID.Draw.surface)
    }

    // scenario: 許可があるときは許可済みの表示になり、セットアップを終えられる
    func testGrantedPermissionAllowsFinishing() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。
        launch(.firstRun, screenRecording: .granted)
        waitForElement(AXID.Setup.window)

        // 操作: 許可のページへ進む。
        continueSetup()

        // 期待される結果: 許可済みであることと、セットアップを終える手段が出る。
        // してはいけないこと: 許可があるのに、許可を待っている表示のままになる。
        // してはいけないこと: セットアップを終える手段が出ない。
        waitForElement(AXID.Setup.permission)
        waitForElement(AXID.Setup.done)
        XCTAssertFalse(isShown(AXID.Setup.requestPermission), "許可があるのに、許可を出す手段（許可を待っている表示）が出ている")
        XCTAssertFalse(appState().settings.setupCompleted)

        // 操作: セットアップを終える。
        finishSetup()

        // 期待される結果: アプリの状態で、セットアップを終えるとセットアップ済みになっている。
        let finished = waitForState("セットアップ済みになる") { $0.settings.setupCompleted }
        XCTAssertTrue(finished.settings.setupCompleted)
        XCTAssertFalse(finished.windows.setup)
    }

    // scenario: セットアップを途中で閉じると、次の起動でもう一度出る
    func testClosedSetupIsShownAgainOnNextLaunch() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はあり。
        launch(.firstRun)
        waitForElement(AXID.Setup.window)

        // 操作: セットアップを終えずに閉じる。
        closeSetup()

        // 期待される結果: アプリの状態で、閉じたあともセットアップは終わっていない。
        // してはいけないこと: 閉じただけで、セットアップ済みとして扱われる。
        // してはいけないこと: 閉じたことで、akapen が終了する。
        let closed = assertStateStays("閉じたあともセットアップは終わっていない") { !$0.windows.setup && !$0.settings.setupCompleted }
        XCTAssertFalse(closed.settings.setupCompleted)
        XCTAssertTrue(isAppRunning, "セットアップを閉じたら akapen が終了した")

        // 操作: 同じ設定の置き場のまま、起動し直す。
        relaunch()

        // 期待される結果: 起動し直すと、もう一度セットアップのウィンドウが出る。
        waitForElement(AXID.Setup.window)
        let relaunched = waitForState("セットアップのウィンドウがもう一度出る") { $0.windows.setup }
        XCTAssertFalse(relaunched.settings.setupCompleted)
    }

    // scenario: 許可がないときは、許可を待っていることと、許可を出す手段が分かる表示になる
    func testMissingPermissionShowsWaitingAndHowToGrant() throws {
        // 前提: まだセットアップを終えていない（初回の起動）。画面収録の許可はなし。
        launch(.firstRun, screenRecording: .denied)
        waitForElement(AXID.Setup.window)

        // 操作: 許可のページへ進む。
        continueSetup()

        // 期待される結果: 画面収録の許可を待っていることと、システム設定の許可の画面を開く手段が出る。
        // してはいけないこと: 許可がないのに、許可済みの表示になる。
        waitForElement(AXID.Setup.permission)
        waitForElement(AXID.Setup.requestPermission)
        XCTAssertFalse(isShown(AXID.Setup.done), "許可がないのに、セットアップを終える手段（許可済みの表示）が出ている")

        // 期待される結果: アプリの状態で、セットアップは終わっていない。
        // してはいけないこと: 許可がないことが分からないまま、セットアップが閉じる。
        let waiting = assertStateStays("許可を待つページが出たまま", for: 2) { state in
            state.windows.setup && state.windows.setupPage == .permission && !state.settings.setupCompleted
        }
        XCTAssertFalse(waiting.settings.setupCompleted)
        XCTAssertFalse(isShown(AXID.Setup.done))
        XCTAssertTrue(isShown(AXID.Setup.requestPermission))
    }
}
