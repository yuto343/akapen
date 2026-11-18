import AppKit
import AkapenCore
import AkapenPlatform
import AkapenUI

/// 依存一式（`AppEnvironment`）に画面をつなぐ。メニューバー・メインメニュー・画面の上に浮く部品・設定・セットアップ・終了の確認。
///
/// 状態の遷移は判断しない。画面の操作は `SessionEvent` にして `model` に送り、`model` の状態を画面に映すだけにする。
/// ここで決めるのは、アプリとしての振る舞い（終了の確認を出すか、ホットキーの登録、許可がないときにセットアップを出すか）だけ。
@MainActor final class AppController {
    private let environment: AppEnvironment
    private let windows: SessionWindows
    private let menuBar: MenuBarController
    private let mainMenu: MainMenuController
    private let quitConfirm: QuitConfirmController
    private let settingsWindow: SettingsController
    private let setupWindow: SetupController
    /// 終了の確認で「終了」が選ばれたか。次の終了の要求は確認なしで通す。
    private var isQuitApproved = false
    /// 前に映した失敗。失敗が新しく起きたときだけ反応するために持つ。
    private var previousFailure: SessionFailure?

    private var model: SessionModel {
        environment.model
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        let model = environment.model
        let hotkeys = environment.hotkeys
        windows = SessionWindows(model: model)
        menuBar = MenuBarController(model: model)
        mainMenu = MainMenuController(language: model.settings.language)
        quitConfirm = QuitConfirmController(model: model)
        settingsWindow = SettingsController(
            model: model,
            canUseHotkey: { [weak hotkeys] shortcut in
                hotkeys?.canUse(shortcut, for: .draw) ?? false
            }
        )
        setupWindow = SetupController(
            model: model,
            permission: environment.permission,
            canUseHotkey: { [weak hotkeys] shortcut in
                hotkeys?.canUse(shortcut, for: .draw) ?? false
            }
        )
    }

    /// 画面をつなぎ、ホットキーを登録し、いまの状態を映す。セットアップが済んでいなければセットアップを出す。
    /// 最後に `state.json` の書き出しを始める（書き出しが始まった時点で、起動が済んでいる）。
    func start() {
        // アクティブでないままでも、枠を描く面の十字やボタンの指のカーソルが効くようにする（効かなくても続ける）。
        BackgroundCursor.enable()
        connect()
        mainMenu.install()
        environment.hotkeys.apply(model.settings)
        previousFailure = model.lastFailure
        windows.render()
        if !model.settings.setupCompleted {
            setupWindow.show()
        }
        environment.windowStatus = { [weak self] in
            self?.windowStatus ?? .none
        }
        environment.startWritingState()
    }

    /// 終了してよいか（`applicationShouldTerminate`）。メニュー・`⌘Q`・システムからの終了の要求のどれもここを通る。
    ///
    /// 確定済みの注釈か書きかけの注釈があれば、終了の確認を出して、いまは終了しない（`DECISIONS.md` A4）。
    func shouldTerminate() -> Bool {
        if isQuitApproved {
            return true
        }
        let count = QuitPolicy.pendingCount(model)
        guard count > 0 else {
            return true
        }
        quitConfirm.show(annotationCount: count)
        environment.writeState()
        return false
    }

    /// 終了する直前の後始末。ホットキーの登録を外し、画面を片付ける。画像ファイルは消さない（`DECISIONS.md` A3）。
    func willTerminate() {
        environment.hotkeys.unregisterAll()
        quitConfirm.hide()
        windows.hide()
    }

    // MARK: - つなぎ

    private func connect() {
        environment.onModelChange = { [weak self] in
            self?.modelChanged()
        }
        environment.hotkeys.onRegistrationFailed = { [weak self] slot, _, restored in
            self?.registrationFailed(slot, restored: restored)
        }
        menuBar.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        menuBar.onQuitRequested = {
            NSApp.terminate(nil)
        }
        mainMenu.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        mainMenu.onQuitRequested = {
            NSApp.terminate(nil)
        }
        quitConfirm.onResult = { [weak self] result in
            self?.quitAnswered(result)
        }
        settingsWindow.onRecordingChanged = { [weak self] isRecording in
            self?.recordingChanged(isRecording, by: .settings)
        }
        settingsWindow.onClosed = { [weak self] in
            self?.environment.writeState()
        }
        setupWindow.onRecordingChanged = { [weak self] isRecording in
            self?.recordingChanged(isRecording, by: .setup)
        }
        setupWindow.onCompleted = { [weak self] in
            self?.setupCompleted()
        }
        setupWindow.onDismissed = { [weak self] in
            self?.environment.writeState()
        }
        setupWindow.onPageChanged = { [weak self] in
            self?.environment.writeState()
        }
    }

    /// `model` の状態が変わったとき。ホットキーの登録を設定に合わせ、画面に映す（`state.json` はこのあとに書き出される）。
    private func modelChanged() {
        environment.hotkeys.apply(model.settings)
        handleNewFailure()
        windows.render()
        settingsWindow.refresh()
        setupWindow.refresh()
        mainMenu.setLanguage(model.settings.language)
    }

    /// 画面収録の許可がないために撮影できなかったら、セットアップの 2 ページ目（許可の案内）を開く。
    ///
    /// 枠を描く面は画面全体を覆ってほかのウィンドウより手前に出るので、浮く部品を下げる入力を送る。
    /// そのあとの状態は `SessionModel` が決める（注釈は残る）。
    private func handleNewFailure() {
        let failure = model.lastFailure
        defer {
            previousFailure = failure
        }
        guard failure == .captureFailed,
              previousFailure != .captureFailed,
              model.phase == .drawing,
              !environment.permission.isGranted else {
            return
        }
        setupWindow.showPermission()
        Task { @MainActor [weak self] in
            self?.model.send(.dismissRequested)
        }
    }

    /// 設定を開く。ボタン類が出ていれば、画面全体を覆う面が設定のウィンドウを隠さないように、先に浮く部品を下げる。
    private func openSettings() {
        model.send(.dismissRequested)
        settingsWindow.show()
        environment.writeState()
    }

    private func recordingChanged(_ isRecording: Bool, by reason: HotkeyCoordinator.SuspendReason) {
        environment.hotkeys.setSuspended(isRecording, by: reason)
        if !isRecording {
            environment.hotkeys.apply(model.settings)
        }
        environment.writeState()
    }

    /// 登録できなかったキーの代わりに、前のキーを登録し直したときは、設定もそのキーに戻す（`DECISIONS.md` A8）。
    private func registrationFailed(_ slot: HotkeyCoordinator.Slot, restored: KeyboardShortcut?) {
        guard let restored else {
            environment.writeState()
            return
        }
        var settings = model.settings
        switch slot {
        case .draw:
            settings.hotkey = restored
        }
        Task { @MainActor [weak self] in
            self?.model.send(.settingsChanged(settings))
        }
    }

    /// セットアップを終えたら、ログイン時に起動するようにする。失敗しても動き続ける（E2E では何もしない実装）。
    private func setupCompleted() {
        do {
            try environment.loginItem.setEnabled(true)
        } catch {
            NSLog("akapen: ログイン時の起動を有効にできなかった: %@", String(describing: error))
        }
        environment.writeState()
    }

    private func quitAnswered(_ result: QuitConfirmResult) {
        switch result {
        case .quit:
            isQuitApproved = true
            NSApp.terminate(nil)
        case .cancel:
            windows.restoreFocus()
            environment.writeState()
        }
    }

    private var windowStatus: SessionSnapshot.Windows {
        let setupPage: SessionSnapshot.Windows.SetupPage?
        if setupWindow.isShown {
            setupPage = setupWindow.isShowingPermission ? .permission : .hotkey
        } else {
            setupPage = nil
        }
        return SessionSnapshot.Windows(
            settings: settingsWindow.isShown,
            setup: setupWindow.isShown,
            setupPage: setupPage,
            quitConfirm: quitConfirm.isShown
        )
    }
}

