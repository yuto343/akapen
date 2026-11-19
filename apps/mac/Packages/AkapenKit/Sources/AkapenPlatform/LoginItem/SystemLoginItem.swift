import ServiceManagement
import AkapenCore

/// ログイン時にアプリ自身を起動する設定。`SMAppService.mainApp` を包む。
@MainActor public final class SystemLoginItem: LoginItem {
    public init() {}

    /// 登録済みで、ユーザーの承認も済んでいるときだけ true。
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 登録・解除する。すでにその状態なら何もしない。OS の失敗はそのまま投げる。
    public func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else {
                return
            }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else {
                return
            }
            try service.unregister()
        }
    }
}
