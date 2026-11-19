import AkapenCore

/// グローバルなホットキー（ボタン類を出して枠を描き始める・隠す、のトグル）の登録を、設定に合わせ続ける。
///
/// - `apply(_:)` で設定を渡すたびに、変わっていれば登録し直す（設定やセットアップで変えたら、その場で効く）。
/// - キーの記録欄が記録を待っているあいだ（`setSuspended(_:by:)`）は、登録を外す。
///   外さないと、いまのホットキーを押したときにボタン類が出てしまい、記録欄にキーが届かない。
/// - `canUse(_:for:)` は記録欄に渡す判定（`DECISIONS.md` A8）。そのキーを実際に登録できるかを、試しに登録して確かめる。
/// - 登録に失敗したら、前に登録できていたキーに戻し、`onRegistrationFailed` で知らせる。
///
/// ボタン類が出ているあいだの `⌘C` / `⌘L` は、グローバルには登録しない（キーになっているパネルが受ける）。
@MainActor public final class HotkeyCoordinator {
    /// ホットキーの役。
    public enum Slot: String, CaseIterable, Sendable {
        /// ボタン類を出して枠を描き始める・隠す（`Settings.hotkey`）。
        case draw
    }

    /// 登録を外している理由（記録を待っている記録欄）。
    public enum SuspendReason: Hashable, Sendable {
        case settings
        case setup
    }

    /// いまの登録の様子（`state.json` に書き出す）。
    public struct Status: Equatable, Sendable {
        /// 登録しているホットキー。
        public var draw: KeyboardShortcut?
        /// 記録欄のために登録を外しているか。
        public var isSuspended: Bool
        /// 直前の登録に失敗した役。
        public var failed: [Slot]
    }

    /// 登録に失敗したとき。役と、登録できなかったキーと、代わりに登録し直したキー（前に登録できていたもの。なければ nil）。
    public var onRegistrationFailed: (@MainActor (Slot, KeyboardShortcut, KeyboardShortcut?) -> Void)?

    private let hotkey: any HotkeyRegistering
    private let probe: any HotkeyRegistering
    private let handler: @MainActor () -> Void
    /// 設定が求めるキー。
    private var wanted: KeyboardShortcut?
    /// 最後に登録を試みたキー（成否によらない）。同じ値で何度も登録し直さないために持つ。
    private var attempted: KeyboardShortcut?
    /// 実際に登録できているキー。
    private var registered: KeyboardShortcut?
    private var failed = false
    private var suspendReasons: Set<SuspendReason> = []

    /// - Parameters:
    ///   - draw: ホットキーを登録する実装。
    ///   - probe: `canUse(_:for:)` で試しに登録するための実装（試したらすぐ外す）。
    ///   - onDraw: ホットキーが押されたとき。
    public init(
        draw: any HotkeyRegistering,
        probe: any HotkeyRegistering,
        onDraw: @escaping @MainActor () -> Void
    ) {
        hotkey = draw
        self.probe = probe
        handler = onDraw
    }

    /// いまの登録の様子。
    public var status: Status {
        Status(draw: registered, isSuspended: isSuspended, failed: failed ? [.draw] : [])
    }

    /// 記録欄のために登録を外しているか。
    public var isSuspended: Bool {
        !suspendReasons.isEmpty
    }

    /// 設定に合わせて登録する。変わっていなければ触らない。外しているあいだは、求めるキーを覚えるだけにする。
    public func apply(_ settings: Settings) {
        wanted = settings.hotkey
        sync()
    }

    /// 記録欄が記録を待ち始めた（true）・やめた（false）。どれかが待っているあいだは、登録を外す。
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
    /// 試しに登録して確かめ、すぐに外す。
    public func canUse(_ shortcut: KeyboardShortcut, for slot: Slot) -> Bool {
        if registered == shortcut {
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
        hotkey.unregister()
        probe.unregister()
        registered = nil
        attempted = nil
    }

    // MARK: - 下請け

    private func sync() {
        if isSuspended {
            if registered != nil {
                hotkey.unregister()
            }
            registered = nil
            attempted = nil
            return
        }
        update()
    }

    private func update() {
        guard let shortcut = wanted, attempted != shortcut else {
            return
        }
        attempted = shortcut
        let previous = registered
        do {
            try hotkey.register(shortcut, handler: handler)
            registered = shortcut
            failed = false
        } catch {
            registered = nil
            failed = true
            var restored: KeyboardShortcut?
            if let previous, previous != shortcut, (try? hotkey.register(previous, handler: handler)) != nil {
                registered = previous
                restored = previous
            }
            onRegistrationFailed?(.draw, shortcut, restored)
        }
    }
}
