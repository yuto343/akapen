import CoreGraphics
import AkapenCore

/// パネルと表示の置き場所の計算。AppKit のウィンドウに依存しない純粋な関数。
///
/// 座標はすべて、画面全体を通した左上原点（`ScreenRect` と同じ。下へ行くほど y が大きい）。
/// 引数の `size` は部品の見た目の大きさ（影を含まない）、戻り値も部品の見た目の矩形。
/// AppKit の左下原点への変換は `ScreenCoordinates` でだけ行う。
enum PanelPlacement {
    /// 画面下の左右中央（ボタン類・コピー完了の表示）。`visibleFrame`（Dock を除いた範囲）の下端から 16pt 上（`DECISIONS.md` 4・10）。
    static func bottomCenter(size: CGSize, visibleFrame: ScreenRect) -> ScreenRect {
        ScreenRect(
            x: visibleFrame.centerX - size.width / 2,
            y: visibleFrame.edgeBottom - Tokens.Placement.bottomInset - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// 案内の表示。`visibleFrame` の上端（メニューバーの下端）から 16pt 下、左右中央（`DECISIONS.md` 5）。
    static func hint(size: CGSize, visibleFrame: ScreenRect) -> ScreenRect {
        ScreenRect(
            x: visibleFrame.centerX - size.width / 2,
            y: visibleFrame.y + Tokens.Placement.hintTopInset,
            width: size.width,
            height: size.height
        )
    }

    /// 一覧。ボタン類の真上に 12pt 空けて置き、左右中央をボタン類に揃える（`DECISIONS.md` 6）。
    /// 上に入りきらないときは、`visibleFrame` の上端に寄せる。
    static func list(size: CGSize, toolbar: ScreenRect, visibleFrame: ScreenRect) -> ScreenRect {
        let y = toolbar.y - Tokens.Placement.listGap - size.height
        return ScreenRect(
            x: toolbar.centerX - size.width / 2,
            y: max(visibleFrame.y, y),
            width: size.width,
            height: size.height
        )
    }

    /// コメント入力（`DECISIONS.md` 8）。
    ///
    /// 赤枠の下端から 12pt 下に置き、右端を赤枠の右端に揃える。下に入りきらないときは赤枠の上（上端から 12pt 上）。
    /// それも入りきらないときは赤枠の内側の下端（下端から 12pt 内側）。
    /// 左右と上下は、`visibleFrame` の端から 8pt の内側に収まるようにずらす。
    static func comment(size: CGSize, frame: ScreenRect, visibleFrame: ScreenRect) -> ScreenRect {
        let gap = Tokens.Placement.commentGap
        let margin = Tokens.Placement.screenMargin
        let top = visibleFrame.y + margin
        let bottom = visibleFrame.edgeBottom - margin
        let below = frame.edgeBottom + gap
        let above = frame.y - gap - size.height
        let y: Double
        if below + size.height <= bottom {
            y = below
        } else if above >= top {
            y = above
        } else {
            y = frame.edgeBottom - gap - size.height
        }
        return ScreenRect(
            x: clamp(frame.edgeRight - size.width, lower: visibleFrame.x + margin, upper: visibleFrame.edgeRight - margin - size.width),
            y: clamp(y, lower: top, upper: bottom - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// 大きさの表示。カーソルに付いていく（上端がカーソルの 10pt 下、右端がカーソルの 15pt 左。`DECISIONS.md` 7）。
    /// `visibleFrame` からはみ出すときは、はみ出さない側（下にはみ出すなら上、左にはみ出すなら右）へ反転する。
    static func sizeLabel(size: CGSize, cursor: CGPoint, visibleFrame: ScreenRect) -> ScreenRect {
        let offsetX = Tokens.Placement.sizeLabelOffsetX
        let offsetY = Tokens.Placement.sizeLabelOffsetY
        var x = cursor.x - offsetX - size.width
        var y = cursor.y + offsetY
        if y + size.height > visibleFrame.edgeBottom {
            y = cursor.y - offsetY - size.height
        }
        if x < visibleFrame.x {
            x = cursor.x + offsetX
        }
        return ScreenRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// 下限を優先して範囲に収める（範囲が逆転しているときは下限）。
    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        max(lower, min(value, upper))
    }
}

/// 置き場所の計算に使う `ScreenRect` の値。名前は `AkapenCore` 側の拡張と重ならないものにしている。
extension ScreenRect {
    /// 右端の x。
    var edgeRight: Double {
        x + width
    }

    /// 下端の y（左上原点なので、下へ行くほど大きい）。
    var edgeBottom: Double {
        y + height
    }

    /// 左右の中心。
    var centerX: Double {
        x + width / 2
    }

    /// 上下の中心。
    var centerY: Double {
        y + height / 2
    }

    /// 点を含むか（左端・上端を含み、右端・下端を含まない）。
    func containsPoint(_ point: CGPoint) -> Bool {
        point.x >= x && point.x < edgeRight && point.y >= y && point.y < edgeBottom
    }

    /// 四方を `amount` だけ外へ広げた矩形。
    func expanded(by amount: Double) -> ScreenRect {
        ScreenRect(x: x - amount, y: y - amount, width: width + amount * 2, height: height + amount * 2)
    }
}
