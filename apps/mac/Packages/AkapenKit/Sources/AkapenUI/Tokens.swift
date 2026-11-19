import AppKit
import SwiftUI

/// デザイントークン。Paper のファイル「Design System」の App 01〜09 で使っている値を、役割の名前で持つ。
///
/// 値の出どころは `.director/design/tokens.md` と各画面の資料、2026-11-19 の調節分は `.director/design-v2/changes.md`。画面のコードには数値や色を直接書かず、ここから使う。
/// 寸法の単位はポイント。文字の字間は em（文字の大きさに対する比）で持ち、表示するときにポイントへ直す。
public enum Tokens {}

// MARK: - 値の型

/// sRGB の色。`#RRGGBB` と `#RRGGBBAA` の書き方から作る。
public struct ColorToken: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    /// `0xRRGGBB` から作る。不透明度は 1。
    public init(rgb: UInt32) {
        red = Double((rgb >> 16) & 0xFF) / 255
        green = Double((rgb >> 8) & 0xFF) / 255
        blue = Double(rgb & 0xFF) / 255
        alpha = 1
    }

    /// `0xRRGGBBAA`（資料の `#RRGGBBAA` と同じ並び）から作る。
    public init(rgba: UInt32) {
        red = Double((rgba >> 24) & 0xFF) / 255
        green = Double((rgba >> 16) & 0xFF) / 255
        blue = Double((rgba >> 8) & 0xFF) / 255
        alpha = Double(rgba & 0xFF) / 255
    }

    /// SwiftUI の色。
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    /// AppKit の色。
    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

/// 文字の太さ。Paper の 400 / 500 / 600 に当たる。
public enum FontWeightToken: Hashable, Sendable {
    case regular
    case medium
    case semibold

    var swiftUI: Font.Weight {
        switch self {
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        }
    }

    var appKit: NSFont.Weight {
        switch self {
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        }
    }
}

/// 文字のスタイル。システムフォント（SF Pro。20pt 以上は SF Pro Display が自動で使われる）か、システムの等幅フォント（SF Mono）。
public struct TextStyle: Hashable, Sendable {
    public var size: CGFloat
    public var weight: FontWeightToken
    /// 行の高さ（pt）。
    public var lineHeight: CGFloat
    /// 字間（em）。
    public var tracking: CGFloat
    /// システムの等幅フォントを使うか。
    public var monospaced: Bool

    /// 等幅の文字は `monospaced` を true にする（`DECISIONS.md` 2。IBM Plex Mono は同梱しない）。
    public init(
        size: CGFloat,
        weight: FontWeightToken,
        lineHeight: CGFloat,
        tracking: CGFloat = 0,
        monospaced: Bool = false
    ) {
        self.size = size
        self.weight = weight
        self.lineHeight = lineHeight
        self.tracking = tracking
        self.monospaced = monospaced
    }

    /// SwiftUI のフォント。
    public var font: Font {
        .system(size: size, weight: weight.swiftUI, design: monospaced ? .monospaced : .default)
    }

    /// AppKit のフォント。
    public var nsFont: NSFont {
        if monospaced {
            return .monospacedSystemFont(ofSize: size, weight: weight.appKit)
        }
        return .systemFont(ofSize: size, weight: weight.appKit)
    }

    /// 字間（pt）。
    public var trackingPoints: CGFloat {
        tracking * size
    }

    /// フォントそのものの行の高さ（pt。AppKit の値）。入力欄（`NSTextView`）で文字を行の上下の中央に置くのに使う。
    public var naturalLineHeight: CGFloat {
        let font = nsFont
        return font.ascender - font.descender + font.leading
    }
}

/// CSS の `box-shadow` 1 層分（外側の影）。`spread` を含めて資料の値をそのまま持つ。
public struct ShadowToken: Equatable, Sendable {
    public var color: ColorToken
    public var x: CGFloat
    public var y: CGFloat
    public var blur: CGFloat
    public var spread: CGFloat

    /// 値は資料の `box-shadow` の並び（色、x、y、ぼかし、広がり）と同じ。
    public init(color: ColorToken, x: CGFloat, y: CGFloat, blur: CGFloat, spread: CGFloat) {
        self.color = color
        self.x = x
        self.y = y
        self.blur = blur
        self.spread = spread
    }

    /// 影が部品の外にはみ出す最大の幅。パネルの余白を決めるのに使う。
    public var extent: CGFloat {
        blur + spread + max(abs(x), abs(y))
    }
}

// MARK: - Paper のトークン

extension Tokens {
    /// Paper に定義されている色のトークン。名前は Paper の `--color-*` に合わせる。
    public enum Palette {
        public static let paper = ColorToken(rgb: 0xF4F4F2)
        public static let paper2 = ColorToken(rgb: 0xE9E9E6)
        public static let ink = ColorToken(rgb: 0x1C1C1F)
        public static let ink2 = ColorToken(rgb: 0x5A5A60)
        public static let steel = ColorToken(rgb: 0x8E8E94)
        public static let line = ColorToken(rgba: 0x1C1C_1F0A)
        public static let accent = ColorToken(rgb: 0xDC2B2B)
        public static let accentDeep = ColorToken(rgb: 0xB81C1C)
        public static let darkSteel = ColorToken(rgb: 0x87878F)
        public static let cleanBackground = ColorToken(rgb: 0xFFFFFF)
        public static let cleanSurface = ColorToken(rgb: 0xF5F5F7)
    }

    /// アプリの画面で使っているが、Paper のトークンにない色（`tokens.md`「トークンにない値」）。
    public enum ExtraColor {
        /// 白 90%。画面下のボタン類の地。
        public static let white90 = ColorToken(rgba: 0xFFFF_FFE6)
        /// 白 80%。メニューで選択中の行のショートカット表記。
        public static let white80 = ColorToken(rgba: 0xFFFF_FFCC)
        /// ink 90%。案内の表示の地。
        public static let ink90 = ColorToken(rgba: 0x1C1C_1FE6)
        /// ink 18%。セットアップの未選択の点、オフのスイッチ。
        public static let ink18 = ColorToken(rgba: 0x1C1C_1F2E)
        /// ink 15%。メニューバーのアイコンが押されている状態の地、キーキャップ下端の影。
        public static let ink15 = ColorToken(rgba: 0x1C1C_1F26)
        /// ink 8%。終了確認のときの画面の暗転。
        public static let ink8 = ColorToken(rgba: 0x1C1C_1F14)
        /// ink 6%。グループ内の区切り線、セグメントの地。
        public static let ink6 = ColorToken(rgba: 0x1C1C_1F0F)
        /// accent 70%。セットアップの主ボタンの下に落ちる赤い影。
        public static let accent70 = ColorToken(rgba: 0xDC2B_2BB3)
        /// accent 15%。赤枠の外側のにじみ。
        public static let accent15 = ColorToken(rgba: 0xDC2B_2B26)
        /// accent 4%。一覧で編集中の行の地。
        public static let accent4 = ColorToken(rgba: 0xDC2B_2B0A)
        /// ink 10%。キーの表示（チップ）の内側の輪郭。
        public static let ink10 = ColorToken(rgba: 0x1C1C_1F1A)
        /// 白 12%。黒い地（Copy prompt）の上のキーの表示の地。
        public static let white12 = ColorToken(rgba: 0xFFFF_FF1F)
        /// 白 8%。黒い地の上のキーの表示の内側の輪郭。
        public static let white8 = ColorToken(rgba: 0xFFFF_FF14)
        /// 黒い地の上のキーの表示の文字。
        public static let keycapOnDarkText = ColorToken(rgb: 0xD4D4D8)
        /// コピー完了の表示のチェックの丸（緑）。
        public static let success = ColorToken(rgb: 0x1F9D55)
        /// 設定ウィンドウのタイトルバー。
        public static let chrome = ColorToken(rgb: 0xF6F6F8)
        /// `chrome` の 95%。メニューの地。
        public static let chrome95 = ColorToken(rgba: 0xF6F6_F8F2)
        /// `chrome` の 97%。終了確認の地。
        public static let chrome97 = ColorToken(rgba: 0xF6F6_F8F7)
        /// 一覧のサムネイルの地。
        public static let thumbnail = ColorToken(rgb: 0xE4E7EE)
        /// 黒 8%。設定ウィンドウのタイトルバー下の線。
        public static let black8 = ColorToken(rgba: 0x0000_0014)
        /// 信号ボタン（閉じる）。
        public static let trafficClose = ColorToken(rgb: 0xFF5F57)
        /// 信号ボタン（最小化）。
        public static let trafficMinimize = ColorToken(rgb: 0xFEBC2E)
        /// 信号ボタン（拡大）。
        public static let trafficZoom = ColorToken(rgb: 0x28C840)
        /// 信号ボタン（使えない状態）。
        public static let trafficDisabled = ColorToken(rgb: 0xD9D9DE)
        /// 透明。状態によって輪郭を出さないときに使う。
        public static let transparent = ColorToken(rgba: 0x0000_0000)
    }

    /// 影の色（黒の不透明度違い）。
    public enum ShadowColor {
        /// 黒 12%。
        public static let black12 = ColorToken(rgba: 0x0000_001F)
        /// 黒 18%。0.5pt の輪郭線。
        public static let black18 = ColorToken(rgba: 0x0000_002E)
        /// 黒 20%。
        public static let black20 = ColorToken(rgba: 0x0000_0033)
        /// 黒 25%。
        public static let black25 = ColorToken(rgba: 0x0000_0040)
        /// 黒 28%。
        public static let black28 = ColorToken(rgba: 0x0000_0047)
        /// 黒 30%。
        public static let black30 = ColorToken(rgba: 0x0000_004D)
        /// 黒 35%。
        public static let black35 = ColorToken(rgba: 0x0000_0059)
        /// 黒 40%。
        public static let black40 = ColorToken(rgba: 0x0000_0066)
    }

    /// Paper の余白のトークン（`--spacing-*`）。
    public enum Spacing {
        public static let s1: CGFloat = 4
        public static let s2: CGFloat = 8
        public static let s3: CGFloat = 12
        public static let s4: CGFloat = 16
        public static let s5: CGFloat = 20
        public static let s6: CGFloat = 24
        public static let s10: CGFloat = 40
        public static let s16: CGFloat = 64
    }

    /// 角丸。
    public enum Radius {
        /// 両端が丸い形（Paper の 999）。
        public static let pill: CGFloat = 999
        /// 入力欄・サムネイル・小さなボタン（`--radius-field`）。
        public static let field: CGFloat = 12
        /// コメント入力・グループの箱・ウィンドウ（`--radius-media`）。
        public static let media: CGFloat = 18
        /// 赤枠。
        public static let frame: CGFloat = 10
        /// 一覧のパネル。
        public static let large: CGFloat = 24
        /// 終了確認の箱。
        public static let alert: CGFloat = 26
        /// 設定の記録欄・終了確認のボタン。
        public static let keycap: CGFloat = 10
        /// 小さなキーの表示（ボタン類・コメント入力・一覧の案内のチップ）。
        public static let keyChip: CGFloat = 6
        /// 定型文の入力欄・セットアップのキー・重複の注意書き。
        public static let box: CGFloat = 16
        /// メニューの項目・セグメントの選択中の項目・信号ボタン。
        public static let item: CGFloat = 6
        /// メニューバーのアイコンが押された状態の地。
        public static let statusItem: CGFloat = 5
        /// 案内の表示の赤い点。
        public static let hintDot: CGFloat = 4
        /// ページの点・重複の注意書きの赤い点。
        public static let dot: CGFloat = 3
        /// 一覧の仮置きのサムネイルの中の四角（参考）。
        public static let thumbnailInner: CGFloat = 3
    }

    /// 線の太さ。
    public enum Stroke {
        /// 赤枠の線。
        public static let frame: CGFloat = 3
        /// 赤枠の外側のにじみ。
        public static let frameGlow: CGFloat = 4
        /// 区切り線。
        public static let hairline: CGFloat = 1
        /// 部品の外側の輪郭線（`0 0 0 0.5px` の影）。
        public static let outline: CGFloat = 0.5
        /// 一覧が開いているときの「List」の輪郭、編集中の入力欄の赤い輪郭。
        public static let emphasis: CGFloat = 1.5
        /// 「List」のアイコンの線。
        public static let listIcon: CGFloat = 1.5
        /// 右上・右向きの矢印のアイコンの線。
        public static let arrowIcon: CGFloat = 1.7
        /// 一覧の鉛筆とゴミ箱のアイコンの線（viewBox 24 の単位）。
        public static let rowIcon: CGFloat = 2
        /// 「Copy prompt」のコピーのアイコンの線。
        public static let copyIcon: CGFloat = 1.5
        /// コピー完了の表示のチェックの印の線。
        public static let checkIcon: CGFloat = 1.8
    }

    /// 動き（`DECISIONS.md` 19・26）。macOS の標準の動き（コントロールセンター・Spotlight）に寄せる。
    ///
    /// システムの「視差効果を減らす」がオンのときは、拡大縮小とずらしをやめて不透明度だけにする。
    public enum Motion {
        public static let hoverLift: CGFloat = 1
        public static let arrowShift: CGFloat = 2
        public static let toolbarScale: CGFloat = 0.92
        public static let entranceRise: CGFloat = 12
        public static let entranceBlur: CGFloat = 8
        public static let hintRise: CGFloat = 8
        public static let buttonDelay: Double = 0.03
        public static let rowDelay: Double = 0.025
        public static let badgePop: CGFloat = 1.25
        public static let framePop: CGFloat = 1.02
        public static let commentScale: CGFloat = 0.95
        public static let pressSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)
        public static let listSpring = Animation.spring(response: 0.45, dampingFraction: 0.85)
        /// パネルが消えるときのフェード（秒）。出るときより速くする。
        public static let fade: TimeInterval = 0.18
        /// パネルが出るときのばねの応答（秒）。
        public static let panelSpringResponse: Double = 0.42
        /// パネルが出るときのばねの減衰。
        public static let panelSpringDamping: Double = 0.82
        /// パネルが出始めるときの大きさ（1 が等倍）。
        public static let panelEntranceScale: CGFloat = 0.94
        /// コピー完了の表示が出始めるときに、下へずらしておく量（pt）。
        public static let toastRise: CGFloat = 6
        /// コピー完了の表示が出始めるときの大きさ。
        public static let toastEntranceScale: CGFloat = 0.9
        /// コピー完了の表示が出始めるときのぼかし（pt）。
        public static let toastEntranceBlur: CGFloat = 6
        /// コピー完了の表示が出るときのばねの応答（秒）。わずかに行き過ぎて戻る。
        public static let toastSpringResponse: Double = 0.38
        /// コピー完了の表示が出るときのばねの減衰。
        public static let toastSpringDamping: Double = 0.78
        /// 箱が出始めてから、チェックの印を描き始めるまで（秒）。
        public static let toastCheckDelay: TimeInterval = 0.08
        /// チェックの印を描く長さ（秒）。
        public static let toastCheckDuration: TimeInterval = 0.3
        /// 箱が出始めてから、文言が現れ始めるまで（秒）。
        public static let toastLabelDelay: TimeInterval = 0.16
        /// 文言が現れる長さ（秒）。
        public static let toastLabelDuration: TimeInterval = 0.26
        /// 文言が現れ始めるときに、左へずらしておく量（pt）。
        public static let toastLabelShift: CGFloat = 4
        /// コピー完了の表示が消える長さ（秒）。出るときより速い。
        public static let toastExit: TimeInterval = 0.2
        /// コピー完了の表示が消えるときの大きさ。
        public static let toastExitScale: CGFloat = 0.96
        /// コピー完了の表示が消えるときのぼかし（pt）。
        public static let toastExitBlur: CGFloat = 4
        /// ホバーの地の色の変化（秒、ease-out）。
        public static let hover: TimeInterval = 0.15
        /// 押した瞬間の大きさ。
        public static let pressedScale: CGFloat = 0.96
        /// 押している最中の不透明度。
        public static let pressedOpacity: Double = 0.8
        /// 使えない状態の不透明度。
        public static let disabledOpacity: Double = 0.4
        /// ホバーのときに地へ重ねる色（地をわずかに濃くする）。
        public static let hoverOverlay = ExtraColor.ink6
        /// セットアップのページを切り替えるときに、横へずらす量（pt）。
        public static let pageShift: CGFloat = 28
        /// 出るときのばね。
        public static var panelSpring: Animation {
            .spring(response: panelSpringResponse, dampingFraction: panelSpringDamping)
        }
        /// ホバーの動き。
        public static var hoverAnimation: Animation {
            .easeOut(duration: hover)
        }
        /// 消えるときの動き。
        public static var exitAnimation: Animation {
            .easeIn(duration: fade)
        }
        /// コピー完了の表示が出るときのばね。
        public static var toastSpring: Animation {
            .spring(response: toastSpringResponse, dampingFraction: toastSpringDamping)
        }
        /// チェックの印を描く動き。箱より少し遅れて始める。
        public static var toastCheckAnimation: Animation {
            .easeOut(duration: toastCheckDuration).delay(toastCheckDelay)
        }
        /// 文言が現れる動き。チェックの印に続けて始める。
        public static var toastLabelAnimation: Animation {
            .easeOut(duration: toastLabelDuration).delay(toastLabelDelay)
        }
        /// コピー完了の表示が消える動き。
        public static var toastExitAnimation: Animation {
            .easeIn(duration: toastExit)
        }
        /// 「視差効果を減らす」がオンのときの、不透明度だけの出入り。
        public static var reducedFadeAnimation: Animation {
            .easeIn(duration: fade)
        }
    }
}

// MARK: - 文字のスタイル

extension Tokens {
    /// 文字のスタイル。名前は使い道。
    public enum Typography {
        /// ボタン類の文言（`List`・`Copy prompt`）と案内の表示の `Drag to frame`。SF Pro Text Medium 13 / 16。
        public static let control = TextStyle(size: 13, weight: .medium, lineHeight: 16)
        /// 「List」のバッジ。SF Pro Text Semibold 11 / 18。
        public static let badge = TextStyle(size: 11, weight: .semibold, lineHeight: 18)
        /// 等幅のメタ表記（`esc to cancel`・大きさの表示・`2 ITEMS`・`Sample App · 14:32`）。11 / 14。
        public static let meta = TextStyle(size: 11, weight: .regular, lineHeight: 14, monospaced: true)
        /// 等幅のラベル（`STEP 1 OF 2`）。11 / 14、字間 0.02em（`--tracking-label`）。
        public static let metaLabel = TextStyle(size: 11, weight: .regular, lineHeight: 14, tracking: 0.02, monospaced: true)
        /// コメント入力の文字。SF Pro Text Regular 14 / 21。
        public static let commentInput = TextStyle(size: 14, weight: .regular, lineHeight: 21)
        /// 一覧の見出し `Annotations`。SF Pro Text Semibold 15 / 18。
        public static let listTitle = TextStyle(size: 15, weight: .semibold, lineHeight: 18)
        /// 一覧の行のコメントと、編集中の入力欄。SF Pro Text Regular 14 / 20。
        public static let listComment = TextStyle(size: 14, weight: .regular, lineHeight: 20)
        /// 一覧のフッター。SF Pro Text Regular 12 / 16。
        public static let listFooter = TextStyle(size: 12, weight: .regular, lineHeight: 16)
        /// 小さなキーの表示（チップ）の文字（`⌘`・`L`・`↵`・`esc`）。SF Pro Text Medium 11 / 14。
        public static let keyChip = TextStyle(size: 11, weight: .medium, lineHeight: 14)
        /// キーの表示に添える文言（`Done`・`New line`・`Save`・`Cancel`）。SF Pro Text Regular 11 / 14。
        public static let keyHintLabel = TextStyle(size: 11, weight: .regular, lineHeight: 14)
        /// メニューの見出しの 1 行目 `akapen`。SF Pro Text Semibold 13 / 16。
        public static let menuTitle = TextStyle(size: 13, weight: .semibold, lineHeight: 16)
        /// メニューの見出しの 2 行目。SF Pro Text Regular 11 / 14。
        public static let menuSubtitle = TextStyle(size: 11, weight: .regular, lineHeight: 14)
        /// メニューの項目と、そのショートカット。SF Pro Text Regular 13 / 16。
        public static let menuItem = TextStyle(size: 13, weight: .regular, lineHeight: 16)
        /// 設定ウィンドウのタイトル。SF Pro Text Semibold 13 / 16。
        public static let windowTitle = TextStyle(size: 13, weight: .semibold, lineHeight: 16)
        /// 設定の行の名前。SF Pro Text Regular 13 / 16。
        public static let rowLabel = TextStyle(size: 13, weight: .regular, lineHeight: 16)
        /// 設定の行の名前の下の補足（`Optional shortcut`）。SF Pro Text Regular 11 / 14。
        public static let rowCaption = TextStyle(size: 11, weight: .regular, lineHeight: 14)
        /// セグメントの選択中の項目。SF Pro Text Medium 12 / 24。
        public static let segmentSelected = TextStyle(size: 12, weight: .medium, lineHeight: 24)
        /// セグメントの選ばれていない項目。SF Pro Text Regular 12 / 24。
        public static let segment = TextStyle(size: 12, weight: .regular, lineHeight: 24)
        /// 設定のキーの記録欄（`⌘ ;`）。SF Pro Text Semibold 12 / 26。
        public static let recorderKey = TextStyle(size: 12, weight: .semibold, lineHeight: 26)
        /// 設定のキーの記録欄の未設定の表示（`Record shortcut`）。SF Pro Text Regular 12 / 26。
        public static let recorderPlaceholder = TextStyle(size: 12, weight: .regular, lineHeight: 26)
        /// 設定の見出し（`Prompt header`）。SF Pro Text Semibold 13 / 16。
        public static let sectionTitle = TextStyle(size: 13, weight: .semibold, lineHeight: 16)
        /// 設定の見出しの右の補足（`Edits the English version`）。SF Pro Text Regular 12 / 16。
        public static let sectionNote = TextStyle(size: 12, weight: .regular, lineHeight: 16)
        /// 定型文の入力欄。等幅 12 / 19。
        public static let boilerplate = TextStyle(size: 12, weight: .regular, lineHeight: 19, monospaced: true)
        /// 設定の入力欄の下の補足。SF Pro Text Regular 11 / 15。
        public static let caption = TextStyle(size: 11, weight: .regular, lineHeight: 15)
        /// 画像を残す日数の数字。SF Pro Text Medium 13 / 26。
        public static let retentionValue = TextStyle(size: 13, weight: .medium, lineHeight: 26)
        /// セットアップの見出し。SF Pro Display Semibold 26 / 32、字間 -0.015em。
        public static let setupTitle = TextStyle(size: 26, weight: .semibold, lineHeight: 32, tracking: -0.015)
        /// セットアップの説明文。SF Pro Text Regular 14 / 21。
        public static let setupBody = TextStyle(size: 14, weight: .regular, lineHeight: 21)
        /// セットアップのキー（`⌘` と `;`）。SF Pro Text Semibold 22 / 52。
        public static let setupKey = TextStyle(size: 22, weight: .semibold, lineHeight: 52)
        /// セットアップのキーの下の案内・`Waiting…`。SF Pro Text Regular 12 / 16。
        public static let setupHint = TextStyle(size: 12, weight: .regular, lineHeight: 16)
        /// セットアップの重複の注意書き。SF Pro Text Regular 12 / 18。
        public static let setupNote = TextStyle(size: 12, weight: .regular, lineHeight: 18)
        /// セットアップの許可の手順の文。SF Pro Text Regular 13 / 16。
        public static let setupStep = TextStyle(size: 13, weight: .regular, lineHeight: 16)
        /// セットアップの主ボタンと `Back`。SF Pro Text Medium 14 / 18。
        public static let setupButton = TextStyle(size: 14, weight: .medium, lineHeight: 18)
        /// 終了確認の見出し。SF Pro Text Semibold 13 / 17。
        public static let alertTitle = TextStyle(size: 13, weight: .semibold, lineHeight: 17)
        /// 終了確認の説明文。SF Pro Text Regular 11 / 15。
        public static let alertBody = TextStyle(size: 11, weight: .regular, lineHeight: 15)
        /// 終了確認のボタン。SF Pro Text Medium 13 / 16。
        public static let alertButton = TextStyle(size: 13, weight: .medium, lineHeight: 16)
    }
}

// MARK: - 影

extension Tokens {
    /// 影（`tokens.md`「影の一覧」）。配列は手前の層から順。
    public enum Shadows {
        /// 0.5pt の輪郭線（黒 18%）。
        public static let outline = ShadowToken(color: Glass.ring, x: 0, y: 0, blur: 0, spread: 0.5)
        /// 0.5pt の輪郭線（黒 25%）。メニュー・終了確認。
        public static let outlineStrong = ShadowToken(color: ShadowColor.black25, x: 0, y: 0, blur: 0, spread: 0.5)
        /// 0.5pt の輪郭線（黒 30%）。設定・セットアップのウィンドウ。
        public static let outlineWindow = ShadowToken(color: ShadowColor.black30, x: 0, y: 0, blur: 0, spread: 0.5)
        /// 画面下のボタン類。
        public static let toolbar = [
            outline,
            ShadowToken(color: Glass.shadow, x: 0, y: 24, blur: 48, spread: -20),
        ]
        /// 案内の表示。
        public static let hint = [
            ShadowToken(color: ShadowColor.black35, x: 0, y: 8, blur: 24, spread: -8),
        ]
        /// コメント入力。
        public static let comment = [
            outline,
            ShadowToken(color: Glass.shadow, x: 0, y: 24, blur: 48, spread: -16),
        ]
        /// 一覧。
        public static let list = [
            outline,
            ShadowToken(color: Glass.shadow, x: 0, y: 24, blur: 48, spread: -16),
        ]
        /// コピー完了の表示（画面下のボタン類と同じ白いピル）。
        public static let toast = toolbar
        /// メニュー。
        public static let menu = [
            outlineStrong,
            ShadowToken(color: ShadowColor.black30, x: 0, y: 16, blur: 40, spread: -8),
        ]
        /// 終了確認。
        public static let alert = [
            outlineStrong,
            ShadowToken(color: ShadowColor.black40, x: 0, y: 24, blur: 60, spread: -12),
        ]
        /// 設定・セットアップのウィンドウ。
        public static let window = [
            outlineWindow,
            ShadowToken(color: ShadowColor.black40, x: 0, y: 32, blur: 80, spread: -16),
        ]
        /// 赤枠の外側のにじみ（accent 15% を外側に 4pt）。
        public static let frameGlow = ShadowToken(color: ExtraColor.accent15, x: 0, y: 0, blur: 0, spread: Stroke.frameGlow)
        /// セットアップの主ボタンの下に落ちる赤い光。
        public static let primaryGlow = [
            ShadowToken(color: Glass.shadow, x: 0, y: 8, blur: 18, spread: -8),
        ]
        /// 設定のセグメントの選択中の項目。
        public static let segmentSelected = [
            ShadowToken(color: ShadowColor.black12, x: 0, y: 1, blur: 2, spread: 0),
        ]
        /// 終了確認の `Cancel` ボタンの下の影。
        public static let alertCancel = [
            ShadowToken(color: ExtraColor.black8, x: 0, y: 0.5, blur: 1, spread: 0),
        ]
        /// セットアップのキー（キーキャップ）の外側の 1pt の輪郭。
        public static let setupKeyOutline = [
            ShadowToken(color: Palette.line, x: 0, y: 0, blur: 0, spread: Stroke.hairline),
        ]
    }
}

// MARK: - 置き場所

extension Tokens {
    /// 画面の中での置き場所（`DECISIONS.md` 4〜8・10）。
    public enum Placement {
        /// 画面下のボタン類とコピー完了の表示の、`visibleFrame` の下端からの距離。
        public static let bottomInset: CGFloat = 16
        /// 案内の表示の、`visibleFrame` の上端（メニューバーの下端）からの距離。
        public static let hintTopInset: CGFloat = 16
        /// 一覧とボタン類の間隔。
        public static let listGap: CGFloat = 12
        /// コメント入力と赤枠の間隔。
        public static let commentGap: CGFloat = 12
        /// コメント入力を画面内に収めるときの、画面の端からの余白。
        public static let screenMargin: CGFloat = 8
        /// 大きさの表示の上端の、カーソルからの距離。
        public static let sizeLabelOffsetY: CGFloat = 10
        /// 大きさの表示の右端の、カーソルからの距離。
        public static let sizeLabelOffsetX: CGFloat = 15
        /// 終了確認の箱の上下の置き場所。画面の高さから箱の高さを引いた残りのうち、箱の上に置く割合。
        /// Paper の App 09（画面 800、箱 245、上端 250）に合わせた値で、画面の中央よりやや上になる。
        public static let alertTopRatio: CGFloat = 0.45
    }
}

// MARK: - 部品ごとの寸法と色（App 01〜04）

extension Tokens {
    /// 画面下のボタン類（`components.md`）。
    public enum Toolbar {
        public static let background = ExtraColor.white90
        public static let padding: CGFloat = 7
        public static let gap: CGFloat = 6
        public static let shadows = Shadows.toolbar
        /// 「List」「Copy prompt」の高さ。
        public static let controlHeight: CGFloat = 38
        /// 全削除のボタン。既存の操作ボタンと配色をそろえる。
        public static let clearBackground = controlBackground
        public static let clearIconSize = iconSize
        public static let clearIconColor = iconColor
        public static let clearIconStroke = Tokens.Stroke.listIcon
        public static let controlBackground = Palette.cleanSurface
        public static let iconSize: CGFloat = 14
        public static let iconColor = Palette.ink
        public static let labelColor = Palette.ink
        public static let listPaddingX: CGFloat = 14
        public static let listGap: CGFloat = 8
        /// 一覧が開いているときの「List」の地と輪郭。
        public static let listOpenBackground = Palette.cleanBackground
        public static let listOpenOutline = Palette.ink
        public static let badgeBackground = Palette.accent
        public static let badgeText = Palette.cleanBackground
        public static let badgePaddingX: CGFloat = 5
        /// バッジの高さと最小の幅（数字 1 桁で正円）。
        public static let badgeSize: CGFloat = 20
        /// バッジを「List」の右上の角からはみ出させる量（右へ・上へ）。
        public static let badgeOverhang: CGFloat = 6
        /// バッジのまわりの白い輪（`0 0 0 2px #FFFFFF`）。
        public static let badgeRing = Palette.cleanBackground
        public static let badgeRingWidth: CGFloat = 2
        public static let copyBackground = Palette.ink
        public static let copyText = Palette.cleanBackground
        public static let copyPaddingLeading: CGFloat = 5
        public static let copyPaddingTrailing: CGFloat = 14
        public static let copyGap: CGFloat = 10
        public static let copyCircleSize: CGFloat = 28
        public static let copyCircle = Palette.accent
        public static let copyIconSize: CGFloat = 13
        public static let copyIconColor = Palette.cleanBackground
        /// 文言と、そのあとのショートカットのキーの表示（`⌘` `L`）との間。
        public static let shortcutGap: CGFloat = 6
    }

    /// 案内の表示（App 01）。
    public enum Hint {
        public static let background = ExtraColor.ink90
        public static let height: CGFloat = 36
        public static let paddingX: CGFloat = 14
        public static let gap: CGFloat = 10
        public static let shadows = Shadows.hint
        public static let dotSize: CGFloat = 8
        public static let dot = Palette.accent
        public static let title = Palette.cleanBackground
        public static let meta = Palette.darkSteel
    }

    /// 赤枠（App 01・02）。
    public enum Frame {
        public static let stroke = Palette.accent
        public static let glow = Shadows.frameGlow
    }

    /// 大きさの表示（App 01）。
    public enum SizeLabel {
        public static let background = Palette.ink
        public static let text = Palette.cleanBackground
        public static let height: CGFloat = 22
        public static let paddingX: CGFloat = 8
    }

    /// 枠を描く面。
    public enum Surface {
        /// 面の地。完全な透明だとクリックが下へ抜けるので、ほぼ透明の色を敷く（`ARCHITECTURE.md`「確かめた結果」3）。
        public static let background = ColorToken(rgba: 0x0000_0003)
    }

    /// コメント入力（App 02）。
    public enum Comment {
        public static let width: CGFloat = 300
        public static let background = Palette.cleanBackground
        public static let shadows = Shadows.comment
        public static let inputPaddingTop: CGFloat = 14
        public static let inputPaddingX: CGFloat = 16
        public static let inputPaddingBottom: CGFloat = 10
        public static let text = Palette.ink
        public static let placeholder = Palette.steel
        public static let caret = Palette.accent
        /// 入力欄が伸びる行数の上限（`DECISIONS.md` 22）。超えたら中でスクロールする。
        public static let maxLines = 5
        public static let footerPaddingY: CGFloat = 8
        public static let footerPaddingX: CGFloat = 16
        public static let divider = Palette.line
        /// 下の案内の、確定と改行の案内の間。
        public static let footerHintGap: CGFloat = 12
    }

    /// 一覧（App 03）。
    public enum List {
        public static let width: CGFloat = 440
        public static let background = Palette.cleanBackground
        public static let shadows = Shadows.list
        public static let headerPaddingTop: CGFloat = 16
        public static let headerPaddingX: CGFloat = 18
        public static let headerPaddingBottom: CGFloat = 12
        public static let title = Palette.ink
        public static let count = Palette.steel
        public static let divider = Palette.line
        public static let rowPaddingY: CGFloat = 12
        public static let rowPaddingX: CGFloat = 18
        public static let rowGap: CGFloat = 14
        public static let thumbnailWidth: CGFloat = 96
        public static let thumbnailHeight: CGFloat = 60
        public static let thumbnailBackground = ExtraColor.thumbnail
        public static let textGap: CGFloat = 6
        public static let comment = Palette.ink
        public static let meta = Palette.steel
        public static let buttonGap: CGFloat = 4
        public static let buttonSize: CGFloat = 28
        public static let buttonBackground = Palette.cleanSurface
        public static let buttonIconSize: CGFloat = 14
        public static let buttonIcon = Palette.ink2
        public static let editingBackground = ExtraColor.accent4
        public static let fieldPaddingY: CGFloat = 6
        public static let fieldPaddingX: CGFloat = 8
        public static let fieldBackground = Palette.cleanBackground
        public static let fieldOutline = Palette.accent
        /// 編集中の行の下の案内の、保存と取りやめの案内の間。
        public static let editHintGap: CGFloat = 12
        public static let footerPaddingY: CGFloat = 12
        public static let footerPaddingX: CGFloat = 18
        public static let footerBackground = Glass.footer
        public static let footerText = Palette.steel
        public static let emptyText = Palette.steel
        /// 行の部分がスクロールに切り替わる件数（`DECISIONS.md` 6）。
        public static let maxVisibleRows = 4
        /// 1 行の高さ（区切り線を含む）。行の高さを測る前の、スクロールする部分の高さの見積もりに使う。
        public static let estimatedRowHeight: CGFloat = 85
    }

    /// コピー完了の表示（App 04）。画面下のボタン類と同じ白いピルの中に、黒いピルを 1 つ入れる。
    public enum Toast {
        public static let background = ExtraColor.white90
        public static let padding: CGFloat = 6
        public static let shadows = Shadows.toast
        /// 中の黒いピル。
        public static let pillHeight: CGFloat = 36
        public static let pillBackground = Palette.ink
        public static let pillPaddingLeading: CGFloat = 4
        public static let pillPaddingTrailing: CGFloat = 18
        public static let gap: CGFloat = 10
        /// チェックの丸。
        public static let checkCircleSize: CGFloat = 28
        public static let checkCircle = ExtraColor.success
        public static let checkIconSize: CGFloat = 13
        public static let checkIcon = Palette.cleanBackground
        public static let title = Palette.cleanBackground
    }

    /// 小さなキーの表示（チップ）と、それに添える文言（App 01〜03 のボタン類・コメント入力・一覧の案内）。
    public enum KeyChip {
        public static let height: CGFloat = 18
        public static let minWidth: CGFloat = 18
        /// 1 文字のキーの左右の余白。
        public static let paddingX: CGFloat = 4
        /// `esc` のような文字のキーの左右の余白。
        public static let wordPaddingX: CGFloat = 5
        /// キーとキーの間（`⌘` `L`）。
        public static let keyGap: CGFloat = 2
        /// キーと、それに添える文言の間（`↵` `Done`）。
        public static let labelGap: CGFloat = 6
        /// 白い地の上の見た目。
        public static let background = Glass.segment
        public static let outline = ExtraColor.ink10
        public static let text = Palette.steel
        /// 黒い地（Copy prompt）の上の見た目。
        public static let darkBackground = ColorToken(rgba: 0xFFFF_FF24)
        public static let darkOutline = ExtraColor.white8
        public static let darkText = ExtraColor.white80
        /// 添える文言の色。
        public static let label = Palette.steel
    }
}

// MARK: - 部品ごとの寸法と色（App 05〜09）

extension Tokens {
    /// メニューバーのメニュー（App 05）。
    public enum Menu {
        public static let width: CGFloat = 260
        public static let padding: CGFloat = 6
        public static let background = ExtraColor.chrome95
        public static let shadows = Shadows.menu
        public static let headerPaddingTop: CGFloat = 8
        public static let headerPaddingX: CGFloat = 10
        public static let headerPaddingBottom: CGFloat = 10
        public static let headerGap: CGFloat = 10
        public static let iconSize: CGFloat = 28
        public static let title = Palette.ink
        public static let subtitle = Palette.steel
        public static let divider = Palette.line
        public static let dividerMargin: CGFloat = 4
        public static let itemHeight: CGFloat = 26
        public static let itemPaddingX: CGFloat = 10
        public static let itemText = Palette.ink
        public static let itemShortcut = Palette.steel
        public static let selection = Palette.accent
        public static let selectionText = Palette.cleanBackground
        public static let selectionShortcut = ExtraColor.white80
        public static let statusIconWidth: CGFloat = 15
        public static let statusIconHeight: CGFloat = 17
        public static let statusPressedWidth: CGFloat = 28
        public static let statusPressedHeight: CGFloat = 24
        public static let statusPressed = ExtraColor.ink15
        /// 見出しの幅（メニューの幅から左右の余白を引いたもの）。
        public static let headerWidth: CGFloat = width - padding * 2
    }

    /// ウィンドウ（設定・セットアップ）の共通部分（`components.md`「ウィンドウのタイトルバー」）。
    public enum Window {
        public static let background = Palette.cleanBackground
        public static let shadows = Shadows.window
        public static let trafficSize: CGFloat = 12
        public static let trafficGap: CGFloat = 8
        public static let trafficClose = ExtraColor.trafficClose
        public static let trafficMinimize = ExtraColor.trafficMinimize
        public static let trafficZoom = ExtraColor.trafficZoom
        public static let trafficDisabled = ExtraColor.trafficDisabled
    }

    /// 設定ウィンドウ（App 06）。
    public enum Settings {
        public static let width: CGFloat = 620
        public static let titleBarHeight: CGFloat = 52
        public static let titleBarBackground = ExtraColor.chrome
        public static let titleBarDivider = ExtraColor.black8
        public static let trafficPaddingLeading: CGFloat = 20
        public static let title = Palette.ink
        public static let bodyPaddingTop: CGFloat = 24
        public static let bodyPaddingX: CGFloat = 28
        public static let bodyPaddingBottom: CGFloat = 28
        public static let sectionGap: CGFloat = 20
        public static let groupBackground = Glass.group
        public static let rowHeight: CGFloat = 48
        public static let rowPaddingX: CGFloat = 16
        public static let rowDivider = ExtraColor.ink6
        public static let rowLabel = Palette.ink
        public static let rowCaption = Palette.steel
        public static let segmentBackground = ExtraColor.ink6
        public static let segmentPadding: CGFloat = 2
        public static let segmentItemPaddingX: CGFloat = 14
        public static let segmentSelectedBackground = Palette.cleanBackground
        public static let segmentSelectedShadows = Shadows.segmentSelected
        public static let segmentSelectedText = Palette.ink
        public static let segmentText = Palette.ink2
        public static let recorderBackground = Palette.cleanBackground
        public static let recorderOutline = ExtraColor.transparent
        public static let recorderPaddingX: CGFloat = 12
        public static let recorderText = Palette.ink
        public static let recorderPlaceholder = Palette.steel
        public static let headerGap: CGFloat = 8
        public static let sectionTitle = Palette.ink
        public static let sectionNote = Palette.steel
        public static let boilerplatePaddingY: CGFloat = 12
        public static let boilerplatePaddingX: CGFloat = 14
        public static let boilerplateOutline = Glass.segment
        public static let boilerplateText = Palette.ink
        public static let caption = Palette.steel
        public static let retentionGap: CGFloat = 8
        public static let retentionText = Palette.ink
        public static let retentionUnit = Palette.ink2
        /// 定型文の入力欄が伸びる行数の上限。超えたら中でスクロールする。
        public static let boilerplateMaxLines = 8
        /// 定型文の入力欄のキャレット（コメント入力と同じ赤）。
        public static let boilerplateCaret = Palette.accent
        /// キーの記録欄で記録を待っているときの輪郭（資料にない状態。一覧の編集中の入力欄と同じ赤）。
        public static let recorderRecordingOutline = Palette.accent
        /// キーの記録欄の下に出す知らせ（`This shortcut is unavailable`）の色（資料にない状態）。
        public static let recorderMessage = Palette.accentDeep
        /// 記録欄と、その下の知らせの間隔。
        public static let recorderMessageGap: CGFloat = 4
        /// 知らせを出している行の上下の余白（行の高さは中身なりに伸びる）。
        public static let rowMessagePaddingY: CGFloat = 10
        /// 日数の入力欄で、数字の幅に足す分（入力欄の中の文字の左右の余白。数字が欠けないように）。
        public static let retentionFieldSlack: CGFloat = 0
    }

    /// 初回のセットアップ（App 07・08）。
    public enum Setup {
        public static let width: CGFloat = 560
        public static let titleBarHeight: CGFloat = 40
        public static let trafficPaddingLeading: CGFloat = 16
        public static let bodyPaddingTop: CGFloat = 12
        public static let bodyPaddingX: CGFloat = 48
        public static let bodyPaddingBottom: CGFloat = 32
        public static let gap: CGFloat = 20
        public static let iconSize: CGFloat = 88
        public static let headingGap: CGFloat = 8
        public static let step = Palette.steel
        public static let title = Palette.ink
        public static let body = Palette.ink2
        public static let bodyWidth: CGFloat = 400
        public static let recorderBackground = Glass.group
        public static let recorderPadding: CGFloat = 24
        public static let recorderGap: CGFloat = 10
        public static let keyGap: CGFloat = 8
        public static let keyWidth: CGFloat = 56
        public static let keyBackground = Palette.cleanBackground
        public static let keyEdge = ExtraColor.ink15
        public static let keyEdgeHeight: CGFloat = 2
        public static let keyOutline = Palette.line
        public static let keyText = Palette.ink
        public static let hint = Palette.steel
        public static let notePaddingY: CGFloat = 12
        public static let notePaddingX: CGFloat = 14
        public static let noteGap: CGFloat = 10
        public static let noteOutline = Palette.line
        public static let noteDotSize: CGFloat = 6
        public static let noteDotTop: CGFloat = 7
        public static let noteDot = Palette.accent
        public static let noteText = Palette.ink2
        public static let footerPaddingTop: CGFloat = 4
        public static let pageDotGap: CGFloat = 6
        public static let pageDotSize: CGFloat = 6
        public static let pageDotCurrentWidth: CGFloat = 20
        public static let pageDotCurrent = Palette.ink
        public static let pageDot = ExtraColor.ink18
        public static let buttonHeight: CGFloat = 44
        public static let buttonGap: CGFloat = 8
        public static let buttonPaddingLeading: CGFloat = 18
        public static let buttonPaddingTrailing: CGFloat = 5
        public static let buttonInnerGap: CGFloat = 10
        public static let buttonBackground = Palette.ink
        public static let buttonText = Palette.cleanBackground
        public static let buttonShadows = Shadows.primaryGlow
        public static let buttonCircleSize: CGFloat = 30
        public static let buttonCircle = Palette.accent
        /// 赤い丸の中のアイコン（12×12、白）。
        public static let buttonIconSize: CGFloat = 12
        public static let buttonIcon = Palette.cleanBackground
        public static let secondaryButtonOutline = Palette.line
        public static let secondaryButtonText = Palette.ink
        public static let stepsBackground = Glass.group
        public static let stepRowHeight: CGFloat = 48
        public static let stepRowPaddingX: CGFloat = 16
        public static let stepRowGap: CGFloat = 12
        public static let stepRowDivider = ExtraColor.ink6
        public static let stepNumberWidth: CGFloat = 16
        public static let stepNumber = Palette.steel
        public static let stepText = Palette.ink
        public static let waiting = Palette.steel
        public static let switchWidth: CGFloat = 32
        public static let switchHeight: CGFloat = 20
        public static let switchPadding: CGFloat = 2
        public static let switchOff = ExtraColor.ink18
        public static let switchKnobSize: CGFloat = 16
        public static let switchKnob = Palette.cleanBackground
        /// 許可が取れたときの表示（`Granted`）。`Waiting…` と同じ色。
        public static let granted = Palette.steel
        /// キーの名前が長いとき（`Space` など）の、キーの左右の余白。1 文字のキーは幅 56 に収まる。
        public static let keyPaddingX: CGFloat = 12
        /// キーの記録欄で記録を待っているときの輪郭（資料にない状態）。
        public static let recorderRecordingOutline = Palette.accent
        /// 記録欄の中に出す知らせ（`This shortcut is unavailable`）の色（資料にない状態）。
        public static let recorderMessage = Palette.accentDeep
    }

    /// 終了確認（App 09）。
    public enum QuitAlert {
        public static let width: CGFloat = 260
        public static let dim = ExtraColor.ink8
        public static let background = ExtraColor.chrome97
        public static let shadows = Shadows.alert
        public static let paddingTop: CGFloat = 22
        public static let paddingX: CGFloat = 16
        public static let paddingBottom: CGFloat = 16
        public static let gap: CGFloat = 14
        public static let iconSize: CGFloat = 64
        public static let textGap: CGFloat = 6
        public static let title = Palette.ink
        public static let body = Palette.ink2
        public static let buttonGap: CGFloat = 6
        public static let buttonHeight: CGFloat = 36
        public static let quitBackground = Palette.accent
        public static let quitText = Palette.cleanBackground
        public static let cancelBackground = Palette.cleanBackground
        public static let cancelText = Palette.ink
        public static let cancelOutline = ExtraColor.transparent
        public static let cancelShadows = Shadows.alertCancel
    }
}


extension Tokens {
    /// Soft Glass / Ink + Red の素材と輪郭。
    public enum Glass {
        public static let inkTop = ColorToken(rgb: 0x4A4A52)
        public static let redTop = ColorToken(rgb: 0xF65A57)
        public static let greenTop = ColorToken(rgb: 0x4FD18A)
        public static let barTop = ColorToken(rgba: 0xFFFF_FFB8)
        public static let barBottom = ColorToken(rgba: 0xFFFF_FF8C)
        public static let panel = ColorToken(rgba: 0xFFFF_FFD9)
        public static let window = ColorToken(rgba: 0xF7F8_FAE6)
        public static let group = ColorToken(rgba: 0xFFFF_FFB3)
        public static let footer = ColorToken(rgba: 0xFFFF_FF66)
        public static let segment = ColorToken(rgba: 0x1C1C_1F0D)
        public static let redTint = ColorToken(rgb: 0xFCDCDB)
        public static let ring = ColorToken(rgba: 0xFFFF_FFB3)
        public static let dotRing = ColorToken(rgba: 0xDC2B_2B4D)
        public static let ringWidth: CGFloat = 1
        public static let dotRingWidth: CGFloat = 3
        public static let commentRadius: CGFloat = 20
        public static let settingsRadius: CGFloat = 26
        public static let setupRadius: CGFloat = 28
        public static let setupKeyRadius: CGFloat = 14
        public static let ink = LinearGradient(colors: [inkTop.color, Palette.ink.color], startPoint: .top, endPoint: .bottom)
        public static let red = LinearGradient(colors: [redTop.color, Palette.accent.color], startPoint: .top, endPoint: .bottom)
        public static let green = LinearGradient(colors: [greenTop.color, ExtraColor.success.color], startPoint: .top, endPoint: .bottom)
        public static let white = LinearGradient(colors: [Palette.cleanBackground.color, panel.color], startPoint: .top, endPoint: .bottom)
        public static let bar = LinearGradient(colors: [barTop.color, barBottom.color], startPoint: .top, endPoint: .bottom)
        public static let hoverShadow: CGFloat = 5
        public static let shadow = ColorToken(rgba: 0x1C1C_2E33)
        public static let pillShadow = [ShadowToken(color: shadow, x: 0, y: 4, blur: 10, spread: -6)]
        public static let redShadow = [ShadowToken(color: ColorToken(rgba: 0xDC2B_2B99), x: 0, y: 3, blur: 8, spread: -2)]
        public static let inkShadow = [ShadowToken(color: ColorToken(rgba: 0x1C1C_2E80), x: 0, y: 8, blur: 18, spread: -8)]
    }
}
