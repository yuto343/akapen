// spec: e2e/specs/settings/retention.md
// spec-sha256: 971b6784340bb6df0557e1c70635d669cd7f3d83e410d45c8257051fb6dc094d
// このファイルは生成物。直接編集しない。md を直して e2e-generator で作り直す。

import XCTest
import AkapenAXID

final class SettingsRetentionTests: AkapenUITestCase {
    // scenario: 日数を変えると、設定に入り、一覧の保存期間の案内も変わる
    func testChangingDaysUpdatesSettingsAndListNote() throws {
        // 前提: セットアップ済み。時刻は固定。画像を残す日数は既定の 7 日。確定済みの注釈が 1 件あり、akapen は何も出していない。
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.imageRetentionDays, 7)

        // 操作: 設定で、画像を残す日数を 14 日に変える。
        openSettingsFromMenuBar()
        enterRetentionDays("14")

        // 期待される結果: アプリの状態で、設定の画像を残す日数が新しい値になっている。
        // してはいけないこと: 一覧の案内だけが変わり、アプリの状態の日数は元のまま。
        let changed = waitForState("画像を残す日数が 14 日になる") { $0.settings.imageRetentionDays == 14 }
        XCTAssertEqual(changed.settings.imageRetentionDays, 14)
        closeSettings()

        // 操作: ホットキーでボタン類を出し、一覧を開く。
        bringSampleToFront()
        pressHotkey()
        waitForPhase(.drawing)
        openList()

        // 期待される結果: 一覧に出る、画像を残す期間の案内が新しい日数になる。
        // してはいけないこと: アプリの状態の日数は変わったのに、一覧の案内が元の日数のまま。
        XCTAssertEqual(listRetentionDays(), 14)
        XCTAssertEqual(appState().settings.imageRetentionDays, 14)
    }

    // scenario: 起動したとき、設定した日数より古い回の画像は消え、新しい回の画像は残る
    func testLaunchRemovesSessionsOlderThanRetention() throws {
        // 前提: セットアップ済み。時刻は固定。画像を残す日数は 3 日。
        // 画像の置き場に、固定した時刻の 5 日前の回と 1 日前の回のフォルダ（画像入り）を置いてから起動する。
        let oldFolder = placeOldSession(daysBeforeNow: 5, imageCount: 2)
        let recentFolder = placeOldSession(daysBeforeNow: 1, imageCount: 2)
        let oldName = oldFolder.lastPathComponent
        let recentName = recentFolder.lastPathComponent
        let recentImages = imageFiles().filter { $0.contains("/" + recentName + "/") }
        XCTAssertEqual(recentImages.count, 2)
        XCTAssertEqual(Set(sessionFolders()), [oldName, recentName])

        launch(.setupDone, settings: LaunchSettings(imageRetentionDays: 3))
        let state = waitForPhase(.hidden)

        // 期待される結果: 保存された画像で、画像を残す日数を 3 日にして起動すると、固定した時刻の 5 日前の回のフォルダが無くなり、1 日前の回のフォルダと画像は残っている。
        // してはいけないこと: 新しい回のフォルダまで消える。
        // してはいけないこと: 既定の 7 日で判定され、5 日前の回が残る。
        // してはいけないこと: 起動したときではなく、コピーした直後に画像が消える。（コピーせずに、起動しただけで確かめる）
        XCTAssertFalse(sessionFolders().contains(oldName), "5 日前の回のフォルダが残っている: \(sessionFolders())")
        XCTAssertFalse(fileExists(oldFolder.path(percentEncoded: false)), "5 日前の回のフォルダが残っている")
        XCTAssertTrue(sessionFolders().contains(recentName), "1 日前の回のフォルダが消えた: \(sessionFolders())")
        for path in recentImages {
            XCTAssertTrue(fileExists(path), "1 日前の回の画像が消えた: \(path)")
        }
        XCTAssertEqual(state.lastCopiedCount, 0)

        // 期待される結果: アプリの状態で、画像を残す日数は 3 日のまま。
        XCTAssertEqual(state.settings.imageRetentionDays, 3)
    }

    // scenario: 範囲の外の日数は、設定に入らない
    func testOutOfRangeDaysAreNotStored() throws {
        // 前提: セットアップ済み。時刻は固定。画像を残す日数は既定の 7 日。
        // 次の起動で画像が残るかを見るため、確定済みの注釈を 1 件入れておく（画像はいまの回のフォルダに保存される）。
        launch(.setupDone, annotations: SeedAnnotation.samples(1))
        let start = waitForPhase(.hidden)
        XCTAssertEqual(start.settings.imageRetentionDays, 7)
        let imagePath = try XCTUnwrap(start.annotations.first?.imagePath)
        let sessionDirectory = try XCTUnwrap(start.storage.sessionDirectory)
        XCTAssertTrue(fileExists(imagePath))

        openSettingsFromMenuBar()

        // 操作: 0 日を入れようとする。
        enterRetentionDays("0")
        waitForRetentionInputToSettle(enteredText: "0")

        // 期待される結果: アプリの状態で、0 日を入れようとしたあとも、画像を残す日数が 1〜365 の範囲に収まっている。
        // してはいけないこと: 0 日が設定に入り、次の起動ですべての回の画像が消える。
        let afterZero = assertStateStays("0 日を入れても範囲に収まる") { (1...365).contains($0.settings.imageRetentionDays) }
        XCTAssertNotEqual(afterZero.settings.imageRetentionDays, 0)

        // 操作: 366 日を入れようとする。
        enterRetentionDays("366")
        waitForRetentionInputToSettle(enteredText: "366")

        // 期待される結果: アプリの状態で、366 日以上を入れようとしたあとも、画像を残す日数が 1〜365 の範囲に収まっている。
        let afterLarge = assertStateStays("366 日を入れても範囲に収まる") { (1...365).contains($0.settings.imageRetentionDays) }
        XCTAssertNotEqual(afterLarge.settings.imageRetentionDays, 366)

        // 操作: 0 日をもう一度入れようとしてから、起動し直す。
        enterRetentionDays("0")
        waitForRetentionInputToSettle(enteredText: "0")
        assertStateStays("0 日を入れても範囲に収まる") { (1...365).contains($0.settings.imageRetentionDays) }
        closeSettings()
        relaunch()

        // してはいけないこと: 0 日が設定に入り、次の起動ですべての回の画像が消える。
        // してはいけないこと: 範囲の外の値が入って、設定が読めなくなる。
        let relaunched = appState()
        XCTAssertTrue((1...365).contains(relaunched.settings.imageRetentionDays))
        XCTAssertTrue(relaunched.settings.setupCompleted, "起動し直したら設定が読めず、既定値に戻った")
        XCTAssertTrue(fileExists(sessionDirectory), "起動し直したら、いまの回のフォルダが消えた")
        XCTAssertTrue(fileExists(imagePath), "起動し直したら、いまの回の画像が消えた")
    }

    // MARK: - 下請け

    /// 日数の欄の入力が確定されるまで待つ（確定すると、欄の文字が設定に入った値に置き換わる）。
    /// 確定されないまま範囲を確かめると、元の値のままでも通ってしまうため。
    private func waitForRetentionInputToSettle(enteredText: String) {
        let field = element(AXID.Settings.imageRetentionDays)
        let settled = poll(timeout: 5) {
            let shown = field.value as? String
            return shown != enteredText && shown == String(self.appState().settings.imageRetentionDays)
        }
        XCTAssertTrue(settled, "日数の入力（\(enteredText)）が確定されない: 欄は \(String(describing: field.value))")
    }
}
