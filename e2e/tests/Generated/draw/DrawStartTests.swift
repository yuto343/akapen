// spec: e2e/specs/draw/start.md
// spec-sha256: 2946e047b5f21beb2212e61872be3bd6bc3c782ac6a6ce0b7c086e08a4cc4332
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
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Toolbar.list)
        waitForElement(AXID.Toolbar.copyPrompt)
        waitForElement(AXID.Draw.surface)

        // してはいけないこと: ボタン類だけが出て、枠を描く状態にならない。
        XCTAssertNotEqual(state.phase, .idle)
        // してはいけないこと: 枠を描く状態にはなったのに、ボタン類が出ていない。（上の isToolbarVisible で確かめた）
        // してはいけないこと: まだ何も描いていないのに、注釈や書きかけの注釈ができている。
        XCTAssertNil(state.draft)
        XCTAssertTrue(imageFiles().isEmpty)
    }

    // scenario: 注釈が残っているときにホットキーを押すと、注釈を保ったまま次の枠を描き始められる
    func testHotkeyWithAnnotationsKeepsThem() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.idle)
        XCTAssertTrue(before.isToolbarVisible)
        XCTAssertEqual(before.annotations.count, 2)

        // 操作: ホットキーを押す。
        pressHotkey()

        // 期待される結果: ボタン類は出たままで、マウスが枠を描く操作になる。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Draw.surface)

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        XCTAssertEqual(state.annotations, before.annotations)
        XCTAssertEqual(state.comments, before.comments)

        // 期待される結果: 保存された画像で、2 件の注釈の画像が残っている。
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }

        // してはいけないこと: 新しい回が始まり、それまでの注釈が消える。
        XCTAssertEqual(state.storage.sessionDirectory, before.storage.sessionDirectory)
        XCTAssertNil(state.draft)
        // してはいけないこと: それまでの注釈の画像ファイルが消える。（上で確かめた）
    }

    // scenario: 注釈が残っているときに、ボタン類から次の枠を描き始められる
    func testAddButtonWithAnnotationsStartsDrawing() throws {
        // 前提: 確定済みの注釈が 2 件あり、ボタン類だけが出ている。
        launch(.setupDone, annotations: SeedAnnotation.samples(2))
        let before = waitForPhase(.idle)
        XCTAssertTrue(before.isToolbarVisible)
        let submitCountBefore = sampleSubmitCount()
        let fieldTextsBefore = [AXID.Sample.firstField, AXID.Sample.secondField, AXID.Sample.thirdField].map(sampleText)

        // 操作: ボタン類から次の枠を始める。
        tapAdd()

        // 期待される結果: ボタン類は出たままで、マウスが枠を描く操作になる。
        let state = waitForPhase(.drawing)
        XCTAssertTrue(state.isToolbarVisible)
        waitForElement(AXID.Toolbar.add)
        waitForElement(AXID.Draw.surface)

        // 期待される結果: アプリの状態で、枠を描く状態になっており、注釈は 2 件のまま（順番とコメントも変わらない）。
        XCTAssertEqual(state.annotations, before.annotations)

        // してはいけないこと: ボタン類から始めたときだけ、それまでの注釈が消える。
        XCTAssertEqual(state.storage.sessionDirectory, before.storage.sessionDirectory)
        for path in before.imagePaths {
            XCTAssertTrue(fileExists(path), "注釈の画像が消えた: \(path)")
        }

        // してはいけないこと: ボタン類を押したクリックが下のアプリに届き、撮影対象のアプリが操作される。
        XCTAssertEqual(sampleSubmitCount(), submitCountBefore)
        XCTAssertEqual([AXID.Sample.firstField, AXID.Sample.secondField, AXID.Sample.thirdField].map(sampleText), fieldTextsBefore)
    }
}
