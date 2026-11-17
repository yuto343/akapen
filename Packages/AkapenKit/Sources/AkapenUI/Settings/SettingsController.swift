import AppKit
import AkapenCore
import AkapenAXID

/// 設定のウィンドウ（App 06）を出し、変更を `SessionModel` に送る。
///
/// - `show()` で開く。開くと前面に出てキー入力を受け取る。既に開いていれば前面に出すだけ。
/// - 変更は、その場で `model.send(.settingsChanged(新しい設定))` として送る（保存ボタンはない）。
/// - 記録したキーを受け入れるかは、`canUseHotkey` / `canUseToolbarShortcut` に聞く。
///   組み立ての側が、そのキーを実際に登録できるかを確かめて返す（判定の中で登録し直してもよい）。
///   false なら元の値に戻し、`This shortcut is unavailable` を出す（`DECISIONS.md` A8）。
/// - 2 つの欄に同じキーは割り当てられない（判定に聞く前に断る）。
@MainActor public final class SettingsController {
    /// キーの記録を待ち始めた（true）・やめた（false）とき。
    ///
    /// 記録を待っている間は、組み立ての側でグローバルなホットキーの登録を外しておく
    /// （外さないと、いまのホットキーを押したときに枠を描き始めてしまい、記録欄にキーが届かない）。
    public var onRecordingChanged: (@MainActor (Bool) -> Void)?
    /// ウィンドウが閉じられたとき（閉じるボタン・`⌘W`・`close()` のどれでも）。
    public var onClosed: (@MainActor () -> Void)?

    let form: SettingsForm
    private let host: ContentWindowHost<SettingsView>
    private let settings: @MainActor () -> Settings
    private let send: @MainActor (SessionEvent) -> Void

    /// `model` の設定を出し、変更を `model` に送る。
    ///
    /// - Parameters:
    ///   - canUseHotkey: 記録したホットキーが使えるか。既定はいつも true。
    ///   - canUseToolbarShortcut: 記録したボタン類の表示切り替えのキーが使えるか。既定はいつも true。
    public convenience init(
        model: SessionModel,
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true },
        canUseToolbarShortcut: @escaping @MainActor (KeyboardShortcut) -> Bool = { _ in true }
    ) {
        self.init(
            settings: { [weak model] in
                model?.settings ?? Settings()
            },
            send: { [weak model] event in
                model?.send(event)
            },
            canUseHotkey: canUseHotkey,
            canUseToolbarShortcut: canUseToolbarShortcut,
            shortcutText: ShortcutText(),
            activatesApp: true
        )
    }

    /// テスト用。設定の読み出しと送り先、キーの表示を差し替えられる。`activatesApp` が false なら、アプリを前面に出さない。
    init(
        settings: @escaping @MainActor () -> Settings,
        send: @escaping @MainActor (SessionEvent) -> Void,
        canUseHotkey: @escaping @MainActor (KeyboardShortcut) -> Bool,
        canUseToolbarShortcut: @escaping @MainActor (KeyboardShortcut) -> Bool,
        shortcutText: ShortcutText,
        activatesApp: Bool
    ) {
        self.settings = settings
        self.send = send
        form = SettingsForm(settings: settings(), shortcutText: shortcutText)
        host = ContentWindowHost(
            content: SettingsView(form: form),
            toolbarStyle: .unified,
            miniaturizable: true,
            activatesApp: activatesApp
        )
        form.base = settings
        form.hotkey.isAvailable = canUseHotkey
        form.toolbarShortcut.isAvailable = canUseToolbarShortcut
        form.onChange = { [weak self] newSettings in
            self?.send(.settingsChanged(newSettings))
            self?.updateTitle()
        }
        form.onRecordingChange = { [weak self] isRecording in
            self?.onRecordingChanged?(isRecording)
        }
        window.setAccessibilityIdentifier(AXID.Settings.window)
        window.onClose = { [weak self] in
            self?.form.finishEditing()
            self?.onClosed?()
        }
        window.onResignKey = { [weak self] in
            self?.form.cancelRecording()
        }
        updateTitle()
    }

    /// 設定のウィンドウ。
    var window: ContentWindow {
        host.window
    }

    /// ウィンドウが開いているか。
    public var isShown: Bool {
        host.isShown
    }

    /// ウィンドウを開いて前面に出す。閉じていたときは、いまの設定を読み直して画面の中央に置く。
    public func show() {
        if host.isShown {
            host.show(center: false)
            return
        }
        form.load(settings())
        updateTitle()
        host.show(center: true)
    }

    /// ウィンドウを閉じる。入力の途中の日数は確定する。
    public func close() {
        window.close()
    }

    /// ほかの所（セットアップなど）で変わった設定を、開いている画面に映す。
    ///
    /// 変わった項目だけを入れ直す。記録を待っている記録欄と、書きかけの定型文・日数の入力欄は、その項目が変わっていなければ触らない。
    /// 閉じているときは何もしない（開くときに読み直す）。
    public func refresh() {
        guard host.isShown else {
            return
        }
        form.sync(settings())
        updateTitle()
    }

    private func updateTitle() {
        window.title = UIStrings(language: form.settings.language)[.settingsTitle]
    }
}
