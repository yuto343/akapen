import AppKit

/// 本文全体を載せる入れ物。左上を原点にし、ウィンドウが小さいときは全体を同じ比率で縮める。
final class SampleCanvas: NSView {
    override var isFlipped: Bool {
        true
    }

    /// 自分の大きさに合わせて、中の座標の倍率を決め直す。
    func fitContents() {
        let widthScale = frame.width / SampleLayout.canvasSize.width
        let heightScale = frame.height / SampleLayout.canvasSize.height
        let scale = min(1, widthScale, heightScale)
        setBoundsSize(NSSize(width: frame.width / scale, height: frame.height / scale))
    }

    override func draw(_ dirtyRect: NSRect) {
        SampleColor.background.setFill()
        bounds.fill()
    }
}

/// 角丸の矩形を塗るだけの部品（灰色の棒、選択中の項目の地、区切り線）。
final class FilledShape: NSView {
    private let color: NSColor

    private let radius: CGFloat

    init(frame: NSRect, color: NSColor, radius: CGFloat) {
        self.color = color
        self.radius = radius
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }
}

/// サイドバー。地と右の線を描き、中に項目を並べる。
final class SidebarView: NSView {
    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        SampleColor.sidebar.setFill()
        bounds.fill()
        SampleColor.sidebarLine.setFill()
        NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height).fill()
    }
}

/// 入力欄の輪郭（角丸 6、内側に 1px の線、地なし）。中に実際の入力欄を入れる。
final class OutlineView: NSView {
    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        SampleColor.outline.setStroke()
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: SampleLayout.controlRadius,
            yRadius: SampleLayout.controlRadius
        )
        path.lineWidth = 1
        path.stroke()
    }
}

/// `Cancel` / `Submit` のボタン。標準の枠を使わず、資料の形（角丸 6、30pt の高さ）で描く。
final class SampleButton: NSButton {
    /// ボタンの見た目の種類。
    enum Style {
        /// 輪郭だけ（`Cancel`）。
        case outlined

        /// 青い地（`Submit`）。
        case filled
    }

    private let style: Style

    init(frame: NSRect, title: String, style: Style) {
        self.style = style
        super.init(frame: frame)
        self.title = title
        isBordered = false
        setButtonType(.momentaryPushIn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: SampleLayout.controlRadius,
            yRadius: SampleLayout.controlRadius
        )
        switch style {
        case .outlined:
            SampleColor.outline.setStroke()
            path.lineWidth = 1
            path.stroke()
        case .filled:
            SampleColor.accent.setFill()
            path.fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style == .filled
                ? NSFont.systemFont(ofSize: SampleLayout.fontSize, weight: .medium)
                : NSFont.systemFont(ofSize: SampleLayout.fontSize),
            .foregroundColor: style == .filled ? SampleColor.accentText : SampleColor.text,
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let size = text.size()
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: origin)
    }
}
