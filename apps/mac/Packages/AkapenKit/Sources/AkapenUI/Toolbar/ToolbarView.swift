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

/// 画面下のボタン類（「すべて消す」「List」「Copy prompt」。Paper の App 01〜03）。
///
/// ボタン類が出ているあいだは、いつでも枠を描ける状態なので「+」は置かない。
/// ボタンには、出ているあいだに使えるショートカット（`⌘` `⌫` / `⌘` `L` / `⌘` `C`）をキーのチップで添え、ツールチップでも示す。
/// 件数のバッジは「List」の右上の角に重ねる。
public struct ToolbarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let state: ToolbarState
    private let strings: UIStrings
    private let onList: () -> Void
    private let onCopy: () -> Void
    private let onClear: () -> Void

    /// 表示に要る値と、押されたときのコールバックを受け取る。
    public init(
        state: ToolbarState,
        strings: UIStrings,
        onList: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void = {}
    ) {
        self.state = state
        self.strings = strings
        self.onList = onList
        self.onCopy = onCopy
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: Tokens.Toolbar.gap) {
            clearButton
                .staggeredEntrance(delay: 0)
            listButton
                .staggeredEntrance(delay: Tokens.Motion.buttonDelay)
            copyButton
                .staggeredEntrance(delay: Tokens.Motion.buttonDelay * 2)
        }
        .padding(Tokens.Toolbar.padding)
        .glassBar()
        .boxShadow(Tokens.Toolbar.shadows, cornerRadius: Tokens.Radius.pill)
        .fixedSize()
        .lightAppearance()
    }

    private var clearButton: some View {
        Button(action: onClear) {
            HStack(spacing: Tokens.Toolbar.listGap) {
                IconView(
                    glyph: .trash,
                    size: Tokens.Toolbar.clearIconSize,
                    color: Tokens.Toolbar.clearIconColor,
                    lineWidth: Tokens.Toolbar.clearIconStroke
                )
                KeyChipsView(keys: strings.clearShortcutKeys, tone: .light)
            }
            .padding(.horizontal, Tokens.Toolbar.listPaddingX)
            .frame(height: Tokens.Toolbar.controlHeight)
            .background(Capsule().fill(Tokens.Glass.white))
            .boxShadow(Tokens.Glass.pillShadow, cornerRadius: Tokens.Radius.pill)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .disabled(!state.canCopy)
        .help(strings[.clearAllHelp])
        .accessibilityLabel(strings[.clearAll])
        .accessibilityIdentifier(AXID.Toolbar.clear)
    }

    private var listButton: some View {
        Button(action: onList) {
            HStack(spacing: Tokens.Toolbar.listGap) {
                IconView(
                    glyph: .list,
                    size: Tokens.Toolbar.iconSize,
                    color: state.isListOpen ? Tokens.Palette.cleanBackground : Tokens.Toolbar.iconColor,
                    lineWidth: Tokens.Stroke.listIcon
                )
                HStack(spacing: Tokens.Toolbar.shortcutGap) {
                    Text(strings[.list])
                        .textStyle(Tokens.Typography.control)
                        .foregroundStyle(state.isListOpen ? Tokens.Palette.cleanBackground.color : Tokens.Toolbar.labelColor.color)
                    KeyChipsView(keys: strings.listShortcutKeys, tone: state.isListOpen ? .dark : .light)
                }
            }
            .padding(.horizontal, Tokens.Toolbar.listPaddingX)
            .frame(height: Tokens.Toolbar.controlHeight)
            .background(Capsule().fill(state.isListOpen ? Tokens.Glass.ink : Tokens.Glass.white))
            .boxShadow(state.isListOpen ? Tokens.Glass.inkShadow : Tokens.Glass.pillShadow, cornerRadius: Tokens.Radius.pill)
            .insetOutline(
                Tokens.ExtraColor.transparent,
                width: Tokens.Stroke.emphasis,
                cornerRadius: Tokens.Radius.pill
            )
            .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.panelSpring, value: state.isListOpen)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .overlay(alignment: .topTrailing) {
            ZStack {
                if state.showsBadge {
                    badge
                        .transition(.scale(scale: reduceMotion ? 1 : 0).combined(with: .opacity))
                }
            }
            .offset(x: Tokens.Toolbar.badgeOverhang, y: -Tokens.Toolbar.badgeOverhang)
            .allowsHitTesting(false)
            .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.panelSpring, value: state.annotationCount)
        }
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
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(state.annotationCount)))
            .phaseAnimator([false, true, false], trigger: state.annotationCount) { content, expanded in
                content.scaleEffect(expanded && !reduceMotion ? Tokens.Motion.badgePop : 1)
            } animation: { _ in
                reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.pressSpring
            }
            .padding(.horizontal, Tokens.Toolbar.badgePaddingX)
            .frame(minWidth: Tokens.Toolbar.badgeSize)
            .frame(height: Tokens.Toolbar.badgeSize)
            .background(Capsule().fill(Tokens.Glass.red))
            .background(
                Capsule()
                    .fill(Tokens.Toolbar.badgeRing.color)
                    .padding(-Tokens.Toolbar.badgeRingWidth)
            )
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            HStack(spacing: Tokens.Toolbar.copyGap) {
                IconView(
                    glyph: .copy,
                    size: Tokens.Toolbar.copyIconSize,
                    color: Tokens.Toolbar.copyIconColor,
                    lineWidth: Tokens.Stroke.copyIcon
                )
                .frame(width: Tokens.Toolbar.copyCircleSize, height: Tokens.Toolbar.copyCircleSize)
                .background(Circle().fill(Tokens.Glass.red))
                .boxShadow(Tokens.Glass.redShadow, cornerRadius: Tokens.Radius.pill)
                HStack(spacing: Tokens.Toolbar.shortcutGap) {
                    Text(strings[.copyPrompt])
                        .textStyle(Tokens.Typography.control)
                        .foregroundStyle(state.isListOpen ? Tokens.Palette.ink.color : Tokens.Toolbar.copyText.color)
                    KeyChipsView(keys: strings.copyPromptShortcutKeys, tone: state.isListOpen ? .light : .dark)
                }
            }
            .padding(.leading, Tokens.Toolbar.copyPaddingLeading)
            .padding(.trailing, Tokens.Toolbar.copyPaddingTrailing)
            .frame(height: Tokens.Toolbar.controlHeight)
            .background(Capsule().fill(state.isListOpen ? Tokens.Glass.white : Tokens.Glass.ink))
            .boxShadow(state.isListOpen ? Tokens.Glass.pillShadow : Tokens.Glass.inkShadow, cornerRadius: Tokens.Radius.pill)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .disabled(!state.canCopy)
        .help(strings[.copyPromptHelp])
        .accessibilityLabel(strings[.copyPrompt])
        .accessibilityIdentifier(AXID.Toolbar.copyPrompt)
    }
}
