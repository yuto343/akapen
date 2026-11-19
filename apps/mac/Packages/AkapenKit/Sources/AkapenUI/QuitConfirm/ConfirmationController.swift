import AppKit
import SwiftUI
import AkapenCore
import AkapenAXID

/// 終了・全削除の確認を共通のパネルで出す。暗転、ばねの出方、Return / Esc の扱いを共有する。
///
/// 出すかどうかは組み立ての側が決め（`DECISIONS.md` A4）、件数を渡して `show(annotationCount:)` を呼ぶ。
/// 答えは `onResult` で伝える。自分ではアプリを終了しない。
/// 出ているあいだにもう一度 `show` を呼んでも、パネルは 1 つのまま（件数だけ新しくする）。
/// パネルは、`show` を呼んだときにカーソルがある画面に出す。
@MainActor public final class ConfirmationController {
    /// 答えが出たとき。パネルを隠してから呼ぶ。1 回の確認につき 1 回だけ呼ぶ。
    public var onResult: (@MainActor (ConfirmationResult) -> Void)?

    let panel: FloatingPanel
    let hostingView: FirstMouseHostingView<ConfirmationOverlay>
    private let purpose: ConfirmationPurpose
    private let language: @MainActor () -> Language
    private let screens: any ScreenProviding
    private let fadeDuration: TimeInterval
    private let presentation = PanelPresentation()
    /// 出している画面。出ているあいだは変えない。
    private(set) var screen: ScreenInfo?
    /// いま出している件数。
    private(set) var annotationCount = 0

    /// 文言の言語は `model` の設定から読む。
    public convenience init(model: SessionModel, purpose: ConfirmationPurpose) {
        self.init(
            purpose: purpose,
            language: { [weak model] in
                model?.settings.language ?? Settings().language
            },
            screens: SystemScreens(),
            fadeDuration: Tokens.Motion.fade
        )
    }

    /// テスト用。画面とフェードの長さを差し替えられる。`fadeDuration` が 0 ならフェードしない。
    init(purpose: ConfirmationPurpose, language: @escaping @MainActor () -> Language, screens: any ScreenProviding, fadeDuration: TimeInterval) {
        self.purpose = purpose
        self.language = language
        self.screens = screens
        self.fadeDuration = fadeDuration
        panel = FloatingPanel(level: .modalPanel)
        panel.allowsKey = true
        panel.setAccessibilityIdentifier(purpose.panelID)
        let placeholder = ScreenInfo(
            id: 0,
            frame: ScreenRect(x: 0, y: 0, width: 0, height: 0),
            visibleFrame: ScreenRect(x: 0, y: 0, width: 0, height: 0)
        )
        hostingView = FirstMouseHostingView(rootView: ConfirmationOverlay(
            screen: placeholder,
            purpose: purpose,
            annotationCount: 0,
            strings: UIStrings(language: .en),
            onQuit: {},
            onCancel: {}
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onReturn = { [weak self] in
            self?.answer(.confirm)
        }
        panel.onCancel = { [weak self] in
            self?.answer(.cancel)
        }
        connectPresentation()
    }

    /// 確認が出ているか。
    public var isShown: Bool {
        panel.isShown
    }

    /// 確認を出す。`annotationCount` は説明文に出す未コピーの注釈の件数。出ているあいだに呼んだら、件数だけ新しくする。
    public func show(annotationCount: Int) {
        self.annotationCount = annotationCount
        let wasShown = panel.isShown
        if !wasShown || screen == nil {
            screen = ScreenInfo.containing(screens.mouseLocation, in: screens.screens)
        }
        guard let screen else {
            return
        }
        hostingView.rootView = ConfirmationOverlay(
            screen: screen,
            purpose: purpose,
            annotationCount: annotationCount,
            strings: UIStrings(language: language()),
            onQuit: { [weak self] in
                self?.answer(.confirm)
            },
            onCancel: { [weak self] in
                self?.answer(.cancel)
            },
            presentation: presentation
        )
        let area = PanelPlacement.dimmedArea(screen: screen)
        panel.setFrame(ScreenCoordinates.nsRect(area, primaryTop: screens.primaryTop), display: true)
        if !wasShown {
            panel.fadeIn(duration: fadeDuration, makeKey: true)
        }
    }

    /// 答えを待たずに隠す（`onResult` は呼ばない）。注釈がなくなったときや、終了処理の後始末に使う。
    public func hide() {
        panel.hideNow()
        screen = nil
    }

    /// 出しはじめは見えない状態で描き、前に出してから、ばねで出す（暗転は不透明度だけ）。
    private func connectPresentation() {
        panel.onWillPresent = { [weak self] in
            guard let self, fadeDuration > 0 else {
                return
            }
            setPresented(false, animation: nil)
        }
        panel.onDidPresent = { [weak self] in
            guard let self else {
                return
            }
            guard fadeDuration > 0 else {
                setPresented(true, animation: nil)
                return
            }
            Task { @MainActor [weak self] in
                self?.setPresented(true, animation: Tokens.Motion.panelSpring)
            }
        }
        panel.onDidHide = { [weak self] in
            guard let self, fadeDuration > 0 else {
                return
            }
            setPresented(false, animation: nil)
        }
    }

    private func setPresented(_ presented: Bool, animation: Animation?) {
        var transaction = Transaction(animation: animation)
        transaction.disablesAnimations = animation == nil
        withTransaction(transaction) {
            presentation.isPresented = presented
        }
        if animation == nil {
            hostingView.layoutSubtreeIfNeeded()
        }
    }

    /// 答えを出す。出ていなければ何もしない（`Return` の連打などで 2 回呼ばない）。
    func answer(_ result: ConfirmationResult) {
        guard panel.isShown else {
            return
        }
        panel.fadeOut(duration: fadeDuration)
        screen = nil
        onResult?(result)
    }
}
