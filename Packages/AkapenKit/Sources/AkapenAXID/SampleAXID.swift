/// 撮影対象のアプリ（`SampleTarget`）の識別子のうち、`AXID.swift` にない分。
///
/// `AXID.Sample.button`（`Submit`）と `AXID.Sample.count`（`Submit` を押した回数）は `AXID.swift` にある。
extension AXID.Sample {
    /// `SampleTarget` のウィンドウ。枠を描くときの基準にする。
    public static let window = "sample.window"

    /// 左のサイドバー。
    public static let sidebar = "sample.sidebar"

    /// 右のフォームの入れ物。
    public static let form = "sample.form"

    /// フォームの上の見出し（灰色の棒 2 本）。
    public static let heading = "sample.heading"

    /// 1 つ目の入力欄（1 行）。
    public static let firstField = "sample.firstField"

    /// 2 つ目の入力欄（複数行）。
    public static let secondField = "sample.secondField"

    /// 3 つ目の入力欄（1 行）。
    public static let thirdField = "sample.thirdField"

    /// `Cancel` ボタン。押すと 3 つの入力欄を空にする。
    public static let cancel = "sample.cancel"

    /// サイドバーの項目。引数は上からのゼロ始まりの番号（0〜3）。
    public static func sidebarItem(_ index: Int) -> String {
        "sample.sidebarItem.\(index)"
    }
}
