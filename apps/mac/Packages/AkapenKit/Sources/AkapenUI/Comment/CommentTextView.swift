import AppKit
import SwiftUI
import AkapenCore

/// 入力欄で扱うキーの仮想キーコード。
enum KeyCode {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
}

/// 入力欄でのキーの扱い。
enum CommentKeyAction: Equatable {
    /// 確定する。
    case confirm
    /// 改行を入れる。
    case insertNewline
    /// 取り消す。
    case cancel
    /// 入力欄（と日本語入力）に任せる。
    case passThrough
}

/// 押されたキーを、入力欄での扱いに直す。
///
/// `Return` の扱いは `AkapenCore` の `ConfirmKeyPolicy` に聞き、その結果をそのまま行動に移す。
/// 変換中かどうか（`isComposing`）は、入力欄の `hasMarkedText()` を渡す。
struct CommentKeyRouter {
    var confirmKey: ConfirmKey
    /// `Return` の扱いを決める関数。既定は `ConfirmKeyPolicy.decide`。テストでは記録する偽物に差し替える。
    var decide: (KeyModifiers, Bool, ConfirmKey) -> ConfirmKeyDecision

    init(
        confirmKey: ConfirmKey,
        decide: @escaping (KeyModifiers, Bool, ConfirmKey) -> ConfirmKeyDecision = ConfirmKeyPolicy.decide(modifiers:isComposing:confirmKey:)
    ) {
        self.confirmKey = confirmKey
        self.decide = decide
    }

    func action(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, isComposing: Bool) -> CommentKeyAction {
        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            switch decide(Self.modifiers(modifierFlags), isComposing, confirmKey) {
            case .confirm:
                return .confirm
            case .insertNewline:
                return .insertNewline
            case .passThrough:
                return .passThrough
            }
        case KeyCode.escape:
            // 変換中の Esc は、変換の取り消しとして日本語入力に任せる。
            return isComposing ? .passThrough : .cancel
        default:
            return .passThrough
        }
    }

    /// AppKit の修飾キーを、`AkapenCore` の修飾キーに直す。Caps Lock やテンキーの印は数えない。
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> KeyModifiers {
        KeyModifiers(eventFlags: flags)
    }
}

/// コメントを書く入力欄。`Return` と `Esc` を `CommentKeyRouter` で振り分ける。
final class CommentTextView: NSTextView {
    var router = CommentKeyRouter(confirmKey: .enter)
    var onConfirm: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: (() -> Void)?
    /// 空のときに出す文言。
    var placeholder: NSAttributedString? {
        didSet {
            needsDisplay = true
        }
    }
    /// ウィンドウに入ったら、フォーカスを入れる。
    var focusWhenAttached = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard focusWhenAttached, let window else {
            return
        }
        focusWhenAttached = false
        window.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let action = router.action(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            isComposing: hasMarkedText()
        )
        switch action {
        case .confirm:
            onConfirm?(string)
        case .insertNewline:
            insertNewlineIgnoringFieldEditor(nil)
        case .cancel:
            onCancel?()
        case .passThrough:
            super.keyDown(with: event)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        onTextChange?()
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        needsDisplay = true
        onTextChange?()
    }

    override func unmarkText() {
        super.unmarkText()
        needsDisplay = true
        onTextChange?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !hasMarkedText(), let placeholder else {
            return
        }
        let origin = textContainerOrigin
        let width = bounds.width - origin.x * 2
        placeholder.draw(
            with: NSRect(x: origin.x, y: origin.y, width: width, height: bounds.height),
            options: [.usesLineFragmentOrigin]
        )
    }
}

/// 複数行の入力欄の中身（`NSScrollView` と `CommentTextView`）を持ち、高さを決める。
///
/// コメント入力と、一覧の編集中の行で使う。行数の上限まで伸び、超えたら中でスクロールする（`DECISIONS.md` 22）。
@MainActor @Observable final class GrowingTextController {
    @ObservationIgnored let textView: CommentTextView
    @ObservationIgnored let scrollView: NSScrollView
    @ObservationIgnored private let style: TextStyle
    @ObservationIgnored private let maxLines: Int
    @ObservationIgnored private let textColor: ColorToken
    @ObservationIgnored private let placeholderColor: ColorToken
    /// 入力欄の高さ（1 行〜上限の行数）。
    private(set) var height: CGFloat
    /// 入力欄の幅（文字が並ぶ幅）。
    @ObservationIgnored let width: CGFloat
    /// 人が文字を書き換えたとき（日本語の変換中は呼ばない）。`setText(_:)` で入れたときは呼ばない。
    @ObservationIgnored var onEdit: ((String) -> Void)?

    init(
        style: TextStyle,
        maxLines: Int,
        width: CGFloat,
        textColor: ColorToken,
        caretColor: ColorToken,
        placeholderColor: ColorToken
    ) {
        self.style = style
        self.maxLines = maxLines
        self.width = width
        self.textColor = textColor
        self.placeholderColor = placeholderColor
        height = style.lineHeight
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        textView = CommentTextView(frame: NSRect(x: 0, y: 0, width: width, height: style.lineHeight), textContainer: container)
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: style.lineHeight))
        configure(caretColor: caretColor)
        textView.onTextChange = { [weak self] in
            self?.textChanged()
        }
    }

    private func configure(caretColor: ColorToken) {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: style.lineHeight)
        textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.insertionPointColor = caretColor.nsColor
        textView.font = style.nsFont
        textView.textColor = textColor.nsColor
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = attributes(color: textColor)
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
    }

    private var paragraphStyle: NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        return paragraph
    }

    /// 資料の行の高さに合わせ、フォントの行の高さとの差の半分だけ文字を持ち上げて、行の上下の中央に置く。
    private func attributes(color: ColorToken) -> [NSAttributedString.Key: Any] {
        [
            .font: style.nsFont,
            .foregroundColor: color.nsColor,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: max(0, style.lineHeight - style.naturalLineHeight) / 2,
            .kern: style.trackingPoints,
        ]
    }

    /// いまの文字列。
    var text: String {
        textView.string
    }

    /// 文字列を入れ替え、カーソルを末尾に置く。取り消しの履歴は消す。
    func setText(_ text: String) {
        textView.string = text
        textView.textStorage?.setAttributes(attributes(color: textColor), range: NSRange(location: 0, length: textView.textStorage?.length ?? 0))
        textView.typingAttributes = attributes(color: textColor)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        textView.undoManager?.removeAllActions(withTarget: textView.textStorage as Any)
        recalculateHeight()
        textView.needsDisplay = true
    }

    /// 空のときに出す文言。
    func setPlaceholder(_ text: String?) {
        textView.placeholder = text.map { NSAttributedString(string: $0, attributes: attributes(color: placeholderColor)) }
    }

    /// 確定キーの設定。
    func setConfirmKey(_ confirmKey: ConfirmKey) {
        textView.router.confirmKey = confirmKey
    }

    /// 入力欄にフォーカスを入れる。まだウィンドウに入っていなければ、入った時点で入れる。
    func focus() {
        if let window = textView.window {
            textView.focusWhenAttached = false
            window.makeFirstResponder(textView)
            return
        }
        textView.focusWhenAttached = true
    }

    private func textChanged() {
        recalculateHeight()
        if !textView.hasMarkedText() {
            onEdit?(textView.string)
        }
    }

    /// 入力欄の高さを、文字の行数（1 行〜上限）から決め直す。
    func recalculateHeight() {
        guard let layout = textView.layoutManager, let container = textView.textContainer else {
            return
        }
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container).height
        let lines = max(1, min(CGFloat(maxLines), (used / style.lineHeight).rounded(.up)))
        let newHeight = lines * style.lineHeight
        if newHeight != height {
            height = newHeight
        }
        textView.scrollRangeToVisible(textView.selectedRange())
    }
}

/// `GrowingTextController` の入力欄を SwiftUI に置く。高さは `controller.height` に従う。
struct GrowingTextField: NSViewRepresentable {
    let controller: GrowingTextController

    func makeNSView(context: Context) -> NSScrollView {
        controller.scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? controller.width, height: controller.height)
    }
}
