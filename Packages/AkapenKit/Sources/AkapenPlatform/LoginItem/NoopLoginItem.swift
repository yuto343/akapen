import AkapenCore

/// OS に触らないログイン起動の設定。E2E と結合テスト用。
///
/// 切り替えた値はメモリにだけ持ち、画面が状態を映せるようにする。
@MainActor public final class NoopLoginItem: LoginItem {
    public private(set) var isEnabled: Bool

    /// 最初の値を渡す。既定は無効。
    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    /// 値を覚えるだけで、OS には登録しない。
    public func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}
