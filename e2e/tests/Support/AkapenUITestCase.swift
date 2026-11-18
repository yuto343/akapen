import AppKit
import XCTest
import AkapenAXID

/// すべての E2E の親。
///
/// - `setUp`: テストごとの一時ディレクトリ（設定・画像・`state.json` の置き場）と、テストごとに一意な名前のクリップボードを用意し、
///   撮影対象のアプリ（SampleTarget）を決まった位置と大きさ（`sampleFrame`。等倍）で起動する。
///   **akapen はここでは起動しない。** 各テストが `launch(...)`（`Launch.swift`）で前提を選んで起動する。
/// - `tearDown`: 失敗していれば、画面の画像・要素ツリー・`state.json`・`AKAPEN_SEED`・クリップボードの文章・置き場の画像の一覧を結果に添付する。
///   そのあと akapen と SampleTarget を終了し、一時ディレクトリを消し、クリップボードを手放す。
///
/// 要素は `AkapenAXID` の識別子で引く（`element(_:)`・`sampleElement(_:)`）。ラベルの文言や位置で探さない。
@MainActor class AkapenUITestCase: XCTestCase {
    /// SampleTarget のウィンドウの位置と大きさ（主画面の左上が原点。タイトルバーを含む。pt）。
    /// 偽の撮影が返すウィンドウも、同じ位置と大きさにする。
    static let sampleFrame = CGRect(x: 140, y: 64, width: 1000, height: 660)

    /// 偽の撮影が返すウィンドウのアプリ名（一覧のメタ情報に出る）。
    static let sampleAppName = "Sample App"

    /// 固定する時刻（`AKAPEN_NOW`）。回のフォルダ名と、古い回の掃除の判定に効く。
    static let fixedNow = "2026-11-18T05:32:10Z"

    /// akapen。
    private(set) var app: XCUIApplication!

    /// 撮影対象のアプリ（SampleTarget）。
    private(set) var sample: XCUIApplication!

    /// このテストの一時ディレクトリ（`AKAPEN_STATE_DIR`）。設定は `settings.json`、画像は `images/`、状態は `state.json`。
    private(set) var stateDirectory: URL!

    /// このテストのクリップボードの名前（`AKAPEN_PASTEBOARD`）。
    private(set) var pasteboardName: String!

    /// 最後に起動したときの `AKAPEN_SEED`（失敗したときに添付する）。
    var lastSeedJSON: String?

    /// 固定する時刻を日時にしたもの。
    static var fixedDate: Date {
        ISO8601DateFormatter().date(from: fixedNow) ?? Date(timeIntervalSince1970: 0)
    }

    /// 画像の置き場の根。
    var imagesDirectory: URL {
        stateDirectory.appending(path: "images", directoryHint: .isDirectory)
    }

    @MainActor override func setUp() async throws {
        continueAfterFailure = false
        stateDirectory = FileManager.default.temporaryDirectory
            .appending(path: "akapen-e2e-" + UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        pasteboardName = "akapen-e2e-" + UUID().uuidString
        app = XCUIApplication(bundleIdentifier: "com.yuto343.akapen")
        sample = XCUIApplication(bundleIdentifier: "com.yuto343.akapen.SampleTarget")
        let frame = Self.sampleFrame
        sample.launchEnvironment["SAMPLE_FRAME"] = "\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width)),\(Int(frame.height))"
        sample.launch()
        XCTAssertTrue(
            sample.buttons[AXID.Sample.button].waitForExistence(timeout: 10),
            "SampleTarget が起動しない"
        )
    }

    @MainActor override func tearDown() async throws {
        if let testRun, testRun.failureCount > 0 {
            attachDiagnostics()
        }
        if let app, app.state != .notRunning {
            app.terminate()
        }
        if let sample, sample.state != .notRunning {
            sample.terminate()
        }
        if let pasteboardName {
            NSPasteboard(name: NSPasteboard.Name(pasteboardName)).releaseGlobally()
        }
        if let stateDirectory {
            try? FileManager.default.removeItem(at: stateDirectory)
        }
    }

    // MARK: - 要素

    /// akapen の要素を識別子で引く（種類は問わない。同じ識別子が複数あれば最初のもの）。
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// SampleTarget の要素を識別子で引く。
    func sampleElement(_ identifier: String) -> XCUIElement {
        sample.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// akapen の要素が出るまで待つ。出なければテストを落とす。
    ///
    /// 既に出ていれば待たずに返す（`waitForExistence` は、出ていても 1 回目の確認まで約 1 秒待つため）。
    @discardableResult
    func waitForElement(_ identifier: String, timeout: TimeInterval = 5) -> XCUIElement {
        let found = element(identifier)
        if found.exists {
            return found
        }
        XCTAssertTrue(found.waitForExistence(timeout: timeout), "要素が出ない: \(identifier)")
        return found
    }

    /// akapen の要素が消えるまで待つ。消えなければテストを落とす。
    func waitForElementToDisappear(_ identifier: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        let gone = poll(timeout: timeout, interval: 0.2) {
            !target.exists
        }
        XCTAssertTrue(gone, "要素が消えない: \(identifier)")
    }

    /// akapen の要素が出ているか（待たない）。
    func isShown(_ identifier: String) -> Bool {
        element(identifier).exists
    }

    // MARK: - 待ち

    /// `check` が true を返すまで、`interval` 秒おきに確かめる。満たせば true、`timeout` 秒たっても満たさなければ false。
    ///
    /// 間は実行ループを回して待つ（`Thread.sleep` で止めない）。状態の待ちは、これを使った `waitForState(_:_:)` などで行う。
    func poll(timeout: TimeInterval, interval: TimeInterval = 0.1, _ check: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if check() {
                return true
            }
            if Date() >= deadline {
                return false
            }
            let tick = XCTestExpectation(description: "次に確かめるまで待つ")
            _ = XCTWaiter.wait(for: [tick], timeout: interval)
        }
    }

    // MARK: - 失敗したときの添付

    private func attachDiagnostics() {
        attach(XCTAttachment(screenshot: XCUIScreen.main.screenshot()), name: "screen")
        attach(XCTAttachment(string: app?.debugDescription ?? "akapen は起動していない"), name: "akapen-tree")
        attach(XCTAttachment(string: sample?.debugDescription ?? "SampleTarget は起動していない"), name: "sample-tree")
        if let stateDirectory {
            let state = (try? String(contentsOf: stateDirectory.appending(path: "state.json"), encoding: .utf8)) ?? "state.json がない"
            attach(XCTAttachment(string: state), name: "state.json")
            if let error = try? String(contentsOf: stateDirectory.appending(path: "startup-error.txt"), encoding: .utf8) {
                attach(XCTAttachment(string: error), name: "startup-error.txt")
            }
            let images = imageFiles().joined(separator: "\n")
            attach(XCTAttachment(string: images.isEmpty ? "画像なし" : images), name: "images")
        }
        attach(XCTAttachment(string: lastSeedJSON ?? "AKAPEN_SEED なし"), name: "AKAPEN_SEED")
        attach(XCTAttachment(string: pasteboardText() ?? "クリップボードは空"), name: "pasteboard")
    }

    private func attach(_ attachment: XCTAttachment, name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
