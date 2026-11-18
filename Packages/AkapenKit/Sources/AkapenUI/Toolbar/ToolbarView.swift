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

/// 画面下のボタン類（「List」「Copy prompt」。Paper の App 01〜03）。
///
/// ボタン類が出ているあいだは、いつでも枠を描ける状態なので「+」は置かない。
/// ボタンには、出ているあいだに使えるショートカット（`⌘L` / `⌘C`）を小さく添え、ツールチップでも示す。
public struct ToolbarView: View {
    private let state: ToolbarState
    private let strings: UIStrings
    private let onList: () -> Void
    private let onCopy: () -> Void

    /// 表示に要る値と、押されたときのコールバックを受け取る。
    public init(
        state: ToolbarState,
        strings: UIStrings,
        onList: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) {
        self.state = state
        self.strings = strings
        self.onList = onList
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: Tokens.Toolbar.gap) {
            listButton
            copyButton
        }
        .padding(Tokens.Toolbar.padding)
        .background(Capsule().fill(Tokens.Toolbar.background.color))
        .boxShadow(Tokens.Toolbar.shadows, cornerRadius: Tokens.Radius.pill)
        .fixedSize()
        .lightAppearance()
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
                HStack(spacing: Tokens.Toolbar.shortcutGap) {
                    Text(strings[.list])
                        .textStyle(Tokens.Typography.control)
                        .foregroundStyle(Tokens.Toolbar.labelColor.color)
                    shortcut(strings[.listShortcut], color: Tokens.Toolbar.listShortcutText)
                }
                if state.showsBadge {
                    badge
                        .transition(.scale(scale: Tokens.Motion.panelEntranceScale).combined(with: .opacity))
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
            .animation(Tokens.Motion.hoverAnimation, value: state.isListOpen)
            .animation(Tokens.Motion.panelSpring, value: state.annotationCount)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .help(strings[.listHelp])
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
            .contentTransition(.numericText(value: Double(state.annotationCount)))
            .padding(.horizontal, Tokens.Toolbar.badgePaddingX)
            .background(Capsule().fill(Tokens.Toolbar.badgeBackground.color))
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: Tokens.Toolbar.copyGap) {
                HStack(spacing: Tokens.Toolbar.shortcutGap) {
                    Text(strings[.copyPrompt])
                        .textStyle(Tokens.Typography.control)
                        .foregroundStyle(Tokens.Toolbar.copyText.color)
                    shortcut(strings[.copyPromptShortcut], color: Tokens.Toolbar.copyShortcutText)
                }
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
        .help(strings[.copyPromptHelp])
        .accessibilityLabel(strings[.copyPrompt])
        .accessibilityIdentifier(AXID.Toolbar.copyPrompt)
    }

    /// ボタンの中に小さく添えるショートカットの表示。読み上げはツールチップに任せる。
    private func shortcut(_ text: String, color: ColorToken) -> some View {
        Text(text)
            .textStyle(Tokens.Typography.meta)
            .foregroundStyle(color.color)
            .accessibilityHidden(true)
    }
}
