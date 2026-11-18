import SwiftUI

/// SVG の `d` 属性（パスのデータ）を `Path` にする。Paper から写したアイコンの形を、そのまま描くために使う。
///
/// 扱う命令は `M L H V C S Q T A Z`（小文字の相対指定を含む）。読めない文字があれば、そこまでの形を返す。
enum SVGPath {
    /// パスのデータを読む。
    static func parse(_ data: String) -> Path {
        var reader = Reader(data)
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var lastQuadControl: CGPoint?
        var command: Character?
        while let next = reader.nextCommand(previous: command) {
            command = next
            let relative = next.isLowercase
            let base = relative ? current : .zero
            switch next.uppercased() {
            case "M":
                guard let point = reader.point() else {
                    return path
                }
                current = point.offset(by: base)
                start = current
                path.move(to: current)
                // M のあとに続く座標は L として扱う。
                command = relative ? "l" : "L"
                lastControl = nil
                lastQuadControl = nil
            case "L":
                guard let point = reader.point() else {
                    return path
                }
                current = point.offset(by: base)
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "H":
                guard let x = reader.number() else {
                    return path
                }
                current = CGPoint(x: x + (relative ? current.x : 0), y: current.y)
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "V":
                guard let y = reader.number() else {
                    return path
                }
                current = CGPoint(x: current.x, y: y + (relative ? current.y : 0))
                path.addLine(to: current)
                lastControl = nil
                lastQuadControl = nil
            case "C":
                guard let first = reader.point(), let second = reader.point(), let end = reader.point() else {
                    return path
                }
                let control2 = second.offset(by: base)
                current = end.offset(by: base)
                path.addCurve(to: current, control1: first.offset(by: base), control2: control2)
                lastControl = control2
                lastQuadControl = nil
            case "S":
                guard let second = reader.point(), let end = reader.point() else {
                    return path
                }
                let control1 = lastControl.map { current.reflecting($0) } ?? current
                let control2 = second.offset(by: base)
                current = end.offset(by: base)
                path.addCurve(to: current, control1: control1, control2: control2)
                lastControl = control2
                lastQuadControl = nil
            case "Q":
                guard let control = reader.point(), let end = reader.point() else {
                    return path
                }
                let absoluteControl = control.offset(by: base)
                current = end.offset(by: base)
                path.addQuadCurve(to: current, control: absoluteControl)
                lastQuadControl = absoluteControl
                lastControl = nil
            case "T":
                guard let end = reader.point() else {
                    return path
                }
                let control = lastQuadControl.map { current.reflecting($0) } ?? current
                current = end.offset(by: base)
                path.addQuadCurve(to: current, control: control)
                lastQuadControl = control
                lastControl = nil
            case "A":
                guard let radiusX = reader.number(),
                      let radiusY = reader.number(),
                      let rotation = reader.number(),
                      let largeArc = reader.flag(),
                      let sweep = reader.flag(),
                      let end = reader.point() else {
                    return path
                }
                let target = end.offset(by: base)
                addArc(
                    to: &path,
                    from: current,
                    to: target,
                    radii: CGSize(width: radiusX, height: radiusY),
                    rotation: rotation,
                    largeArc: largeArc,
                    sweep: sweep
                )
                current = target
                lastControl = nil
                lastQuadControl = nil
            case "Z":
                path.closeSubpath()
                current = start
                lastControl = nil
                lastQuadControl = nil
            default:
                return path
            }
        }
        return path
    }

    /// SVG の円弧（端点で指定）を、ベジェ曲線で足す（SVG 1.1 の付録 F.6 の手順）。
    private static func addArc(
        to path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        radii: CGSize,
        rotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        var radiusX = abs(radii.width)
        var radiusY = abs(radii.height)
        guard radiusX > 0, radiusY > 0, start != end else {
            path.addLine(to: end)
            return
        }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (radiusX * radiusX) + (y1 * y1) / (radiusY * radiusY)
        if lambda > 1 {
            radiusX *= sqrt(lambda)
            radiusY *= sqrt(lambda)
        }
        let numerator = radiusX * radiusX * radiusY * radiusY - radiusX * radiusX * y1 * y1 - radiusY * radiusY * x1 * x1
        let denominator = radiusX * radiusX * y1 * y1 + radiusY * radiusY * x1 * x1
        var factor = sqrt(max(0, numerator / denominator))
        if largeArc == sweep {
            factor = -factor
        }
        let centerX1 = factor * radiusX * y1 / radiusY
        let centerY1 = -factor * radiusY * x1 / radiusX
        let center = CGPoint(
            x: cosPhi * centerX1 - sinPhi * centerY1 + (start.x + end.x) / 2,
            y: sinPhi * centerX1 + cosPhi * centerY1 + (start.y + end.y) / 2
        )
        let startAngle = angle(from: CGPoint(x: 1, y: 0), to: CGPoint(x: (x1 - centerX1) / radiusX, y: (y1 - centerY1) / radiusY))
        var delta = angle(
            from: CGPoint(x: (x1 - centerX1) / radiusX, y: (y1 - centerY1) / radiusY),
            to: CGPoint(x: (-x1 - centerX1) / radiusX, y: (-y1 - centerY1) / radiusY)
        )
        if !sweep && delta > 0 {
            delta -= 2 * .pi
        } else if sweep && delta < 0 {
            delta += 2 * .pi
        }
        // 90 度ごとに分けて、それぞれを 3 次のベジェ曲線で近づける。
        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let handle = 4 / 3 * tan(step / 4)
        func point(_ theta: CGFloat) -> CGPoint {
            let x = radiusX * cos(theta)
            let y = radiusY * sin(theta)
            return CGPoint(x: center.x + cosPhi * x - sinPhi * y, y: center.y + sinPhi * x + cosPhi * y)
        }
        func derivative(_ theta: CGFloat) -> CGPoint {
            let x = -radiusX * sin(theta)
            let y = radiusY * cos(theta)
            return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
        }
        var theta = startAngle
        for index in 0..<segments {
            let next = theta + step
            let from = point(theta)
            let to = index == segments - 1 ? end : point(next)
            let d1 = derivative(theta)
            let d2 = derivative(next)
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x + handle * d1.x, y: from.y + handle * d1.y),
                control2: CGPoint(x: to.x - handle * d2.x, y: to.y - handle * d2.y)
            )
            theta = next
        }
    }

    private static func angle(from u: CGPoint, to v: CGPoint) -> CGFloat {
        let dot = u.x * v.x + u.y * v.y
        let length = sqrt(u.x * u.x + u.y * u.y) * sqrt(v.x * v.x + v.y * v.y)
        var value = acos(max(-1, min(1, dot / length)))
        if u.x * v.y - u.y * v.x < 0 {
            value = -value
        }
        return value
    }

    /// パスのデータを、命令の文字と数に分けて読む。
    private struct Reader {
        private let scalars: [Character]
        private var index = 0

        init(_ data: String) {
            scalars = Array(data)
        }

        /// 次の命令。命令の文字がなく数が続くときは、前の命令をくり返す。
        mutating func nextCommand(previous: Character?) -> Character? {
            skipSeparators()
            guard index < scalars.count else {
                return nil
            }
            let character = scalars[index]
            if character.isLetter {
                index += 1
                return character
            }
            return previous
        }

        mutating func point() -> CGPoint? {
            guard let x = number(), let y = number() else {
                return nil
            }
            return CGPoint(x: x, y: y)
        }

        /// 円弧の 0 / 1 の旗。`a2 2 0 0 0-.5.83` のように区切りなしで続くことがある。
        mutating func flag() -> Bool? {
            skipSeparators()
            guard index < scalars.count else {
                return nil
            }
            let character = scalars[index]
            guard character == "0" || character == "1" else {
                return nil
            }
            index += 1
            return character == "1"
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = index
            var seenDot = false
            var seenExponent = false
            if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" {
                index += 1
            }
            while index < scalars.count {
                let character = scalars[index]
                if character.isNumber {
                    index += 1
                } else if character == ".", !seenDot, !seenExponent {
                    seenDot = true
                    index += 1
                } else if character == "e" || character == "E", !seenExponent {
                    seenExponent = true
                    index += 1
                    if index < scalars.count, scalars[index] == "-" || scalars[index] == "+" {
                        index += 1
                    }
                } else {
                    break
                }
            }
            guard index > begin, let value = Double(String(scalars[begin..<index])) else {
                index = begin
                return nil
            }
            return CGFloat(value)
        }

        private mutating func skipSeparators() {
            while index < scalars.count, scalars[index] == " " || scalars[index] == "," || scalars[index].isNewline {
                index += 1
            }
        }
    }
}

private extension CGPoint {
    func offset(by base: CGPoint) -> CGPoint {
        CGPoint(x: x + base.x, y: y + base.y)
    }

    /// `control` を自分を中心に反転した点（`S` と `T` の、省かれた制御点）。
    func reflecting(_ control: CGPoint) -> CGPoint {
        CGPoint(x: 2 * x - control.x, y: 2 * y - control.y)
    }
}
