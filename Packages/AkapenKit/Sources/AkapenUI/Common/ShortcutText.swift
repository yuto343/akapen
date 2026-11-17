import AppKit
import Carbon.HIToolbox
import AkapenCore

/// キーコードから、修飾キーなしでそのキーを押したときの文字を引く。
///
/// 表示用の文字はキーボードの配列で変わる（JIS 配列と US 配列で、同じキーコードの文字が違う）。
/// テストでは配列に左右されないように、決まった表（`ANSIKeyNames`）に差し替える。
@MainActor protocol KeyNameProviding {
    /// 修飾キーなしでそのキーを押したときの文字。分からなければ nil。
    func character(forKeyCode keyCode: UInt32) -> String?
}

/// いま使っているキーボードの配列（ASCII を打てる配列）で引く。引けないキーは US 配列の表で引く。
///
/// 日本語入力が「かな」のときも ASCII を打てる配列を使うので、`;` は `;` のまま出る。
struct KeyboardLayoutKeyNames: KeyNameProviding {
    func character(forKeyCode keyCode: UInt32) -> String? {
        translate(keyCode) ?? ANSIKeyNames().character(forKeyCode: keyCode)
    }

    private func translate(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else {
            return nil
        }
        let text = String(utf16CodeUnits: characters, count: length)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)).isEmpty else {
            return nil
        }
        return text
    }
}

/// US 配列（ANSI）の表。配列が引けないときと、テストで使う。
struct ANSIKeyNames: KeyNameProviding {
    private static let table: [UInt32: String] = [
        0: "a",
        1: "s",
        2: "d",
        3: "f",
        4: "h",
        5: "g",
        6: "z",
        7: "x",
        8: "c",
        9: "v",
        11: "b",
        12: "q",
        13: "w",
        14: "e",
        15: "r",
        16: "y",
        17: "t",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "o",
        32: "u",
        33: "[",
        34: "i",
        35: "p",
        37: "l",
        38: "j",
        39: "'",
        40: "k",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "n",
        46: "m",
        47: ".",
        50: "`",
        65: ".",
        67: "*",
        69: "+",
        75: "/",
        78: "-",
        81: "=",
        82: "0",
        83: "1",
        84: "2",
        85: "3",
        86: "4",
        87: "5",
        88: "6",
        89: "7",
        91: "8",
        92: "9",
    ]

    func character(forKeyCode keyCode: UInt32) -> String? {
        Self.table[keyCode]
    }
}

/// キーボードショートカットの表示。修飾キーは macOS のメニューと同じ順（⌃ ⌥ ⇧ ⌘）で、キーの名前を最後に置く。
@MainActor struct ShortcutText {
    let keyNames: any KeyNameProviding

    /// 既定は、いま使っているキーボードの配列で引く。
    init(keyNames: any KeyNameProviding = KeyboardLayoutKeyNames()) {
        self.keyNames = keyNames
    }

    /// 修飾キーとキーを 1 つずつに分けたもの（`["⌘", ";"]`）。セットアップのキーキャップに 1 つずつ載せる。
    func parts(_ shortcut: KeyboardShortcut) -> [String] {
        Self.modifierSymbols(shortcut.modifiers) + [keyName(shortcut.keyCode)]
    }

    /// 記号の間に半角スペースを入れた文字列（`⌘ ;`。設定の記録欄の書き方）。
    func string(_ shortcut: KeyboardShortcut) -> String {
        parts(shortcut).joined(separator: " ")
    }

    /// キーの名前。文字を打つキーは大文字にする（macOS のメニューと同じ `⌘K`）。
    func keyName(_ keyCode: UInt32) -> String {
        if let special = Self.specialKeys[keyCode] {
            return special
        }
        if let character = keyNames.character(forKeyCode: keyCode) {
            return character.uppercased()
        }
        return "#\(keyCode)"
    }

    /// 修飾キーの記号（⌃ ⌥ ⇧ ⌘ の順）。
    static func modifierSymbols(_ modifiers: KeyModifiers) -> [String] {
        var symbols: [String] = []
        if modifiers.contains(.control) {
            symbols.append("⌃")
        }
        if modifiers.contains(.option) {
            symbols.append("⌥")
        }
        if modifiers.contains(.shift) {
            symbols.append("⇧")
        }
        if modifiers.contains(.command) {
            symbols.append("⌘")
        }
        return symbols
    }

    /// 配列によらず名前が決まっているキー（`kVK_*`）。
    private static let specialKeys: [UInt32: String] = [
        UInt32(kVK_Return): "↵",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_Home): "↖",
        UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞",
        UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_Help): "Help",
        UInt32(kVK_ANSI_KeypadEnter): "⌤",
        UInt32(kVK_ANSI_KeypadClear): "⌧",
        UInt32(kVK_JIS_Eisu): "英数",
        UInt32(kVK_JIS_Kana): "かな",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13",
        UInt32(kVK_F14): "F14",
        UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17",
        UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19",
        UInt32(kVK_F20): "F20",
    ]
}

extension KeyModifiers {
    /// AppKit の修飾キーから作る。Caps Lock・テンキー・fn の印は数えない。
    init(eventFlags flags: NSEvent.ModifierFlags) {
        let relevant = flags.intersection(.deviceIndependentFlagsMask)
        var result: KeyModifiers = []
        if relevant.contains(.command) {
            result.insert(.command)
        }
        if relevant.contains(.shift) {
            result.insert(.shift)
        }
        if relevant.contains(.option) {
            result.insert(.option)
        }
        if relevant.contains(.control) {
            result.insert(.control)
        }
        self = result
    }
}
