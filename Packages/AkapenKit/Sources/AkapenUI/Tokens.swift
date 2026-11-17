import AppKit

/// 骨組みの仮のデザイントークン。正式な見た目は後続で置き換える。
@MainActor public enum Tokens {
    public static let drawingBackground = NSColor.black.withAlphaComponent(0.01)
    public static let frameColor = NSColor.systemRed
    public static let frameWidth: CGFloat = 3
    public static let toolbarSize = NSSize(width: 300, height: 52)
    public static let margin: CGFloat = 24
    public static let spacing: CGFloat = 12
}
