import Carbon
import AkapenCore

/// Carbon の登録を所有する。終了時は unregister を呼んで解放する。
@MainActor public final class CarbonHotkey: HotkeyRegistering {
    private var reference: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (@MainActor () -> Void)?
    public init() {}
    /// RegisterEventHotKey の失敗を OSStatus として返す。
    public struct RegistrationError: Error { public let status: OSStatus }
    public func register(_ shortcut: KeyboardShortcut, handler: @escaping @MainActor () -> Void) throws {
        unregister()
        callback = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let install = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<CarbonHotkey>.fromOpaque(context).takeUnretainedValue().callback?()
            }
            return noErr
        }, 1, &spec, context, &eventHandler)
        guard install == noErr else { unregister(); throw RegistrationError(status: install) }
        var modifiers: UInt32 = 0
        if shortcut.modifiers.contains(.command) { modifiers |= UInt32(cmdKey) }
        if shortcut.modifiers.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if shortcut.modifiers.contains(.option) { modifiers |= UInt32(optionKey) }
        if shortcut.modifiers.contains(.control) { modifiers |= UInt32(controlKey) }
        let status = RegisterEventHotKey(shortcut.keyCode, modifiers, EventHotKeyID(signature: 0x414b504e, id: 1), GetApplicationEventTarget(), 0, &reference)
        guard status == noErr else { unregister(); throw RegistrationError(status: status) }
    }
    public func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        reference = nil; eventHandler = nil; callback = nil
    }
}
