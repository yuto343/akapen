import AppKit
import SwiftUI
import Testing
import AkapenCore
@testable import AkapenUI

/// メニューの見出し・終了確認・設定・セットアップを、いくつかの状態で `build/ui-snapshots/<言語>/` に PNG として書き出す。
///
/// 書き出した PNG は、Paper の画像（`.director/design/img/app-05.png`〜`app-09.png`）と人が見比べる。画素の一致は確かめない。
/// 設定とセットアップは、実際のウィンドウをタイトルバーごと描く（信号ボタンは、アプリが前面にないので灰色になる）。
/// Paper と同じ 1280×800 の画面に並べたもの（`scene-app-0N.png`）と、Paper の画像と横に並べたもの（`compare/`）も書き出す。
@Suite(.serialized)
@MainActor
struct WindowSnapshotTests {
    nonisolated static let languages: [Language] = [.en, .ja]

    private let optionCommandK = AkapenCore.KeyboardShortcut(keyCode: UInt32(TestKey.k), modifiers: [.option, .command])

    /// 影が見えるように、部品のまわりに余白と背景を付ける。
    private func framed<V: View>(_ view: V) -> some View {
        view
            .padding(Tokens.Spacing.s16)
            .background(Color(red: 0.90, green: 0.91, blue: 0.93))
    }

    private func settings(_ language: Language) -> AkapenCore.Settings {
        var settings = AkapenCore.Settings()
        settings.language = language
        return settings
    }

    // MARK: - メニュー（App 05）

    @Test(arguments: languages)
    func menuHeaderStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        for count in [0, 1, 2] {
            let menu = MenuMock(header: MenuHeaderView(annotationCount: count, strings: strings), strings: strings)
            try Snapshot.write(try await Snapshot.render(framed(menu)), to: "\(folder)/menu-header-\(count).png")
        }
    }

    // MARK: - 終了の確認（App 09）

    @Test(arguments: languages)
    func quitConfirmStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        for count in [1, 2] {
            let view = QuitConfirmView(annotationCount: count, strings: strings, onQuit: {}, onCancel: {})
            try Snapshot.write(try await Snapshot.render(framed(view)), to: "\(folder)/quit-\(count).png")
        }
    }

    // MARK: - 設定（App 06）

    private func settingsController(
        _ settings: AkapenCore.Settings,
        canUseHotkey: @escaping @MainActor (AkapenCore.KeyboardShortcut) -> Bool = { _ in true }
    ) -> SettingsController {
        let sink = SettingsSink(settings)
        let controller = SettingsController(
            settings: {
                sink.settings
            },
            send: sink.send,
            canUseHotkey: canUseHotkey,
            shortcutText: .ansi,
            activatesApp: false
        )
        controller.show()
        return controller
    }

    private func renderSettings(_ controller: SettingsController) async throws -> NSBitmapImageRep {
        defer { controller.close() }
        return try await Snapshot.renderWindow(controller.window)
    }

    @Test(arguments: languages)
    func settingsStates(language: Language) async throws {
        let folder = language.rawValue
        let base = settings(language)

        let defaultRep = try await renderSettings(settingsController(base))
        try Snapshot.write(defaultRep, to: "\(folder)/settings-default.png")

        let recording = settingsController(base)
        recording.form.hotkey.beginRecording()
        try Snapshot.write(try await renderSettings(recording), to: "\(folder)/settings-recording.png")

        var assignedSettings = base
        assignedSettings.hotkey = optionCommandK
        assignedSettings.confirmKey = .commandEnter
        assignedSettings.imageRetentionDays = 365
        try Snapshot.write(try await renderSettings(settingsController(assignedSettings)), to: "\(folder)/settings-assigned.png")

        let unavailable = settingsController(base, canUseHotkey: { _ in
            false
        })
        unavailable.form.hotkey.beginRecording()
        unavailable.form.hotkey.handle(keyCode: TestKey.k, flags: [.command, .option])
        try Snapshot.write(try await renderSettings(unavailable), to: "\(folder)/settings-unavailable.png")
    }

    // MARK: - セットアップ（App 07・08）

    private func setupController(_ settings: AkapenCore.Settings, granted: Bool) -> SetupController {
        let sink = SettingsSink(settings)
        let controller = SetupController(
            settings: {
                sink.settings
            },
            send: sink.send,
            permission: FakePermission(isGranted: granted),
            canUseHotkey: { _ in true },
            shortcutText: .ansi,
            pollInterval: .seconds(60),
            activatesApp: false
        )
        controller.show()
        return controller
    }

    private func renderSetup(_ controller: SetupController) async throws -> NSBitmapImageRep {
        defer { controller.close() }
        return try await Snapshot.renderWindow(controller.window)
    }

    @Test(arguments: languages)
    func setupStates(language: Language) async throws {
        let folder = language.rawValue
        let base = settings(language)

        try Snapshot.write(try await renderSetup(setupController(base, granted: false)), to: "\(folder)/setup-hotkey.png")

        let recording = setupController(base, granted: false)
        recording.flow.hotkey.beginRecording()
        try Snapshot.write(try await renderSetup(recording), to: "\(folder)/setup-hotkey-recording.png")

        let waiting = setupController(base, granted: false)
        waiting.flow.goNext()
        try Snapshot.write(try await renderSetup(waiting), to: "\(folder)/setup-permission-waiting.png")

        let granted = setupController(base, granted: true)
        granted.flow.goNext()
        try Snapshot.write(try await renderSetup(granted), to: "\(folder)/setup-permission-granted.png")
    }

    // MARK: - Paper と同じ配置の画面

    @Test(arguments: languages)
    func scenes(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        let screen = FakeScreens.primary
        let base = settings(language)

        let menuScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            StatusItemMock()
                .layoutValue(key: ScenePlacement.self, value: .at(x: 1123, y: 2))
            MenuMock(header: MenuHeaderView(annotationCount: 2, strings: strings), strings: strings)
                .layoutValue(key: ScenePlacement.self, value: .at(x: 1000, y: 32))
        }
        let menuRep = try await Snapshot.render(menuScene)
        try Snapshot.write(menuRep, to: "\(folder)/scene-app-05.png")

        let settingsRep = try await renderSettings(settingsController(base))
        let settingsScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            WindowSnapshot(rep: settingsRep)
                .layoutValue(key: ScenePlacement.self, value: .at(x: 330, y: 84))
        }
        let settingsSceneRep = try await Snapshot.render(settingsScene)
        try Snapshot.write(settingsSceneRep, to: "\(folder)/scene-app-06.png")

        let hotkeyRep = try await renderSetup(setupController(base, granted: false))
        let hotkeyScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            WindowSnapshot(rep: hotkeyRep)
                .layoutValue(key: ScenePlacement.self, value: .at(x: 360, y: 120))
        }
        let hotkeySceneRep = try await Snapshot.render(hotkeyScene)
        try Snapshot.write(hotkeySceneRep, to: "\(folder)/scene-app-07.png")

        let waiting = setupController(base, granted: false)
        waiting.flow.goNext()
        let permissionRep = try await renderSetup(waiting)
        let permissionScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            WindowSnapshot(rep: permissionRep)
                .layoutValue(key: ScenePlacement.self, value: .at(x: 360, y: 120))
        }
        let permissionSceneRep = try await Snapshot.render(permissionScene)
        try Snapshot.write(permissionSceneRep, to: "\(folder)/scene-app-08.png")

        let quitScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            QuitConfirmOverlay(screen: screen, annotationCount: 2, strings: strings, onQuit: {}, onCancel: {})
                .layoutValue(key: ScenePlacement.self, value: .at(x: 0, y: 28))
        }
        let quitRep = try await Snapshot.render(quitScene)
        try Snapshot.write(quitRep, to: "\(folder)/scene-app-09.png")

        if language == .en {
            try Snapshot.writeComparison(paper: "app-05.png", ours: menuRep, to: "compare/app-05.png")
            try Snapshot.writeComparison(paper: "app-06.png", ours: settingsSceneRep, to: "compare/app-06.png")
            try Snapshot.writeComparison(paper: "app-07.png", ours: hotkeySceneRep, to: "compare/app-07.png")
            try Snapshot.writeComparison(paper: "app-08.png", ours: permissionSceneRep, to: "compare/app-08.png")
            try Snapshot.writeComparison(paper: "app-09.png", ours: quitRep, to: "compare/app-09.png")
        }
    }
}

/// メニューの見出しを、Paper の App 05 のメニューの形に並べたもの（見比べ用）。
///
/// 本物のメニューは標準の `NSMenu` で、見出しのほかはシステムが描く（`DECISIONS.md` 9・14）。ここでは見出しの寸法を見比べるために、
/// 資料の値でメニューの形と項目を描き足している（選択中の行の赤は資料の絵のとおりで、本物はシステムの選択色になる）。
private struct MenuMock: View {
    let header: MenuHeaderView
    let strings: UIStrings

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            row(strings[.menuSettings], shortcut: "⌘,", selected: true)
                .padding(.top, Tokens.Menu.dividerMargin)
            divider
                .padding(.vertical, Tokens.Menu.dividerMargin)
            row(strings[.menuQuit], shortcut: "⌘Q", selected: false)
        }
        .padding(Tokens.Menu.padding)
        .frame(width: Tokens.Menu.width)
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Menu.background.color))
        .boxShadow(Tokens.Menu.shadows, cornerRadius: Tokens.Radius.media)
        .fixedSize()
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.Menu.divider.color)
            .frame(height: Tokens.Stroke.hairline)
    }

    private func row(_ title: String, shortcut: String, selected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(selected ? Tokens.Menu.selectionText.color : Tokens.Menu.itemText.color)
            Spacer()
            Text(shortcut)
                .foregroundStyle(selected ? Tokens.Menu.selectionShortcut.color : Tokens.Menu.itemShortcut.color)
        }
        .textStyle(Tokens.Typography.menuItem)
        .padding(.horizontal, Tokens.Menu.itemPaddingX)
        .frame(height: Tokens.Menu.itemHeight)
        .background(RoundedBox(cornerRadius: Tokens.Radius.item).fill(selected ? Tokens.Menu.selection.color : .clear))
    }
}

/// メニューバーのアイコンが押された状態（見比べ用。本物はシステムが描く）。
private struct StatusItemMock: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedBox(cornerRadius: Tokens.Radius.statusItem)
                .fill(Tokens.Menu.statusPressed.color)
                .frame(width: Tokens.Menu.statusPressedWidth, height: Tokens.Menu.statusPressedHeight)
            if let icon = MenuBarIconImage.make() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Tokens.Menu.statusIconWidth, height: Tokens.Menu.statusIconHeight)
            }
        }
        .fixedSize()
    }
}
