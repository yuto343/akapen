import SwiftUI
import AkapenAXID

/// メニューの見出し（アイコン、`akapen`、注釈の件数。App 05）。`NSMenuItem` のカスタムビューに載せる。
public struct MenuHeaderView: View {
    let annotationCount: Int
    let strings: UIStrings

    /// 未コピーの注釈の件数と、文言の言語を受け取る。
    public init(annotationCount: Int, strings: UIStrings) {
        self.annotationCount = annotationCount
        self.strings = strings
    }

    public var body: some View {
        HStack(spacing: Tokens.Menu.headerGap) {
            AppIconView(size: Tokens.Menu.iconSize)
            VStack(alignment: .leading, spacing: 0) {
                Text(strings[.appName])
                    .textStyle(Tokens.Typography.menuTitle)
                    .foregroundStyle(Tokens.Menu.title.color)
                Text(strings.menuStatus(count: annotationCount))
                    .textStyle(Tokens.Typography.menuSubtitle)
                    .foregroundStyle(Tokens.Menu.subtitle.color)
                    .accessibilityIdentifier(AXID.MenuBar.status)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.top, Tokens.Menu.headerPaddingTop)
        .padding(.horizontal, Tokens.Menu.headerPaddingX)
        .padding(.bottom, Tokens.Menu.headerPaddingBottom)
        .frame(width: Tokens.Menu.headerWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .lightAppearance()
    }
}
