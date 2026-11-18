/// macOS 仮想キーコードと修飾キー。既定値は ANSI の 6 と Command + Shift（`⌘⇧6`）。
public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: KeyModifiers

    /// キーコードは Carbon の仮想キーコード。修飾キーは独自のビット集合。
    public init(keyCode: UInt32 = 22, modifiers: KeyModifiers = [.command, .shift]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}
