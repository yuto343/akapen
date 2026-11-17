import SwiftUI
import AkapenAXID

/// 画面下のボタン類に表示する値。
public struct ToolbarState: Equatable, Sendable {
    /// 確定済みの注釈の件数（入力中のものは数えない。`DECISIONS.md` 11）。
    public var annotationCount: Int
    /// 一覧が開いているか。開いているときは「List」を押された見た目にする。
    public var isListOpen: Bool

    /// 件数と一覧の開閉から作る。
    public init(annotationCount: Int, isListOpen: Bool) {
        self.annotationCount = annotationCount
        self.isListOpen = isListOpen
    }

    /// 「Copy prompt」を押せるか。0 件では使えない（`DECISIONS.md` 20）。
    public var canCopy: Bool {
        annotationCount > 0
    }

    /// バッジを出すか。0 件では出さない（`DECISIONS.md` 20）。
    public var showsBadge: Bool {
        annotationCount > 0
    }
}

/// 画面下のボタン類（「+」「List」「Copy prompt」。Paper の App 01〜03）。
public struct ToolbarView: View {
    private let state: ToolbarState
    private let strings: UIStrings
    private let onAdd: () -> Void
    private let onList: () -> Void
    private let onCopy: () -> Void

    /// 表示に要る値と、押されたときのコールバックを受け取る。
    public init(
        state: ToolbarState,
        strings: UIStrings,
        onAdd: @escaping () -> Void,
        onList: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) {
        self.state = state
        self.strings = strings
        self.onAdd = onAdd
        self.onList = onList
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: Tokens.Toolbar.gap) {
            addButton
            listButton
            copyButton
        }
        .padding(Tokens.Toolbar.padding)
        .background(Capsule().fill(Tokens.Toolbar.background.color))
        .boxShadow(Tokens.Toolbar.shadows, cornerRadius: Tokens.Radius.pill)
        .fixedSize()
        .lightAppearance()
    }

    private var addButton: some View {
        Button(action: onAdd) {
            IconView(
                glyph: .plus,
                size: Tokens.Toolbar.iconSize,
                color: Tokens.Toolbar.iconColor,
                lineWidth: Tokens.Stroke.addIcon
            )
            .frame(width: Tokens.Toolbar.controlHeight, height: Tokens.Toolbar.controlHeight)
            .background(Circle().fill(Tokens.Toolbar.controlBackground.color))
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityLabel(strings[.add])
        .accessibilityIdentifier(AXID.Toolbar.add)
    }

    private var listButton: some View {
        Button(action: onList) {
            HStack(spacing: Tokens.Toolbar.listGap) {
                IconView(
                    glyph: .list,
                    size: Tokens.Toolbar.iconSize,
                    color: Tokens.Toolbar.iconColor,
                    lineWidth: Tokens.Stroke.listIcon
                )
                Text(strings[.list])
                    .textStyle(Tokens.Typography.control)
                    .foregroundStyle(Tokens.Toolbar.labelColor.color)
                if state.showsBadge {
                    badge
                }
            }
            .padding(.horizontal, Tokens.Toolbar.listPaddingX)
            .frame(height: Tokens.Toolbar.controlHeight)
            .background(Capsule().fill(listBackground.color))
            .insetOutline(
                state.isListOpen ? Tokens.Toolbar.listOpenOutline : Tokens.ExtraColor.transparent,
                width: Tokens.Stroke.emphasis,
                cornerRadius: Tokens.Radius.pill
            )
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityLabel(strings[.list])
        .accessibilityValue(state.showsBadge ? String(state.annotationCount) : "")
        .accessibilityAddTraits(state.isListOpen ? .isSelected : [])
        .accessibilityIdentifier(AXID.Toolbar.list)
    }

    private var listBackground: ColorToken {
        state.isListOpen ? Tokens.Toolbar.listOpenBackground : Tokens.Toolbar.controlBackground
    }

    private var badge: some View {
        Text(String(state.annotationCount))
            .textStyle(Tokens.Typography.badge)
            .foregroundStyle(Tokens.Toolbar.badgeText.color)
            .padding(.horizontal, Tokens.Toolbar.badgePaddingX)
            .background(Capsule().fill(Tokens.Toolbar.badgeBackground.color))
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: Tokens.Toolbar.copyGap) {
                Text(strings[.copyPrompt])
                    .textStyle(Tokens.Typography.control)
                    .foregroundStyle(Tokens.Toolbar.copyText.color)
                IconView(
                    glyph: .arrowUpRight,
                    size: Tokens.Toolbar.copyIconSize,
                    color: Tokens.Toolbar.copyIconColor,
                    lineWidth: Tokens.Stroke.arrowIcon
                )
                .frame(width: Tokens.Toolbar.copyCircleSize, height: Tokens.Toolbar.copyCircleSize)
                .background(Circle().fill(Tokens.Toolbar.copyCircle.color))
            }
            .padding(.leading, Tokens.Toolbar.copyPaddingLeading)
            .padding(.trailing, Tokens.Toolbar.copyPaddingTrailing)
            .frame(height: Tokens.Toolbar.controlHeight)
            .background(Capsule().fill(Tokens.Toolbar.copyBackground.color))
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .disabled(!state.canCopy)
        .accessibilityLabel(strings[.copyPrompt])
        .accessibilityIdentifier(AXID.Toolbar.copyPrompt)
    }
}
