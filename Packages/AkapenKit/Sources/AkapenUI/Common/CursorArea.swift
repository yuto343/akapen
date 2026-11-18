import AppKit
import SwiftUI

extension View {
    /// ホバー中のカーソルを `cursor` にする。アプリがアクティブでないとき（アクティブ化しないパネルの上）でも効く。
    ///
    /// SwiftUI の `pointerStyle` とカーソル矩形は、アクティブでないアプリでは効かないので、
    /// `.activeAlways` の追跡領域で入った・動いた・出たを受けて `NSCursor.set()` する。
    /// 出たときは矢印に戻す（下に覆う面があれば、面が次の動きで十字にし直す）。
    func hoverCursor(_ cursor: NSCursor, isEnabled: Bool = true) -> some View {
        overlay {
            CursorArea(cursor: isEnabled ? cursor : nil)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// `hoverCursor(_:isEnabled:)` の中身。クリックは受け取らず、下の部品に通す。
private struct CursorArea: NSViewRepresentable {
    /// nil なら矢印のままにする（使えない状態のボタン）。
    let cursor: NSCursor?

    func makeNSView(context: Context) -> CursorTrackingView {
        let view = CursorTrackingView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ view: CursorTrackingView, context: Context) {
        let changed = view.cursor !== cursor
        view.cursor = cursor
        if changed {
            view.refreshIfHovering()
        }
    }
}

/// 追跡領域でカーソルを切り替えるビュー。
final class CursorTrackingView: NSView {
    var cursor: NSCursor?
    private var isHovering = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        apply()
    }

    override func mouseMoved(with event: NSEvent) {
        isHovering = true
        apply()
    }

    override func cursorUpdate(with event: NSEvent) {
        apply()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        NSCursor.arrow.set()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            isHovering = false
        }
    }

    /// 使える・使えないが変わったとき、ホバー中ならすぐに映す。
    func refreshIfHovering() {
        if isHovering {
            apply()
        }
    }

    private func apply() {
        (cursor ?? .arrow).set()
    }
}
