// spec: e2e/specs/draw/start.md
// spec-sha256: 603d1b20bf3d59a0c93af78ebe11998e8eba30056d88aa300ce93f5c170ea4de
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class DrawStartTests: AkapenUITestCase {
    // scenario: 何も出ていないときにホットキーを押すと、ボタン類が出て枠を描き始められる
    func testHotkeyFromHiddenStartsDrawing() throws {
        // 前提: セットアップ済み（ホットキーは既定の ⌘;）。注釈は 0 件で、akapen は何も出していない。
        launch(.setupDone)
        let before = appState()
        XCTAssertEqual(before.phase, .hidden)
        XCTAssertFalse(before.isToolbarVisible)
        XCTAssertEqual(before.hotkeys.draw, .commandSemicolon)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: 画面にボタン類が出て、マウスが枠を描く操作になる。
        // 期待される結果: アプリの状態で、枠を描く状態になっており、ボタン類が出ていて、注釈は 0 件。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        XCTAssertTrue(state.annotations.isEmpty)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Toolbar.copyPrompt)
        waitForElement(AXID.Draw.surface)

        // してはいけないこと: ボタン類だけが出て、枠を描く状態にならない。（phase が drawing で確かめた）
        XCTAssertEqual(state.phase, .drawing)
        // してはいけないこと: 枠を描く状態にはなったのに、ボタン類が出ていない。（上の isToolbarVisible で確かめた）
        // してはいけないこと: まだ何も描いていないのに、注釈や書きかけの注釈ができている。
        XCTAssertNil(state.draft)
        XCTAssertTrue(imageFiles().isEmpty)
    }

    // scenario: 注釈が残っているときにホットキーを押すと、注釈を保ったまま次の枠を描き始められる
    func testHotkeyWithAnnotationsKeepsThem() throws {
        // 前提: 前の操作で確定した注釈が 2 件残っていて、akapen は何も出していない。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.hidden)
        XCTAssertFalse(before.isToolbarVisible)
        XCTAssertEqual(before.annotations.count, 2)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: 画面にボタン類が出て、マウスが枠を描く操作になる。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Draw.surface)

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）、この回のフォルダは注釈の画像があるフォルダのまま。
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertEqual(state.comments, before.comments)
        let sessionDirectory = try XCTUnwrap(state.storage.sessionDirectory)
        XCTAssertEqual(sessionDirectory, before.storage.sessionDirectory)
        for path in before.imagePaths {
            XCTAssertTrue(path.hasPrefix(sessionDirectory), "注釈の画像がこの回のフォルダにない: \(path)")
        }

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }

        // してはいけないこと: 新しい回が始まり、それまでの注釈が消える。（上の注釈とフォルダで確かめた）
        XCTAssertNil(state.draft)
        // してはいけないこと: それまでの注釈の画像ファイルが消える。（上で確かめた）
    }
}
