import AppKit
import AkapenCore
/// 骨組みの仮のデザイントークン。正式な見た目は後続で置き換える。
@MainActor public enum Tokens {
    public static let drawingBackground = NSColor.black.withAlphaComponent(0.01)
    public static let frameColor = NSColor.systemRed
    public static let frameWidth: CGFloat = 3
    public static let toolbarSize = NSSize(width: 300, height: 52)
    public static let margin: CGFloat = 24
    public static let spacing: CGFloat = 12
}
/// 英語を既定とする文字列カタログの読み出し。
public enum UIStrings {
    public static func text(_ key: String, language: Language = .en) -> String {
        let bundle = Bundle.module.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
