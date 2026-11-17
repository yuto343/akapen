/// ログイン起動の照会と切り替え。
@MainActor public protocol LoginItem {
    var isEnabled: Bool { get }

    /// ログイン時の起動設定を変更する。OS の失敗は throws。
    func setEnabled(_ enabled: Bool) throws
}
