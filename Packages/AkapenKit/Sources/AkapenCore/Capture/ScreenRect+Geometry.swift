extension ScreenRect {
    /// 右端の x。
    var maxX: Double {
        x + width
    }

    /// 下端の y（左上原点なので、下へ行くほど大きい）。
    var maxY: Double {
        y + height
    }

    /// 面積。
    var area: Double {
        width * height
    }

    /// 2 つの矩形の重なり。重なりの面積が 0（辺で接するだけを含む）なら nil。
    func intersection(_ other: ScreenRect) -> ScreenRect? {
        let left = Swift.max(x, other.x)
        let top = Swift.max(y, other.y)
        let right = Swift.min(maxX, other.maxX)
        let bottom = Swift.min(maxY, other.maxY)
        guard right > left, bottom > top else {
            return nil
        }
        return ScreenRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
