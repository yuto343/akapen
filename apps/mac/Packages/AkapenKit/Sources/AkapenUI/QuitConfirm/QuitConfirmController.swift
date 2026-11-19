import AkapenCore

/// 終了の確認の答え。
public enum QuitConfirmResult: Equatable, Sendable {
    /// 終了する（`Quit` か `Return`）。
    case quit
    /// 取りやめる（`Cancel` か `Esc`）。
    case cancel
}

/// 終了確認の互換窓口。パネルとキー処理は全削除の確認と共用する。
@MainActor public final class QuitConfirmController {
    /// パネルを隠してから答えを伝える。
    public var onResult: (@MainActor (QuitConfirmResult) -> Void)?
    private let confirmation: ConfirmationController

    var panel: FloatingPanel {
        confirmation.panel
    }

    var hostingView: FirstMouseHostingView<QuitConfirmOverlay> {
        confirmation.hostingView
    }

    var annotationCount: Int {
        confirmation.annotationCount
    }

    var screen: ScreenInfo? {
        confirmation.screen
    }


    /// 設定の言語で終了の確認を作る。
    public convenience init(model: SessionModel) {
        self.init(confirmation: ConfirmationController(model: model, purpose: .quit))
    }

    init(language: @escaping @MainActor () -> Language, screens: any ScreenProviding, fadeDuration: Double) {
        confirmation = ConfirmationController(purpose: .quit, language: language, screens: screens, fadeDuration: fadeDuration)
        connect()
    }

    private init(confirmation: ConfirmationController) {
        self.confirmation = confirmation
        connect()
    }

    private func connect() {
        confirmation.onResult = { [weak self] result in
            self?.onResult?(result == .confirm ? .quit : .cancel)
        }
    }

    /// 確認が出ているか。
    public var isShown: Bool {
        confirmation.isShown
    }


    /// 件数を映して確認を出す。
    public func show(annotationCount: Int) {
        confirmation.show(annotationCount: annotationCount)
    }

    /// 答えを待たずに隠す。
    public func hide() {
        confirmation.hide()
    }
}
