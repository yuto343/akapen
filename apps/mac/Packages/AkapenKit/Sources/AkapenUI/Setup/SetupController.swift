import AppKit
import AkapenCore
import AkapenAXID

/// 初回のセットアップのウィンドウ（App 07・08）を出し、`SessionModel` につなぐ。
///
/// - 1 ページ目でホットキーを決める。記録したホットキーは、その場で `settingsChanged` として保存する（`DECISIONS.md` A6）。
///   受け入れるかは `canUseHotkey` に聞く（false なら元に戻して `This shortcut is unavailable` を出す。`DECISIONS.md` A8）。
/// - 2 ページ目が出ているあいだ、`pollInterval`（既定 1 秒）おきに `permission.isGranted` を確かめ、
///   取れたら状態の表示を `Granted` に、主ボタンを `Done` に変える（`DECISIONS.md` 25・A5）。
///   `Open System Settings` は `permission.request()` を呼んでから `permission.openSystemSettings()` を呼ぶ。
/// - `Done` で `model.send(.setupCompleted)` を送り、ウィンドウを閉じ、`onCompleted` を呼ぶ。
/// - 閉じるボタンで閉じたときは `setupCompleted` を送らず、`onDismissed` を呼ぶ（次の起動でもう一度出す）。
@MainActor public final class SetupController {
    /// 許可の状態を確かめる間隔の既定値。
    public static let defaultPollInterval = Duration.seconds(1)

    /// キーの記録を待ち始めた（true）・やめた（false）とき。
    ///
    /// 記録を待っている間は、組み立ての側でグローバルなホットキーの登録を外しておく
    /// （外さないと、いまのホットキーを押したときに枠を描き始めてしまい、記録欄にキーが届かない）。
    public var onRecordingChanged: (@MainActor (Bool) -> Void)?
    /// `Done` でセットアップを終えたとき（`setupCompleted` を送り、ウィンドウを閉じたあと）。
    public var onCompleted: (@MainActor () -> Void)?
    /// 終えずに閉じたとき（閉じるボタン・`⌘W`・`close()`）。`setupCompleted` は送っていない。
    public var onDismissed: (@MainActor () -> Void)?
    /// ページが変わったとき（`Continue`・`Back`・`showPermission()`）。組み立ての側は、出ているページを `state.json` に映す。
    public var onPageChanged: (@MainActor () -> Void)?

    let flow: SetupFlow
    private let host: ContentWindowHost<SetupView>
    private let settings: @MainActor () -> Settings
    private let send: @MainActor (SessionEvent) -> Void
    private let permission: any ScreenRecordingPermission
    private let pollInterval: Duration
    private var pollTask: Task<Void, Never>?
    private var isCompleting = false

    /// `model` の設定を出し、ホットキーの変更と完了を `model` に送る。
    ///
    /// - Parameters:
    ///   - permission: 画面収録の許可。`isGranted` を確かめ、`Open System Settings` で `request()` と `openSystemSettings()` を呼ぶ。
    ///   - canUseHotkey: 記録したホットキーが使えるか。既定はいつも true。
    public convenience init(
        model: SessionModel,
        permission: any ScreenRecordingPermission,
        imagesPath: String = "",
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true }
    ) {
        self.init(
            settings: { [weak model] in
                model?.settings ?? Settings()
            },
            send: { [weak model] event in
                model?.send(event)
            },
            permission: permission,
            canUseHotkey: canUseHotkey,
            shortcutText: ShortcutText(),
            pollInterval: Self.defaultPollInterval,
            activatesApp: true
        )
        flow.imagesPath = imagesPath
    }

    /// テスト用。設定の読み出しと送り先、キーの表示、許可を確かめる間隔を差し替えられる。
    /// `activatesApp` が false なら、アプリを前面に出さない。
    init(
        settings: @escaping @MainActor () -> Settings,
        send: @escaping @MainActor (SessionEvent) -> Void,
        permission: any ScreenRecordingPermission,
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool,
        shortcutText: ShortcutText,
        pollInterval: Duration,
        activatesApp: Bool,
        imagesPath: String = ""
    ) {
        self.settings = settings
        self.send = send
        self.permission = permission
        self.pollInterval = pollInterval
        flow = SetupFlow(settings: settings(), shortcutText: shortcutText)
        flow.imagesPath = imagesPath
        host = ContentWindowHost(
            content: SetupView(flow: flow),
            toolbarStyle: .unifiedCompact,
            miniaturizable: false,
            activatesApp: activatesApp
        )
        flow.hotkey.isAvailable = canUseHotkey
        connect()
    }

    /// セットアップのウィンドウ。
    var window: ContentWindow {
        host.window
    }

    /// ウィンドウが開いているか。
    public var isShown: Bool {
        host.isShown
    }

    /// ウィンドウを開いて前面に出す。閉じていたときは、1 ページ目から始め、画面の中央に置く。
    public func show() {
        if host.isShown {
            host.show(center: false)
            return
        }
        isCompleting = false
        let current = settings()
        flow.load(current, isGranted: permission.isGranted)
        window.title = UIStrings(language: current.language)[.appName]
        host.show(center: true)
    }

    /// 2 ページ目（画面収録の許可の案内）を開く。閉じていれば開いてから、開いていればそのまま 2 ページ目へ移る。
    ///
    /// 許可がないために撮影できなかったときに、組み立ての側が呼ぶ。
    public func showPermission() {
        show()
        flow.goNext()
    }

    /// 2 ページ目（画面収録の許可の案内）を出しているか。
    public var isShowingPermission: Bool {
        host.isShown && flow.page == .permission
    }

    /// 終えずに閉じる（閉じるボタンと同じ。`setupCompleted` は送らず、`onDismissed` を呼ぶ）。
    public func close() {
        window.close()
    }

    /// ほかの所（設定）で変わった設定を、開いている画面に映す（言語と、記録を待っていないときのホットキー）。
    /// 閉じているときは何もしない（開くときに読み直す）。
    public func refresh() {
        guard host.isShown else {
            return
        }
        let current = settings()
        flow.sync(current)
        window.title = UIStrings(language: current.language)[.appName]
    }

    /// 許可の状態を確かめ直して、表示に映す。
    func refreshPermission() {
        flow.setGranted(permission.isGranted)
    }

    // MARK: - 下請け

    private func connect() {
        window.setAccessibilityIdentifier(AXID.Setup.window)
        flow.onPageChange = { [weak self] page in
            switch page {
            case .hotkey:
                self?.stopPolling()
            case .permission:
                self?.startPolling()
            }
            self?.onPageChanged?()
        }
        flow.onOpenSystemSettings = { [weak self] in
            self?.openSystemSettings()
        }
        flow.onDone = { [weak self] in
            self?.complete()
        }
        flow.hotkey.onCommit = { [weak self] value in
            guard let self, let value else {
                return
            }
            var next = settings()
            next.hotkey = value
            send(.settingsChanged(next))
        }
        flow.hotkey.onRecordingChange = { [weak self] isRecording in
            self?.onRecordingChanged?(isRecording)
        }
        window.onClose = { [weak self] in
            self?.windowClosed()
        }
        window.onResignKey = { [weak self] in
            self?.flow.hotkey.cancelRecording()
        }
    }

    private func openSystemSettings() {
        _ = permission.request()
        permission.openSystemSettings()
        refreshPermission()
    }

    private func complete() {
        guard flow.isGranted else {
            return
        }
        isCompleting = true
        send(.setupCompleted)
        window.close()
        onCompleted?()
    }

    private func windowClosed() {
        stopPolling()
        flow.hotkey.cancelRecording()
        let completed = isCompleting
        isCompleting = false
        if !completed {
            onDismissed?()
        }
    }

    private func startPolling() {
        stopPolling()
        refreshPermission()
        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard let self else {
                    return
                }
                refreshPermission()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
