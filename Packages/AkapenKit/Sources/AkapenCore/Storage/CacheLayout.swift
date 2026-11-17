import Foundation

/// 画像の置き場の決め方。回ごとのフォルダ名とファイル名、古い回の選び出し。
///
/// どれも純粋な関数。タイムゾーンは呼び出し側から受け取り、手元の設定に左右されない。
public enum CacheLayout {
    /// 画像ファイルの拡張子。
    public static let imageExtension = "png"

    /// 回の ID（`yyyyMMdd-HHmm`）。`date` を `timeZone` の暦で表した日時から作る。
    public static func sessionID(for date: Date, timeZone: TimeZone) -> String {
        let parts = calendar(timeZone).dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let year = pad(parts.year ?? 0, width: 4)
        let month = pad(parts.month ?? 0, width: 2)
        let day = pad(parts.day ?? 0, width: 2)
        let hour = pad(parts.hour ?? 0, width: 2)
        let minute = pad(parts.minute ?? 0, width: 2)
        return "\(year)\(month)\(day)-\(hour)\(minute)"
    }

    /// 回の中の `index` 番目（1 始まり）の画像のファイル名。`01.png`、`02.png` …、100 番目からは `100.png`。
    public static func fileName(index: Int) -> String {
        "\(pad(index, width: 2)).\(imageExtension)"
    }

    /// 回の ID を、その回が始まった日時（分の頭）に戻す。形が違えば nil。
    public static func date(fromSessionID sessionID: String, timeZone: TimeZone) -> Date? {
        let characters = Array(sessionID)
        guard characters.count == 13, characters[8] == "-" else {
            return nil
        }
        let digits = characters[0..<8] + characters[9..<13]
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        let text = String(digits)
        func number(_ offset: Int, _ length: Int) -> Int {
            let start = text.index(text.startIndex, offsetBy: offset)
            let end = text.index(start, offsetBy: length)
            return Int(text[start..<end]) ?? 0
        }
        var parts = DateComponents()
        parts.year = number(0, 4)
        parts.month = number(4, 2)
        parts.day = number(6, 2)
        parts.hour = number(8, 2)
        parts.minute = number(10, 2)
        let calendar = calendar(timeZone)
        guard parts.isValidDate(in: calendar), let date = calendar.date(from: parts) else {
            return nil
        }
        return date
    }

    /// `sessionIDs` のうち、始まった日時が `date` より前の回を、渡された順のまま返す。
    /// 回の ID として読めない名前（ほかのファイルなど）は選ばない。
    public static func sessionIDs(_ sessionIDs: [String], olderThan date: Date, timeZone: TimeZone) -> [String] {
        sessionIDs.filter { sessionID in
            guard let started = self.date(fromSessionID: sessionID, timeZone: timeZone) else {
                return false
            }
            return started < date
        }
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func pad(_ value: Int, width: Int) -> String {
        let text = String(value)
        guard text.count < width else {
            return text
        }
        return String(repeating: "0", count: width - text.count) + text
    }
}
