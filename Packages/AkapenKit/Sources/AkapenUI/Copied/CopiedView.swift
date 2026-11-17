import SwiftUI
import AkapenAXID

/// コピー完了の表示（App 04）。件数は `SessionModel.lastCopiedCount`。
public struct CopiedView: View {
    private let count: Int
    private let strings: UIStrings

    /// コピーした注釈の件数と、文言の言語を受け取る。
    public init(count: Int, strings: UIStrings) {
        self.count = count
        self.strings = strings
    }

    public var body: some View {
        HStack(spacing: Tokens.Toast.gap) {
            icon
            VStack(alignment: .leading, spacing: Tokens.Toast.textGap) {
                Text(strings[.copiedTitle])
                    .textStyle(Tokens.Typography.toastTitle)
                    .foregroundStyle(Tokens.Toast.title.color)
                Text(strings.plural(.copiedSummary, count: count))
                    .textStyle(Tokens.Typography.toastSubtitle)
                    .foregroundStyle(Tokens.Toast.subtitle.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(strings[.copiedShortcut])
                .textStyle(Tokens.Typography.toastKeycap)
                .foregroundStyle(Tokens.Toast.keycapText.color)
                .padding(.horizontal, Tokens.Toast.keycapPaddingX)
                .background(RoundedBox(cornerRadius: Tokens.Radius.keycap).fill(Tokens.Toast.keycapBackground.color))
                .fixedSize()
        }
        .padding(.vertical, Tokens.Toast.paddingY)
        .padding(.leading, Tokens.Toast.paddingLeading)
        .padding(.trailing, Tokens.Toast.paddingTrailing)
        .frame(width: Tokens.Toast.width)
        .background(RoundedBox(cornerRadius: Tokens.Radius.large).fill(Tokens.Toast.background.color))
        .boxShadow(Tokens.Toast.shadows, cornerRadius: Tokens.Radius.large)
        .lightAppearance()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AXID.Copied.message)
    }

    @ViewBuilder private var icon: some View {
        if let image = AppIconImage.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: Tokens.Toast.iconSize, height: Tokens.Toast.iconSize)
                .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: Tokens.Toast.iconSize, height: Tokens.Toast.iconSize)
        }
    }
}
