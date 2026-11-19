import SwiftUI
import AkapenAXID

/// 初回のセットアップのウィンドウの中身（App 07・08）。1 ページ目はホットキー、2 ページ目は画面収録の許可。
///
/// 表示に要る値と操作の受け口は `SetupFlow` が持つ。`SessionModel` にも OS にも触らない。
struct SetupView: View {
    let flow: SetupFlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let strings = UIStrings(language: flow.language)
        VStack(spacing: 0) {
            Color.clear
                .frame(height: Tokens.Setup.titleBarHeight)
            VStack(spacing: Tokens.Setup.gap) {
                AppIconView(size: Tokens.Setup.iconSize)
                // 2 つのページは重ねて置き、切り替えのあいだだけ両方を出す（縦に並べてウィンドウが伸びないように）。
                ZStack(alignment: .top) {
                    page(strings)
                        .id(flow.page)
                        .transition(pageTransition)
                }
                .animation(Tokens.Motion.panelSpring, value: flow.page)
            }
            .padding(.top, Tokens.Setup.bodyPaddingTop)
            .padding(.horizontal, Tokens.Setup.bodyPaddingX)
            .padding(.bottom, Tokens.Setup.bodyPaddingBottom)
        }
        .frame(width: Tokens.Setup.width)
        .glassSurface(radius: Tokens.Glass.setupRadius, tint: Tokens.Glass.window)
        .clipShape(RoundedBox(cornerRadius: Tokens.Glass.setupRadius))
        .lightAppearance()
    }

    @ViewBuilder private func page(_ strings: UIStrings) -> some View {
        VStack(spacing: Tokens.Setup.gap) {
            switch flow.page {
            case .hotkey:
                hotkeyPage(strings)
            case .permission:
                permissionPage(strings)
            }
        }
    }

    /// ページの切り替え。進むときは右から、戻るときは左から、ずらしながら出す。消えるページは不透明度だけで消す。
    private var pageTransition: AnyTransition {
        let shift = reduceMotion ? 0 : (flow.movedForward ? Tokens.Motion.pageShift : -Tokens.Motion.pageShift)
        return .asymmetric(
            insertion: .offset(x: shift).combined(with: .opacity),
            removal: .opacity.animation(Tokens.Motion.exitAnimation)
        )
    }

    private func step(_ strings: UIStrings) -> String {
        strings.setupStep(current: flow.page.rawValue, total: SetupFlow.Page.allCases.count)
    }

    // MARK: - 1 ページ目

    @ViewBuilder private func hotkeyPage(_ strings: UIStrings) -> some View {
        SetupHeading(
            step: step(strings),
            title: strings[.setupHotkeyTitle],
            message: strings[.setupHotkeyBody]
        )
        SetupKeyRecorder(recorder: flow.hotkey, shortcutText: flow.shortcutText, strings: strings)
        SetupConflictNote(text: strings[.setupConflictNote])
        footer {
            primaryButton(strings)
        }
    }

    // MARK: - 2 ページ目

    @ViewBuilder private func permissionPage(_ strings: UIStrings) -> some View {
        SetupHeading(
            step: step(strings),
            title: strings[.setupPermissionTitle],
            message: strings.setupPermissionBody(path: flow.imagesPath)
        )
        VStack(spacing: 0) {
            SetupStepRow(number: 1, text: strings[.setupStepOpenSettings], showsDivider: true) {
                EmptyView()
            }
            SetupStepRow(number: 2, text: strings[.setupStepTurnOn], showsDivider: true) {
                SetupSwitchPicture()
            }
            SetupStepRow(number: 3, text: strings[.setupStepComeBack], showsDivider: false) {
                Text(strings[flow.permissionStatus])
                    .textStyle(Tokens.Typography.setupHint)
                    .foregroundStyle(flow.isGranted ? Tokens.Setup.granted.color : Tokens.Setup.waiting.color)
                    .accessibilityIdentifier(AXID.Setup.permission)
            }
        }
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Setup.stepsBackground.color))
        footer {
            HStack(spacing: Tokens.Setup.buttonGap) {
                SetupSecondaryButton(title: strings[.setupBack], identifier: AXID.Setup.back) {
                    flow.goBack()
                }
                primaryButton(strings)
            }
        }
    }

    // MARK: - 下の行

    /// 主ボタン（`flow.primaryAction` のとおり）。
    @ViewBuilder private func primaryButton(_ strings: UIStrings) -> some View {
        switch flow.primaryAction {
        case .next:
            SetupPrimaryButton(title: strings[.setupContinue], glyph: .arrowRight, identifier: AXID.Setup.next) {
                flow.goNext()
            }
        case .openSystemSettings:
            SetupPrimaryButton(
                title: strings[.setupOpenSystemSettings],
                glyph: .arrowUpRight,
                identifier: AXID.Setup.requestPermission
            ) {
                flow.openSystemSettings()
            }
        case .done:
            SetupPrimaryButton(title: strings[.setupDone], glyph: .check, identifier: AXID.Setup.done) {
                flow.done()
            }
        }
    }

    /// ページの点と、右端のボタン。
    private func footer<Buttons: View>(@ViewBuilder buttons: () -> Buttons) -> some View {
        HStack {
            SetupPageDots(current: flow.page.rawValue, count: SetupFlow.Page.allCases.count)
            Spacer(minLength: Tokens.Spacing.s2)
            buttons()
        }
        .padding(.top, Tokens.Setup.footerPaddingTop)
    }
}
