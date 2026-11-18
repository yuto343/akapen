// spec: e2e/specs/settings/hotkey.md
// spec-sha256: 037ae4206731c878f64d7caabfddc237b65dcafa9c66fc73388ce0be9e54453d
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SettingsHotkeyTests: AkapenUITestCase {
    /// 新しく割り当てるホットキー（⌃⌥K）。
    private let newHotkey = Shortcut(key: "k", modifiers: [.control, .option])

    // scenario: ホットキーを変えると、新しい組み合わせで枠を描き始められる
    func testNewHotkeyStartsDrawing() throws {
        // 前提: セットアップ済み、ホットキーは既定の ⌘;。撮影対象のアプリ（Sample App）が出ている。注釈は 0 件で、何も出ていない。
        launch(.setupDone)
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.hotkey, .commandSemicolon)
        XCTAssertTrue(start.annotations.isEmpty)
        let before = recorderTextAfterOpeningSettings()

        // 操作: 設定でホットキーを ⌃⌥K に変える。
        recordShortcut(newHotkey, in: AXID.Settings.hotkey)

        // 期待される結果: 設定に新しい組み合わせが出る。
        let shown = recorderText(AXID.Settings.hotkey)
        XCTAssertNotEqual(shown, before, "設定の表示が元の組み合わせのまま")
        XCTAssertEqual(modifierSymbols(shown), ["⌃", "⌥"], "設定に新しい組み合わせが出ていない: \(shown)")

        // 期待される結果: アプリの状態で、設定のホットキーが新しい組み合わせになっている。
        // してはいけないこと: 設定の表示だけが変わり、アプリの状態のホットキーは元のまま。
        let changed = waitForState("ホットキーが ⌃⌥K になる") { $0.settings.hotkey == self.newHotkey }
        XCTAssertEqual(changed.settings.hotkey, newHotkey)
        XCTAssertEqual(changed.hotkeys.draw, newHotkey)

        // 操作: 設定のウィンドウを閉じ、新しい組み合わせを押す。
        closeSettings()
        bringSampleToFront()
        pressHotkey(newHotkey)

        // 期待される結果: アプリの状態で、設定のウィンドウを閉じたあと、新しい組み合わせを押すと枠を描く状態になる。
        // してはいけないこと: 新しい組み合わせが、アプリを起動し直すまで効かない。（起動し直さずに押す）
        let drawing = waitForPhase(.drawing)
        XCTAssertFalse(drawing.windows.settings)
        waitForElement(AXID.Draw.surface)
    }

    // scenario: ホットキーを変えたあとは、元の組み合わせでは描き始めない
    func testOldHotkeyNoLongerStartsDrawing() throws {
        // 前提: セットアップ済み、ホットキーは既定の ⌘;。撮影対象のアプリ（Sample App）が出ている。注釈は 0 件で、何も出ていない。
        launch(.setupDone)
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.hotkey, .commandSemicolon)

        // 操作: 設定でホットキーを ⌃⌥K に変えて、設定のウィンドウを閉じる。
        openSettingsFromMenuBar()
        recordShortcut(newHotkey, in: AXID.Settings.hotkey)
        waitForState("ホットキーが ⌃⌥K になる") { $0.settings.hotkey == self.newHotkey && $0.hotkeys.draw == self.newHotkey }
        closeSettings()
        bringSampleToFront()

        // 操作: 元の ⌘; を押す。
        pressHotkey(.commandSemicolon)

        // 期待される結果: アプリの状態で、元の ⌘; を押しても、何も出ていない状態のまま。
        // してはいけないこと: 元の組み合わせと新しい組み合わせの両方で、枠を描き始められる。
        let stayed = assertStateStays("元の ⌘; では何も出ていない状態のまま", for: 2) { $0.phase == .hidden && !$0.isToolbarVisible }
        XCTAssertEqual(stayed.phase, .hidden)
        XCTAssertNotEqual(stayed.hotkeys.draw, .commandSemicolon)
        XCTAssertFalse(isShown(AXID.Draw.surface))
    }

    // MARK: - 下請け

    /// 設定をメニューバーから開き、ホットキーの記録欄の表示を返す。
    private func recorderTextAfterOpeningSettings() -> String {
        openSettingsFromMenuBar()
        return recorderText(AXID.Settings.hotkey)
    }

    /// 記録欄の表示（`⌃ ⌥ K` の形）のうち、修飾キーの記号。キーの文字は配列で変わるので見ない。
    private func modifierSymbols(_ text: String) -> [String] {
        let modifiers: Set<String> = ["⌃", "⌥", "⇧", "⌘"]
        return text.split(separator: " ").map(String.init).filter { modifiers.contains($0) }
    }
}
