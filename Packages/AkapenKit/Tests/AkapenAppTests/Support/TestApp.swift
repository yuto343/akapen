import AppKit
import Foundation
import AkapenApp
import AkapenCore

/// E2E と同じ設定（一時ディレクトリ・テストごとに一意な名前のクリップボード・固定の時刻・偽の撮影）で組み立てたアプリ。
///
/// 画面は作らない。`model` に入力を順に送り、クリップボード・画像・`state.json` を確かめる。
/// 終わったら `cleanUp()` で一時ディレクトリを消し、クリップボードを手放す。
@MainActor final class TestApp {
    /// 固定する時刻（2026-11-18T05:32:10Z）。
    static let now = Date(timeIntervalSince1970: 1_794_979_930)
    static let nowText = "2026-11-18T05:32:10Z"

    /// 偽の撮影が返すウィンドウ（`LaunchSeed.defaultWindows` と同じ。SampleTarget の既定の位置と大きさ）。
    static let window = ScreenRect(x: 140, y: 64, width: 1000, height: 660)

    /// ウィンドウの中の、1 つ目の枠。
    static let firstRect = ScreenRect(x: 1008, y: 429, width: 108, height: 46)

    /// ウィンドウの中の、2 つ目の枠。
    static let secondRect = ScreenRect(x: 370, y: 230, width: 300, height: 90)

    let directory: URL
    let pasteboardName: String
    let environment: AppEnvironment

    var model: SessionModel {
        environment.model
    }

    /// 画像の置き場の根。
    var imagesDirectory: URL {
        directory.appending(path: "images", directoryHint: .isDirectory)
    }

    private init(directory: URL, pasteboardName: String, environment: AppEnvironment) {
        self.directory = directory
        self.pasteboardName = pasteboardName
        self.environment = environment
    }

    /// E2E の環境変数（`AKAPEN_SEED` を除く）。
    static func variables(directory: URL, pasteboardName: String) -> [String: String] {
        [
            "AKAPEN_E2E": "1",
            "AKAPEN_STATE_DIR": directory.path(percentEncoded: false),
            "AKAPEN_PASTEBOARD": pasteboardName,
            "AKAPEN_CAPTURE": "fixture",
            "AKAPEN_NOW": nowText,
        ]
    }

    /// 新しい一時ディレクトリで組み立てる。`prepare` は組み立ての前に、一時ディレクトリにファイルを置くのに使う。
    static func make(
        seed: LaunchSeed? = nil,
        prepare: (URL) throws -> Void = { _ in }
    ) async throws -> TestApp {
        let directory = makeDirectory()
        try prepare(directory)
        return try await make(seed: seed, directory: directory, pasteboardName: "akapen-test-" + UUID().uuidString)
    }

    /// 決まったディレクトリで組み立てる（起動し直しを確かめるとき）。
    static func make(seed: LaunchSeed?, directory: URL, pasteboardName: String) async throws -> TestApp {
        var variables = variables(directory: directory, pasteboardName: pasteboardName)
        if let seed {
            variables["AKAPEN_SEED"] = try seed.json()
        }
        let environment = try await AppEnvironment.make(LaunchConfiguration(environment: variables))
        return TestApp(directory: directory, pasteboardName: pasteboardName, environment: environment)
    }

    /// セットアップ済みの前提。
    static func setupDone(
        _ patch: LaunchSeed.SettingsPatch = LaunchSeed.SettingsPatch(),
        annotations: [LaunchSeed.Annotation] = []
    ) -> LaunchSeed {
        var settings = patch
        settings.setupCompleted = true
        return LaunchSeed(settings: settings, annotations: annotations)
    }

    /// 空の一時ディレクトリ。
    static func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "akapen-app-tests-" + UUID().uuidString, directoryHint: .isDirectory)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
        NSPasteboard(name: NSPasteboard.Name(pasteboardName)).releaseGlobally()
    }

    // MARK: - 操作

    func send(_ event: SessionEvent) async {
        await model.send(event).value
    }

    /// 枠を描ける状態にして（何も出ていなければホットキー、一覧が開いていれば閉じる）→ 枠 → コメントの確定。確定すると `drawing` に戻る。
    func annotate(_ comment: String, rect: ScreenRect) async {
        switch model.phase {
        case .hidden, .copied:
            await send(.hotkeyPressed)
        case .listOpen:
            await send(.listToggled)
        case .drawing, .commenting:
            break
        }
        await send(.dragEnded(rect: rect, screen: ScreenDescriptor(id: 1, frame: rect)))
        await send(.commentConfirmed(text: comment))
    }

    // MARK: - 検証

    /// テスト用のクリップボードの文章。
    func pasteboardText() -> String? {
        NSPasteboard(name: NSPasteboard.Name(pasteboardName)).string(forType: .string)
    }

    /// テスト用のクリップボードに文章を入れておく。
    func putOnPasteboard(_ text: String) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(pasteboardName))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// いまの回のフォルダ。
    var sessionDirectory: URL? {
        model.currentSessionID.map { imagesDirectory.appending(path: $0, directoryHint: .isDirectory) }
    }

    /// 置き場にある PNG（回のフォルダの下。名前の順）。
    func imageFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: imagesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "png" }
            .map(\.standardizedFileURL)
            .sorted { $0.path < $1.path }
    }

    /// `state.json` を辞書で読む。
    func stateJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: directory.appending(path: "state.json"))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestFailure("state.json が辞書ではない")
        }
        return object
    }

    /// `state.json` があるか。
    var hasStateFile: Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: "state.json").path(percentEncoded: false))
    }
}

/// テストの中の失敗。
struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// 回の ID（アプリと同じ決め方。この Mac のタイムゾーン）。
func sessionID(for date: Date) -> String {
    CacheLayout.sessionID(for: date, timeZone: .current)
}
