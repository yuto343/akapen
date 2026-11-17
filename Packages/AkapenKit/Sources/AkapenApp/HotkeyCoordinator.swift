import AkapenCore

/// グローバルなホットキー 2 つ（「枠を描き始める」と「ボタン類の表示切り替え」）の登録を、設定に合わせ続ける。
///
/// - `apply(_:)` で設定を渡すたびに、変わったものだけを登録し直す（設定やセットアップで変えたら、その場で効く）。
/// - キーの記録欄が記録を待っているあいだ（`setSuspended(_:by:)`）は、両方の登録を外す。
///   外さないと、いまのホットキーを押したときに枠を描き始めてしまい、記録欄にキーが届かない。
/// - `canUse(_:for:)` は記録欄に渡す判定（`DECISIONS.md` A8）。そのキーを実際に登録できるかを、試しに登録して確かめる。
/// - 登録に失敗したら、前に登録できていたキーに戻し、`onRegistrationFailed` で知らせる。
@MainActor public final class HotkeyCoordinator {
    /// ホットキーの役。
    public enum Slot: String, CaseIterable, Sendable {
        /// 枠を描き始める（`Settings.hotkey`）。
        case draw
        /// ボタン類の表示を切り替える（`Settings.toolbarShortcut`）。
        case toolbar
    }

    /// 登録を外している理由（記録を待っている記録欄）。
    public enum SuspendReason: Hashable, Sendable {
        case settings
        case setup
    }

    /// いまの登録の様子（`state.json` に書き出す）。
    public struct Status: Equatable, Sendable {
        /// 登録している「枠を描き始める」のキー。
        public var draw: KeyboardShortcut?
        /// 登録している「ボタン類の表示切り替え」のキー。
        public var toolbar: KeyboardShortcut?
        /// 記録欄のために登録を外しているか。
        public var isSuspended: Bool
        /// 直前の登録に失敗した役。
        public var failed: [Slot]
    }

    /// 登録に失敗したとき。役と、登録できなかったキーと、代わりに登録し直したキー（前に登録できていたもの。なければ nil）。
    public var onRegistrationFailed: (@MainActor (Slot, KeyboardShortcut, KeyboardShortcut?) -> Void)?

    private let hotkeys: [Slot: any HotkeyRegistering]
    private let probe: any HotkeyRegistering
    private let handlers: [Slot: @MainActor () -> Void]
    /// 設定が求めるキー。
    private var wanted: [Slot: KeyboardShortcut] = [:]
    /// 最後に登録を試みたキー（成否によらない）。同じ値で何度も登録し直さないために持つ。
    private var attempted: [Slot: KeyboardShortcut?] = [:]
    /// 実際に登録できているキー。
    private var registered: [Slot: KeyboardShortcut] = [:]
    private var failed: Set<Slot> = []
    private var suspendReasons: Set<SuspendReason> = []

    /// - Parameters:
    ///   - draw: 「枠を描き始める」を登録する実装。
    ///   - toolbar: 「ボタン類の表示切り替え」を登録する実装。
    ///   - probe: `canUse(_:for:)` で試しに登録するための実装（試したらすぐ外す）。
    ///   - onDraw: 「枠を描き始める」が押されたとき。
    ///   - onToolbar: 「ボタン類の表示切り替え」が押されたとき。
    public init(
        draw: any HotkeyRegistering,
        toolbar: any HotkeyRegistering,
        probe: any HotkeyRegistering,
        onDraw: @escaping @MainActor () -> Void,
        onToolbar: @escaping @MainActor () -> Void
    ) {
        hotkeys = [.draw: draw, .toolbar: toolbar]
        self.probe = probe
        handlers = [.draw: onDraw, .toolbar: onToolbar]
    }

    /// いまの登録の様子。
    public var status: Status {
        Status(
            draw: registered[.draw],
            toolbar: registered[.toolbar],
            isSuspended: isSuspended,
            failed: Slot.allCases.filter(failed.contains)
        )
    }

    /// 記録欄のために登録を外しているか。
    public var isSuspended: Bool {
        !suspendReasons.isEmpty
    }

    /// 設定に合わせて登録する。変わっていない役は触らない。外しているあいだは、求めるキーを覚えるだけにする。
    public func apply(_ settings: Settings) {
        wanted[.draw] = settings.hotkey
        wanted[.toolbar] = settings.toolbarShortcut
        sync()
    }

    /// 記録欄が記録を待ち始めた（true）・やめた（false）。どれかが待っているあいだは、両方の登録を外す。
    public func setSuspended(_ suspended: Bool, by reason: SuspendReason) {
        if suspended {
            suspendReasons.insert(reason)
        } else {
            suspendReasons.remove(reason)
        }
        sync()
    }

    /// 記録欄で記録したキーを、その役に使えるか（実際に登録できるか）。記録欄に渡す判定（`DECISIONS.md` A8）。
    ///
    /// もう 1 つの役が使っているキーは使えない。それ以外は、試しに登録して確かめ、すぐに外す。
    public func canUse(_ shortcut: KeyboardShortcut, for slot: Slot) -> Bool {
        let other: Slot = slot == .draw ? .toolbar : .draw
        if wanted[other] == shortcut || registered[other] == shortcut {
            return false
        }
        if registered[slot] == shortcut {
            return true
        }
        do {
            try probe.register(shortcut) {}
        } catch {
            return false
        }
        probe.unregister()
        return true
    }

    /// すべての登録を外す（終了するとき）。
    public func unregisterAll() {
        for slot in Slot.allCases {
            hotkeys[slot]?.unregister()
        }
        probe.unregister()
        registered = [:]
        attempted = [:]
    }

    // MARK: - 下請け

    private func sync() {
        if isSuspended {
            for slot in Slot.allCases where registered[slot] != nil {
                hotkeys[slot]?.unregister()
            }
            registered = [:]
            attempted = [:]
            return
        }
        for slot in Slot.allCases {
            update(slot)
        }
    }

    private func update(_ slot: Slot) {
        let shortcut = wanted[slot]
        if let previous = attempted[slot], previous == shortcut {
            return
        }
        attempted[slot] = .some(shortcut)
        guard let hotkey = hotkeys[slot] else {
            return
        }
        let previous = registered[slot]
        guard let shortcut else {
            hotkey.unregister()
            registered[slot] = nil
            failed.remove(slot)
            return
        }
        do {
            try hotkey.register(shortcut, handler: handler(for: slot))
            registered[slot] = shortcut
            failed.remove(slot)
        } catch {
            registered[slot] = nil
            failed.insert(slot)
            var restored: KeyboardShortcut?
            if let previous, previous != shortcut, (try? hotkey.register(previous, handler: handler(for: slot))) != nil {
                registered[slot] = previous
                restored = previous
            }
            onRegistrationFailed?(slot, shortcut, restored)
        }
    }

    private func handler(for slot: Slot) -> @MainActor () -> Void {
        handlers[slot] ?? {}
    }
}
