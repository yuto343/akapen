import AppKit
import Observation
import AkapenCore

/// 初回のセットアップの状態（ページ、画面収録の許可、ホットキーの記録欄）。`SessionModel` も OS も知らず、操作をコールバックで外に渡す。
@MainActor @Observable final class SetupFlow {
    /// セットアップのページ。
    enum Page: Int, CaseIterable {
        /// 1 ページ目: ホットキー（App 07）。
        case hotkey = 1
        /// 2 ページ目: 画面収録の許可（App 08）。
        case permission = 2
    }

    /// 下の行の右端の主ボタン。
    enum PrimaryAction: Equatable {
        /// `Continue`（1 ページ目）。
        case next
        /// `Open System Settings`（2 ページ目、許可を待っている）。
        case openSystemSettings
        /// `Done`（2 ページ目、許可が取れた）。
        case done
    }

    /// いまのページ。
    private(set) var page: Page = .hotkey
    /// 直前のページの切り替えが、先へ進む向きだったか（ページの出る動きの向きに使う）。
    private(set) var movedForward = true
    /// 画面収録の許可が取れているか。
    private(set) var isGranted = false
    /// 表示の言語。
    private(set) var language: Language
    /// ホットキーの記録欄（未割り当てを許さない。設定と同じ部品）。
    let hotkey: KeyRecorderModel
    /// キーの表示。
    @ObservationIgnored let shortcutText: ShortcutText
    /// ページが変わったとき。
    @ObservationIgnored var onPageChange: (@MainActor (Page) -> Void)?
    /// `Open System Settings` が押されたとき。
    @ObservationIgnored var onOpenSystemSettings: (@MainActor () -> Void)?
    /// `Done` が押されたとき（許可が取れているときだけ）。
    @ObservationIgnored var onDone: (@MainActor () -> Void)?

    var imagesPath = ""

    init(settings: Settings, shortcutText: ShortcutText = ShortcutText()) {
        language = settings.language
        hotkey = KeyRecorderModel(shortcut: settings.hotkey, allowsNone: false)
        self.shortcutText = shortcutText
    }

    /// 主ボタン。許可が取れるまでは `Done` を出さない（`DECISIONS.md` 25・A5）。
    var primaryAction: PrimaryAction {
        switch page {
        case .hotkey:
            .next
        case .permission:
            isGranted ? .done : .openSystemSettings
        }
    }

    /// 2 ページ目の 3 行目の右端の表示（`Waiting…` / `Granted`）。
    var permissionStatus: StringKey {
        isGranted ? .setupGranted : .setupWaiting
    }

    /// 最初のページから始め直す（ウィンドウを開いたとき）。
    func load(_ settings: Settings, isGranted: Bool) {
        language = settings.language
        hotkey.load(settings.hotkey)
        self.isGranted = isGranted
        if page != .hotkey {
            page = .hotkey
            onPageChange?(.hotkey)
        }
    }

    /// ほかの所で変わった設定を映す。言語と、記録を待っていないときのホットキー。ページは変えない。
    func sync(_ settings: Settings) {
        if language != settings.language {
            language = settings.language
        }
        if !hotkey.isRecording, hotkey.shortcut != settings.hotkey {
            hotkey.load(settings.hotkey)
        }
    }

    /// `Continue`。2 ページ目へ進む。
    func goNext() {
        move(to: .permission)
    }

    /// `Back`。1 ページ目へ戻る。
    func goBack() {
        move(to: .hotkey)
    }

    /// 許可の状態を入れる。
    func setGranted(_ granted: Bool) {
        if isGranted != granted {
            isGranted = granted
        }
    }

    /// `Open System Settings`。
    func openSystemSettings() {
        onOpenSystemSettings?()
    }

    /// `Done`。許可が取れていなければ何もしない（`DECISIONS.md` A5）。
    func done() {
        guard isGranted else {
            return
        }
        onDone?()
    }

    private func move(to page: Page) {
        hotkey.cancelRecording()
        guard self.page != page else {
            return
        }
        movedForward = page.rawValue > self.page.rawValue
        self.page = page
        onPageChange?(page)
    }
}
