import Foundation

/// 環境変数を副作用なしで解釈する。未知の capture は fixture、無効な日付は nil。
public struct LaunchConfiguration: Sendable {
    public enum Capture: String, Sendable {
        case fixture
        case live
    }

    public let isE2E: Bool
    public let stateDirectory: URL?
    public let pasteboardName: String?
    public let capture: Capture
    public let seedJSON: String?
    public let now: Date?

    /// 辞書以外のプロセス状態には触れない。seed は後続担当がスキーマを定義する。
    public init(environment: [String: String]) {
        isE2E = environment["AKAPEN_E2E"] == "1"
        stateDirectory = environment["AKAPEN_STATE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        pasteboardName = environment["AKAPEN_PASTEBOARD"]
        capture = environment["AKAPEN_CAPTURE"].flatMap(Capture.init(rawValue:)) ?? .fixture
        seedJSON = environment["AKAPEN_SEED"]
        now = environment["AKAPEN_NOW"].flatMap { ISO8601DateFormatter().date(from: $0) }
    }
}
