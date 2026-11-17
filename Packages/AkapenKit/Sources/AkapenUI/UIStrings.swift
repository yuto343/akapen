import Foundation
import AkapenCore

/// 英語を既定とする文字列カタログの読み出し。
public enum UIStrings {
    public static func text(_ key: String, language: Language = .en) -> String {
        let bundle = Bundle.module
            .path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .module
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
