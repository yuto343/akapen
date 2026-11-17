import Testing
import AkapenApp
import AkapenCore

/// ホットキーの登録を設定に合わせ続けること。OS には触らず、偽の登録で確かめる。
@MainActor
@Suite
struct HotkeyCoordinatorTests {
    private let commandSemicolon = KeyboardShortcut()
    private let controlOptionK = KeyboardShortcut(keyCode: 40, modifiers: [.control, .option])
    private let commandShiftB = KeyboardShortcut(keyCode: 11, modifiers: [.command, .shift])

    private func settings(hotkey: KeyboardShortcut? = nil, toolbar: KeyboardShortcut? = nil) -> Settings {
        var settings = Settings()
        if let hotkey {
            settings.hotkey = hotkey
        }
        settings.toolbarShortcut = toolbar
        return settings
    }

    @Test
    func registersHotkeyAndOptionalToolbarShortcut() {
        let harness = Harness()
        harness.coordinator.apply(settings())
        #expect(harness.draw.current == commandSemicolon)
        #expect(harness.toolbar.current == nil)
        #expect(harness.coordinator.status.draw == commandSemicolon)
        #expect(harness.coordinator.status.toolbar == nil)
        harness.coordinator.apply(settings(toolbar: commandShiftB))
        #expect(harness.toolbar.current == commandShiftB)
        harness.draw.fire()
        harness.toolbar.fire()
        #expect(harness.events == ["draw", "toolbar"])
    }

    @Test
    func reregistersOnlyWhatChanged() {
        let harness = Harness()
        harness.coordinator.apply(settings())
        harness.coordinator.apply(settings())
        #expect(harness.draw.registerCount == 1)
        harness.coordinator.apply(settings(hotkey: controlOptionK))
        #expect(harness.draw.registerCount == 2)
        #expect(harness.draw.current == controlOptionK)
        #expect(harness.toolbar.registerCount == 0)
        // 割り当てを外すと、登録も外す。
        harness.coordinator.apply(settings(hotkey: controlOptionK, toolbar: commandShiftB))
        harness.coordinator.apply(settings(hotkey: controlOptionK, toolbar: nil))
        #expect(harness.toolbar.current == nil)
        harness.toolbar.fire()
        #expect(harness.events.isEmpty)
    }

    @Test
    func suspendsWhileRecording() {
        let harness = Harness()
        harness.coordinator.apply(settings(toolbar: commandShiftB))
        harness.coordinator.setSuspended(true, by: .settings)
        #expect(harness.draw.current == nil)
        #expect(harness.toolbar.current == nil)
        #expect(harness.coordinator.status.isSuspended)
        // 記録の途中で設定が変わっても、外したまま。
        harness.coordinator.apply(settings(hotkey: controlOptionK, toolbar: commandShiftB))
        #expect(harness.draw.current == nil)
        harness.coordinator.setSuspended(true, by: .setup)
        harness.coordinator.setSuspended(false, by: .settings)
        #expect(harness.draw.current == nil)
        harness.coordinator.setSuspended(false, by: .setup)
        #expect(harness.draw.current == controlOptionK)
        #expect(harness.toolbar.current == commandShiftB)
        #expect(!harness.coordinator.status.isSuspended)
    }

    @Test
    func canUseProbesRealRegistration() {
        let harness = Harness()
        harness.coordinator.apply(settings(toolbar: commandShiftB))
        harness.coordinator.setSuspended(true, by: .settings)
        #expect(harness.coordinator.canUse(controlOptionK, for: .draw))
        #expect(harness.probe.current == nil)
        #expect(harness.probe.registerCount == 1)
        // もう 1 つの役が使っているキーは使えない。
        #expect(!harness.coordinator.canUse(commandShiftB, for: .draw))
        #expect(!harness.coordinator.canUse(commandSemicolon, for: .toolbar))
        // 登録できないキー（ほかのアプリとぶつかる）は使えない。
        harness.probe.failing = [controlOptionK]
        #expect(!harness.coordinator.canUse(controlOptionK, for: .draw))
    }

    @Test
    func failedRegistrationRestoresPrevious() {
        let harness = Harness()
        var failures: [(HotkeyCoordinator.Slot, KeyboardShortcut, KeyboardShortcut?)] = []
        harness.coordinator.onRegistrationFailed = { slot, shortcut, restored in
            failures.append((slot, shortcut, restored))
        }
        harness.coordinator.apply(settings())
        harness.draw.failing = [controlOptionK]
        harness.coordinator.apply(settings(hotkey: controlOptionK))
        #expect(harness.draw.current == commandSemicolon)
        #expect(failures.count == 1)
        #expect(failures.first?.0 == .draw)
        #expect(failures.first?.1 == controlOptionK)
        #expect(failures.first?.2 == commandSemicolon)
        #expect(harness.coordinator.status.failed == [.draw])
        // 同じ値では登録をやり直さない。
        harness.coordinator.apply(settings(hotkey: controlOptionK))
        #expect(failures.count == 1)
        // 設定が戻れば、失敗の印も消える。
        harness.coordinator.apply(settings())
        #expect(harness.coordinator.status.failed.isEmpty)
        #expect(harness.draw.current == commandSemicolon)
    }

    @Test
    func unregisterAllOnQuit() {
        let harness = Harness()
        harness.coordinator.apply(settings(toolbar: commandShiftB))
        harness.coordinator.unregisterAll()
        #expect(harness.draw.current == nil)
        #expect(harness.toolbar.current == nil)
        #expect(harness.coordinator.status.draw == nil)
    }
}

/// 偽の登録と、押されたときの記録。
@MainActor private final class Harness {
    let draw = FakeHotkey()
    let toolbar = FakeHotkey()
    let probe = FakeHotkey()
    private(set) var events: [String] = []
    private(set) var coordinator: HotkeyCoordinator!

    init() {
        coordinator = HotkeyCoordinator(
            draw: draw,
            toolbar: toolbar,
            probe: probe,
            onDraw: { [weak self] in
                self?.events.append("draw")
            },
            onToolbar: { [weak self] in
                self?.events.append("toolbar")
            }
        )
    }
}

/// 登録を覚えるだけの `HotkeyRegistering`。`failing` のキーは登録に失敗する。
@MainActor private final class FakeHotkey: HotkeyRegistering {
    struct Failure: Error {}

    private(set) var current: KeyboardShortcut?
    private(set) var registerCount = 0
    var failing: [KeyboardShortcut] = []
    private var handler: (@MainActor () -> Void)?

    func register(_ shortcut: KeyboardShortcut, handler: @escaping @MainActor () -> Void) throws {
        unregister()
        registerCount += 1
        guard !failing.contains(shortcut) else {
            throw Failure()
        }
        current = shortcut
        self.handler = handler
    }

    func unregister() {
        current = nil
        handler = nil
    }

    func fire() {
        handler?()
    }
}
