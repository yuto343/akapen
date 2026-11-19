import Foundation

/// 起動時の環境変数を、副作用なしで値にする。
///
/// 読むのは `AKAPEN_E2E`・`AKAPEN_STATE_DIR`・`AKAPEN_PASTEBOARD`・`AKAPEN_CAPTURE`・`AKAPEN_SEED`・`AKAPEN_NOW` だけ。
/// どの実装を使うかは `AppEnvironment` が決める。
/// `AKAPEN_E2E=1` でないとき（本番）は、ほかの変数をすべて無視する。
///
/// 読むのは Debug の構成（`make run`・`make e2e`・`swift test`）だけ。Release の構成（配布するビルド）では
/// 環境変数をひとつも見ず、`AKAPEN_E2E=1` を付けて起動しても本番として動く（`readsTestVariables`）。
public struct LaunchConfiguration: Sendable, Equatable {
    /// 撮影の実装。
    public enum Capture: String, Sendable {
        /// 偽の撮影（`FixtureCapturer`）。E2E の既定。
        case fixture
        /// 実際の画面収録（`ScreenCaptureKitCapturer`）。`make e2e-live` で使う。
        case live
    }

    /// E2E の起動で、環境変数が足りない・読めないとき。`AppEnvironment.make` が起動エラーにする。
    public enum Problem: Error, Equatable, Sendable {
        /// `AKAPEN_E2E` が `1` でも `0` でもない。ユーザーの設定に触らないように、E2E として扱ったうえで起動エラーにする。
        case invalidE2EFlag(String)
        /// `AKAPEN_STATE_DIR` がない、または空。
        case missingStateDirectory
        /// `AKAPEN_STATE_DIR` が絶対パスでない。
        case relativeStateDirectory(String)
        /// `AKAPEN_PASTEBOARD` がない、または空。一般のクリップボードには落とさない。
        case missingPasteboardName
        /// `AKAPEN_CAPTURE` が `fixture` でも `live` でもない。
        case invalidCapture(String)
        /// `AKAPEN_NOW` が ISO 8601 の日時として読めない。
        case invalidNow(String)
    }

    /// E2E 用の依存に切り替えるか（`AKAPEN_E2E=1`）。
    public let isE2E: Bool
    /// 設定・画像・`state.json` の置き場（`AKAPEN_STATE_DIR`）。E2E のときだけ読む。
    public let stateDirectory: URL?
    /// 名前つきのクリップボードの名前（`AKAPEN_PASTEBOARD`）。E2E のときだけ読む。
    public let pasteboardName: String?
    /// 撮影の実装（`AKAPEN_CAPTURE`）。既定は `fixture`。E2E のときだけ読む。
    public let capture: Capture
    /// 起動時の前提の JSON（`AKAPEN_SEED`）。形は `LaunchSeed`。E2E のときだけ読む。
    public let seedJSON: String?
    /// 固定する時刻（`AKAPEN_NOW`）。E2E のときだけ読む。
    public let now: Date?
    /// 足りない・読めない値。E2E のときだけ数える（本番では空）。
    public let problems: [Problem]

    /// このビルドが `AKAPEN_*` を読むか。Debug の構成では true、Release の構成では false。
    public static let readsTestVariables: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    /// 環境変数の辞書から作る。辞書のほかのプロセスの状態には触れない。
    ///
    /// Release の構成では辞書を読まず、本番の設定にする。
    public init(environment: [String: String]) {
        self.init(environment: environment, readsTestVariables: Self.readsTestVariables)
    }

    /// `readsTestVariables` が false なら、辞書をひとつも読まずに本番の設定にする（Release の構成と同じ）。
    init(environment: [String: String], readsTestVariables: Bool) {
        guard readsTestVariables else {
            self.init(testVariables: [:])
            return
        }
        self.init(testVariables: environment)
    }

    /// 辞書の `AKAPEN_*` を読んで値にする。読んでよいかは呼び出す側（`init(environment:readsTestVariables:)`）が決める。
    private init(testVariables environment: [String: String]) {
        var problems: [Problem] = []
        switch environment["AKAPEN_E2E"] {
        case nil, "0":
            isE2E = false
        case "1":
            isE2E = true
        case let .some(other):
            isE2E = true
            problems.append(.invalidE2EFlag(other))
        }
        guard isE2E else {
            stateDirectory = nil
            pasteboardName = nil
            capture = .fixture
            seedJSON = nil
            now = nil
            self.problems = []
            return
        }
        let directory = environment["AKAPEN_STATE_DIR"] ?? ""
        if directory.isEmpty {
            problems.append(.missingStateDirectory)
            stateDirectory = nil
        } else if !directory.hasPrefix("/") {
            problems.append(.relativeStateDirectory(directory))
            stateDirectory = nil
        } else {
            stateDirectory = URL(filePath: directory, directoryHint: .isDirectory)
        }
        let name = environment["AKAPEN_PASTEBOARD"] ?? ""
        if name.isEmpty {
            problems.append(.missingPasteboardName)
            pasteboardName = nil
        } else {
            pasteboardName = name
        }
        if let text = environment["AKAPEN_CAPTURE"], !text.isEmpty {
            if let value = Capture(rawValue: text) {
                capture = value
            } else {
                problems.append(.invalidCapture(text))
                capture = .fixture
            }
        } else {
            capture = .fixture
        }
        seedJSON = environment["AKAPEN_SEED"].flatMap { $0.isEmpty ? nil : $0 }
        if let text = environment["AKAPEN_NOW"], !text.isEmpty {
            now = Self.parseDate(text)
            if now == nil {
                problems.append(.invalidNow(text))
            }
        } else {
            now = nil
        }
        self.problems = problems
    }

    /// ISO 8601 の日時（`2026-11-18T05:32:10Z`。小数の秒があってもよい）。
    static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) {
            return date
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}
