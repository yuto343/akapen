import Foundation

/// セッションの表示状態。遷移の所有者は SessionModel のみ。
public enum Phase: String, Codable, Sendable { case hidden, drawing, commenting, idle, listOpen, copied }

/// 全ディスプレイ共通の左上原点（主画面の左上 = 0,0）、単位はポイント。
/// 左・上に配置された画面では負数を許す。ピクセル倍率は含めない。
public struct ScreenRect: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    /// 幅と高さは非負の矩形を渡す。
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}
/// 表示装置の識別子と、共通の左上原点によるフレーム。
public struct ScreenDescriptor: Codable, Equatable, Sendable {
    public var id: UInt32
    public var frame: ScreenRect
    /// id は CGDirectDisplayID と対応する。
    public init(id: UInt32, frame: ScreenRect) { self.id = id; self.frame = frame }
}
/// 保存済みの注釈。rect は ScreenRect と同じ全画面共通の座標。
public struct Annotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var imagePath: String
    public var comment: String
    public var rect: ScreenRect
    /// imagePath は画像ファイルの絶対パス。
    public init(id: UUID = UUID(), imagePath: String, comment: String, rect: ScreenRect) {
        self.id = id; self.imagePath = imagePath; self.comment = comment; self.rect = rect
    }
}
/// 表示と定型文の言語。
public enum Language: String, Codable, Sendable { case en, ja }
/// コメントの確定操作。
public enum ConfirmKey: String, Codable, Sendable { case enter, commandEnter }
/// プラットフォーム非依存の修飾キー集合。
public struct KeyModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt32
    /// 保存済みビット集合から復元する。
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1)
    public static let shift = Self(rawValue: 2)
    public static let option = Self(rawValue: 4)
    public static let control = Self(rawValue: 8)
}
/// macOS 仮想キーコードと修飾キー。既定値は ANSI セミコロンと Command。
public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: KeyModifiers
    /// キーコードは Carbon の仮想キーコード。修飾キーは独自のビット集合。
    public init(keyCode: UInt32 = 41, modifiers: KeyModifiers = .command) { self.keyCode = keyCode; self.modifiers = modifiers }
}
/// 永続化する設定。既定は英語、Enter 確定、7 日保存。
public struct Settings: Codable, Equatable, Sendable {
    public var language: Language = .en
    public var hotkey = KeyboardShortcut()
    public var toolbarShortcut: KeyboardShortcut? = nil
    public var confirmKey: ConfirmKey = .enter
    public var boilerplates: [String: String] = [
        "en": "I annotated the screen. Please address the comments below.\nOpen every image and check the area marked with the red frame before you start.",
        "ja": "画面に注釈を付けました。以下のコメントに対応してください。\n作業前にすべての画像を開き、赤枠の箇所を確認してください。"
    ]
    public var imageRetentionDays: Int = 7
    /// DESIGN.md に定めた既定値で初期化する。
    public init() {}
}
/// 状態機械の入力。画面・ホットキー・タイマーはこの入口に集約する。
public enum SessionEvent: Sendable {
    case hotkeyPressed, addTapped, escapePressed
    case dragEnded(rect: ScreenRect, screen: ScreenDescriptor)
    case commentConfirmed(text: String), commentCancelled
    case listToggled, annotationEdited(id: UUID, text: String), annotationDeleted(id: UUID)
    case copyPromptTapped, copiedExpired, toolbarToggled
    case settingsChanged(Settings)
}
