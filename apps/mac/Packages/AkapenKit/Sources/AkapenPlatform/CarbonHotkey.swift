import Carbon
import AkapenCore

/// Carbon の登録を所有する。終了時は unregister を呼んで解放する。
///
/// インスタンスごとに別のホットキー ID を持ち、自分の ID のイベントだけに反応する。
/// 複数のインスタンス（ホットキーと、使えるかを試す登録）を同時に登録できる。
@MainActor public final class CarbonHotkey: HotkeyRegistering {
    /// ホットキー ID の署名（'AKPN'）。
    static let signature: OSType = 0x414b504e

    /// 次に払い出すホットキー ID。
    private static var nextIdentifier: UInt32 = 1

    /// このインスタンスのホットキー ID。インスタンスごとに一意。
    let identifier: UInt32

    private var reference: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (@MainActor () -> Void)?

    public init() {
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
    }

    /// RegisterEventHotKey の失敗を OSStatus として返す。
    public struct RegistrationError: Error {
        public let status: OSStatus
    }

    public func register(_ shortcut: KeyboardShortcut, handler: @escaping @MainActor () -> Void) throws {
        unregister()
        callback = handler
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        let install = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else {
                    return OSStatus(eventNotHandledErr)
                }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else {
                    return OSStatus(eventNotHandledErr)
                }
                let signature = hotKeyID.signature
                let identifier = hotKeyID.id
                return MainActor.assumeIsolated {
                    Unmanaged<CarbonHotkey>.fromOpaque(context)
                        .takeUnretainedValue()
                        .handle(signature: signature, identifier: identifier)
                }
            },
            1,
            &spec,
            context,
            &eventHandler
        )
        guard install == noErr else {
            unregister()
            throw RegistrationError(status: install)
        }
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            Self.carbonModifiers(shortcut.modifiers),
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else {
            unregister()
            throw RegistrationError(status: status)
        }
    }

    public func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        reference = nil
        eventHandler = nil
        callback = nil
    }

    /// 自分の ID のイベントならハンドラーを呼んで `noErr`。ほかのホットキーのイベントは、次のハンドラーへ回す。
    func handle(signature: OSType, identifier: UInt32) -> OSStatus {
        guard signature == Self.signature, identifier == self.identifier, let callback else {
            return OSStatus(eventNotHandledErr)
        }
        callback()
        return noErr
    }

    private static func carbonModifiers(_ modifiers: KeyModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        return result
    }
}
