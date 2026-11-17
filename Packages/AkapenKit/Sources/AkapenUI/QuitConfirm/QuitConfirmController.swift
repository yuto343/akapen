import AppKit
import SwiftUI
import AkapenCore
import AkapenAXID

/// 終了の確認の答え。
public enum QuitConfirmResult: Equatable, Sendable {
    /// 終了する（`Quit` か `Return`）。
    case quit
    /// 取りやめる（`Cancel` か `Esc`）。
    case cancel
}

/// 終了の確認（App 09）を出す。自前のパネルで、画面の暗転、赤い `Quit`、`Return` で `Quit`、`Esc` で `Cancel`（`DECISIONS.md` 15）。
///
/// 出すかどうかは組み立ての側が決め（`DECISIONS.md` A4）、件数を渡して `show(annotationCount:)` を呼ぶ。
/// 答えは `onResult` で伝える。自分ではアプリを終了しない。
/// 出ているあいだにもう一度 `show` を呼んでも、パネルは 1 つのまま（件数だけ新しくする）。
/// パネルは、`show` を呼んだときにカーソルがある画面に出す。
@MainActor public final class QuitConfirmController {
    /// 答えが出たとき。パネルを隠してから呼ぶ。1 回の確認につき 1 回だけ呼ぶ。
    public var onResult: (@MainActor (QuitConfirmResult) -> Void)?

    let panel: FloatingPanel
    let hostingView: FirstMouseHostingView<QuitConfirmOverlay>
    private let language: @MainActor () -> Language
    private let screens: any ScreenProviding
    private let fadeDuration: TimeInterval
    /// 出している画面。出ているあいだは変えない。
    private(set) var screen: ScreenInfo?
    /// いま出している件数。
    private(set) var annotationCount = 0

    /// 文言の言語は `model` の設定から読む。
    public convenience init(model: SessionModel) {
        self.init(
            language: { [weak model] in
                model?.settings.language ?? Settings().language
            },
            screens: SystemScreens(),
            fadeDuration: Tokens.Motion.fade
        )
    }

    /// テスト用。画面とフェードの長さを差し替えられる。`fadeDuration` が 0 ならフェードしない。
    init(language: @escaping @MainActor () -> Language, screens: any ScreenProviding, fadeDuration: TimeInterval) {
        self.language = language
        self.screens = screens
        self.fadeDuration = fadeDuration
        panel = FloatingPanel(level: .modalPanel)
        panel.allowsKey = true
        panel.setAccessibilityIdentifier(AXID.QuitConfirm.panel)
        let placeholder = ScreenInfo(
            id: 0,
            frame: ScreenRect(x: 0, y: 0, width: 0, height: 0),
            visibleFrame: ScreenRect(x: 0, y: 0, width: 0, height: 0)
        )
        hostingView = FirstMouseHostingView(rootView: QuitConfirmOverlay(
            screen: placeholder,
            annotationCount: 0,
            strings: UIStrings(language: .en),
            onQuit: {},
            onCancel: {}
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.onReturn = { [weak self] in
            self?.answer(.quit)
        }
        panel.onCancel = { [weak self] in
            self?.answer(.cancel)
        }
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
        hostingView.rootView = QuitConfirmOverlay(
            screen: screen,
            annotationCount: annotationCount,
            strings: UIStrings(language: language()),
            onQuit: { [weak self] in
                self?.answer(.quit)
            },
            onCancel: { [weak self] in
                self?.answer(.cancel)
            }
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

    /// 答えを出す。出ていなければ何もしない（`Return` の連打などで 2 回呼ばない）。
    func answer(_ result: QuitConfirmResult) {
        guard panel.isShown else {
            return
        }
        panel.fadeOut(duration: fadeDuration)
        screen = nil
        onResult?(result)
    }
}
