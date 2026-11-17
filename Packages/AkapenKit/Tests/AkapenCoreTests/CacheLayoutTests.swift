import Foundation
import Testing
import AkapenCore

private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
private let utc = TimeZone(identifier: "UTC")!

/// 2026-11-17 05:32:45 UTC（東京では 14:32:45）。
private let sample = Date(timeIntervalSince1970: 1_794_893_565)

@Test
func sessionIDUsesGivenTimeZone() {
    #expect(CacheLayout.sessionID(for: sample, timeZone: tokyo) == "20261117-1432")
    #expect(CacheLayout.sessionID(for: sample, timeZone: utc) == "20261117-0532")
}

@Test
func sessionIDPadsEveryField() {
    // 2027-01-02 03:04:00 UTC
    let date = Date(timeIntervalSince1970: 1_798_859_040)
    #expect(CacheLayout.sessionID(for: date, timeZone: utc) == "20270102-0304")
}

@Test(arguments: [
    (1, "01.png"),
    (2, "02.png"),
    (9, "09.png"),
    (10, "10.png"),
    (99, "99.png"),
    (100, "100.png"),
])
func fileNames(index: Int, name: String) {
    #expect(CacheLayout.fileName(index: index) == name)
}

@Test
func sessionIDRoundTripsToStartOfMinute() throws {
    let id = CacheLayout.sessionID(for: sample, timeZone: tokyo)
    let date = try #require(CacheLayout.date(fromSessionID: id, timeZone: tokyo))
    // 秒は切り捨てて分の頭になる。
    #expect(date == sample.addingTimeInterval(-45))
    #expect(CacheLayout.date(fromSessionID: id, timeZone: utc) == date.addingTimeInterval(9 * 3600))
}

@Test(arguments: [
    "",
    "20261117",
    "20261117_1432",
    "20261117-143",
    "20261117-14320",
    "2026111a-1432",
    "20261317-1432",
    "20261132-1432",
    "20261117-2460",
    ".DS_Store",
    "２0261117-1432",
])
func invalidSessionIDs(id: String) {
    #expect(CacheLayout.date(fromSessionID: id, timeZone: utc) == nil)
}

@Test
func selectsSessionsOlderThanDate() {
    let ids = [
        "20261110-1431",
        "20261110-1432",
        "20261110-1433",
        "20261117-1432",
        "notes.txt",
        "20251231-2359",
    ]
    // 東京の 2026-11-10 14:32:00。
    let cutoff = CacheLayout.date(fromSessionID: "20261110-1432", timeZone: tokyo)!
    let older = CacheLayout.sessionIDs(ids, olderThan: cutoff, timeZone: tokyo)
    // ちょうど同じ時刻の回は残す。
    #expect(older == ["20261110-1431", "20251231-2359"])
}
