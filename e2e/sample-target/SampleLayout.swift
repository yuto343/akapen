import AppKit

/// Sample App の配置。`.director/design/sample-app.md` の値を、本文の左上を原点にした座標に直したもの。
///
/// 本文はタイトルバーの下の 1000×608 の領域。ウィンドウの本文がこれより小さいときは、
/// 全体を同じ比率で縮めて収める（`SampleCanvas`）。大きいときは等倍のまま左上に寄せる。
enum SampleLayout {
    /// 等倍で描いたときの本文の大きさ。
    static let canvasSize = NSSize(width: 1000, height: 608)

    /// `SAMPLE_FRAME` がないときのウィンドウの位置と大きさ（主画面の左上が原点。x, y, 幅, 高さ）。
    static let defaultFrame = NSRect(x: 140, y: 64, width: 1000, height: 660)

    /// サイドバーの幅。
    static let sidebarWidth: CGFloat = 200

    /// サイドバーの項目の位置（上から 4 つ）。
    static let sidebarItems = (0..<4).map { index in
        NSRect(x: 8, y: 16 + CGFloat(index) * 30, width: 184, height: 28)
    }

    /// サイドバーの項目の中の棒の幅（上から 4 つ）。
    static let sidebarBarWidths: [CGFloat] = [72, 96, 60, 84]

    /// フォームの入れ物（サイドバーの右）。
    static let form = NSRect(x: 200, y: 0, width: 800, height: 608)

    /// 見出しの 1 本目の棒。
    static let headingTitle = NSRect(x: 240, y: 36, width: 180, height: 14)

    /// 見出しの 2 本目の棒。
    static let headingSubtitle = NSRect(x: 240, y: 60, width: 320, height: 8)

    /// 入力欄のラベル（灰色の棒。上から 3 つ）。
    static let fieldLabels = [
        NSRect(x: 240, y: 98, width: 110, height: 8),
        NSRect(x: 240, y: 162, width: 80, height: 8),
        NSRect(x: 240, y: 268, width: 90, height: 8),
    ]

    /// 1 つ目の入力欄（1 行）。
    static let firstField = NSRect(x: 240, y: 112, width: 420, height: 30)

    /// 2 つ目の入力欄（複数行）。
    static let secondField = NSRect(x: 240, y: 176, width: 560, height: 72)

    /// 3 つ目の入力欄（1 行）。
    static let thirdField = NSRect(x: 240, y: 282, width: 320, height: 30)

    /// 区切り線。
    static let separator = NSRect(x: 240, y: 344, width: 720, height: 1)

    /// `Cancel` ボタン。
    static let cancel = NSRect(x: 784, y: 365, width: 76, height: 30)

    /// `Submit` ボタン。
    static let submit = NSRect(x: 868, y: 365, width: 92, height: 30)

    /// `Submit` を押した回数の見出し（ボタンの行の左端）。幅は文言なり。
    static let countCaption = NSRect(x: 240, y: 372, width: 0, height: 16)

    /// `Submit` を押した回数。x は見出しの右端からのずれ。
    static let count = NSRect(x: 0, y: 372, width: 60, height: 16)

    /// 回数の見出しと回数の間隔。
    static let countSpacing: CGFloat = 8

    /// 入力欄の中の文字の左右の余白。
    static let fieldInset: CGFloat = 8

    /// 入力欄・ボタンの角丸。
    static let controlRadius: CGFloat = 6

    /// 文字の大きさ。
    static let fontSize: CGFloat = 13
}

/// Sample App の色。
enum SampleColor {
    /// 本文の地。
    static let background = NSColor(hex: 0xFFFFFF)

    /// サイドバーの地。
    static let sidebar = NSColor(hex: 0xF4F4F6)

    /// サイドバーの右の線と、選択中の項目の地。
    static let sidebarLine = NSColor(hex: 0x000000, alpha: 0x14)

    /// サイドバーの選択中の項目の地。
    static let sidebarSelection = NSColor(hex: 0x000000, alpha: 0x12)

    /// サイドバーの選択中の項目の棒。
    static let selectedBar = NSColor(hex: 0xAEAEB2)

    /// サイドバーのほかの項目の棒と、入力欄のラベル。
    static let bar = NSColor(hex: 0xD1D1D6)

    /// 見出しの 1 本目。
    static let headingTitle = NSColor(hex: 0xC7C7CC)

    /// 見出しの 2 本目。
    static let headingSubtitle = NSColor(hex: 0xE5E5EA)

    /// 入力欄と `Cancel` の輪郭。
    static let outline = NSColor(hex: 0x000000, alpha: 0x29)

    /// 区切り線。
    static let separator = NSColor(hex: 0x000000, alpha: 0x1A)

    /// `Submit` の地。
    static let accent = NSColor(hex: 0x0A64D2)

    /// 文字の色。
    static let text = NSColor(hex: 0x000000)

    /// 回数の見出しの色。
    static let secondaryText = NSColor(hex: 0x62626A)

    /// `Submit` の文字の色。
    static let accentText = NSColor(hex: 0xFFFFFF)
}

extension NSColor {
    /// `0xRRGGBB` と不透明度（0〜255）から sRGB の色を作る。
    convenience init(hex: UInt32, alpha: UInt32 = 0xFF) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: CGFloat(alpha) / 255)
    }
}
