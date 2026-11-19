import AkapenCore

/// 決まった許可状態を返す、E2E と結合テスト用の実装。OS には問い合わせない。
@MainActor public final class FixedScreenRecordingPermission: ScreenRecordingPermission {
    /// 許可されているか。テストから書き換えて、許可の有無を切り替えられる。
    public var isGranted: Bool

    /// 許可の有無を固定して作る。
    public init(isGranted: Bool) {
        self.isGranted = isGranted
    }

    /// OS に許可を求めず、いまの値をそのまま返す。
    public func request() -> Bool {
        isGranted
    }

    /// 何もしない。
    public func openSystemSettings() {}
}
