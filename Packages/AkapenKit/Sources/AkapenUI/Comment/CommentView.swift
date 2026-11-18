import SwiftUI
import AkapenCore
import AkapenAXID

/// 赤枠の横のコメント入力（App 02）。入力欄の中身は `GrowingTextController` が持つ。
struct CommentView: View {
    let editor: GrowingTextController
    let confirmKey: ConfirmKey
    let strings: UIStrings

    /// 文字が並ぶ幅（入れ物の幅から左右の余白を引いたもの）。
    static let textWidth = Tokens.Comment.width - Tokens.Comment.inputPaddingX * 2

    /// コメント入力の入力欄を作る。
    @MainActor static func makeEditor() -> GrowingTextController {
        let editor = GrowingTextController(
            style: Tokens.Typography.commentInput,
            maxLines: Tokens.Comment.maxLines,
            width: textWidth,
            textColor: Tokens.Comment.text,
            caretColor: Tokens.Comment.caret,
            placeholderColor: Tokens.Comment.placeholder
        )
        editor.textView.setAccessibilityIdentifier(AXID.Comment.field)
        return editor
    }

    var body: some View {
        VStack(spacing: 0) {
            GrowingTextField(controller: editor)
                .frame(width: Self.textWidth, height: editor.height)
                .padding(.top, Tokens.Comment.inputPaddingTop)
                .padding(.horizontal, Tokens.Comment.inputPaddingX)
                .padding(.bottom, Tokens.Comment.inputPaddingBottom)
            Rectangle()
                .fill(Tokens.Comment.divider.color)
                .frame(height: Tokens.Stroke.hairline)
            HStack(spacing: 0) {
                KeyHintRow(hints: strings.commentHints(for: confirmKey), spacing: Tokens.Comment.footerHintGap)
                Spacer(minLength: Tokens.Spacing.s2)
                KeyHintView(hint: strings.cancelHint)
            }
            .padding(.vertical, Tokens.Comment.footerPaddingY)
            .padding(.horizontal, Tokens.Comment.footerPaddingX)
        }
        .frame(width: Tokens.Comment.width)
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Comment.background.color))
        .boxShadow(Tokens.Comment.shadows, cornerRadius: Tokens.Radius.media)
        .lightAppearance()
    }
}
