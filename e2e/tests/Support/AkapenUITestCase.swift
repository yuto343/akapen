import XCTest
import AkapenAXID

@MainActor class AkapenUITestCase: XCTestCase {
    var app: XCUIApplication!
    var sample: XCUIApplication!
    var directory: URL!
    @MainActor override func setUp() async throws {
        try setUpApplications()
    }
    private func setUpApplications() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("akapen-e2e-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sample = XCUIApplication(bundleIdentifier: "com.yuto343.akapen.SampleTarget")
        sample.launchEnvironment["SAMPLE_FRAME"] = "160,180,500,320"
        sample.launch()
        app = XCUIApplication(bundleIdentifier: "com.yuto343.akapen")
        app.launchEnvironment = ["AKAPEN_E2E":"1", "AKAPEN_STATE_DIR":directory.path, "AKAPEN_PASTEBOARD":UUID().uuidString, "AKAPEN_CAPTURE":ProcessInfo.processInfo.environment["AKAPEN_CAPTURE"] ?? "fixture"]
        app.launch(); sample.activate()
        XCTAssertTrue(sample.buttons[AXID.Sample.button].waitForExistence(timeout: 5))
    }
    @MainActor override func tearDown() async throws {
        try tearDownApplications()
    }
    private func tearDownApplications() throws {
        if let testRun, testRun.failureCount > 0 {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screenshot.lifetime = .keepAlways; add(screenshot)
            let tree = XCTAttachment(string: app?.debugDescription ?? "No app"); tree.lifetime = .keepAlways; add(tree)
        }
        app?.terminate(); sample?.terminate()
        if let directory { try FileManager.default.removeItem(at: directory) }
    }
    func startDrawing() {
        // 実際の Carbon 経路を使う。akapen は前面にしない。
        sample.typeKey(";", modifierFlags: .command)
        XCTAssertTrue(app.buttons[AXID.Toolbar.add].waitForExistence(timeout: 5))
    }
    func appState() throws -> [String: Any] {
        let data = try Data(contentsOf: directory.appendingPathComponent("state.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    func waitForPhase(_ phase: String) {
        let predicate = NSPredicate { [self] _, _ in (try? appState()["phase"] as? String) == phase }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
