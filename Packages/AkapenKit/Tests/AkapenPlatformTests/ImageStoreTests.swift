import Foundation
import Testing
import AkapenPlatform

@MainActor
struct ImageStoreTests {
    private let utc = TimeZone(identifier: "UTC")!

    @Test
    func saveWritesIntoSessionFolder() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let root = temporary.child("cache")
        let store = FileImageStore(root: root, timeZone: utc)
        let url = try store.save(png: Data("first".utf8), sessionID: "20261117-1432", index: 1)
        #expect(url.standardizedFileURL == root.appending(path: "20261117-1432/01.png").standardizedFileURL)
        #expect(try Data(contentsOf: url) == Data("first".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: root.appending(path: "20261117-1432").path())
        #expect(names == ["01.png"])
    }

    @Test
    func saveNeverOverwritesExistingFile() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        let first = try store.save(png: Data("first".utf8), sessionID: "20261117-1432", index: 1)
        let second = try store.save(png: Data("second".utf8), sessionID: "20261117-1432", index: 1)
        #expect(first.lastPathComponent == "01.png")
        #expect(second.lastPathComponent == "02.png")
        #expect(try Data(contentsOf: first) == Data("first".utf8))
        #expect(try Data(contentsOf: second) == Data("second".utf8))
        let names = try FileManager.default.contentsOfDirectory(atPath: first.deletingLastPathComponent().path())
        #expect(names.sorted() == ["01.png", "02.png"])
    }

    @Test
    func saveSkipsTakenNumbersFromRequestedIndex() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let folder = temporary.child("20261117-1432")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("old3".utf8).write(to: folder.appending(path: "03.png"))
        try Data("old4".utf8).write(to: folder.appending(path: "04.png"))
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        let url = try store.save(png: Data("new".utf8), sessionID: "20261117-1432", index: 3)
        #expect(url.lastPathComponent == "05.png")
        #expect(try Data(contentsOf: folder.appending(path: "03.png")) == Data("old3".utf8))
        #expect(try Data(contentsOf: folder.appending(path: "04.png")) == Data("old4".utf8))
    }

    @Test
    func saveRejectsInvalidSessionIDAndIndex() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        #expect(throws: FileImageStore.StoreError.invalidSessionID("../20261117-1432")) {
            try store.save(png: Data(), sessionID: "../20261117-1432", index: 1)
        }
        #expect(throws: FileImageStore.StoreError.invalidIndex(0)) {
            try store.save(png: Data(), sessionID: "20261117-1432", index: 0)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: temporary.url.path()).isEmpty)
    }

    @Test
    func removeDeletesFileUnderRoot() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        let url = try store.save(png: Data("x".utf8), sessionID: "20261117-1432", index: 1)
        try store.remove(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path()))
        #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path()))
    }

    @Test
    func removeRejectsFilesOutsideRoot() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let root = temporary.child("root")
        let outsideFolder = temporary.child("outside")
        try FileManager.default.createDirectory(at: root.appending(path: "20261117-1432"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideFolder, withIntermediateDirectories: true)
        let outside = outsideFolder.appending(path: "keep.png")
        try Data("keep".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appending(path: "link"), withDestinationURL: outsideFolder)
        let store = FileImageStore(root: root, timeZone: utc)

        let direct = outside
        let dotDot = URL(filePath: root.path() + "/20261117-1432/../../outside/keep.png")
        let throughLink = root.appending(path: "link/keep.png")
        for url in [direct, dotDot, throughLink] {
            #expect(throws: FileImageStore.StoreError.outsideRoot(url)) {
                try store.remove(at: url)
            }
        }
        #expect(throws: FileImageStore.StoreError.self) {
            try store.remove(at: URL(string: "https://example.com/01.png")!)
        }
        #expect(try Data(contentsOf: outside) == Data("keep".utf8))
    }

    @Test
    func removeRejectsFolders() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let folder = temporary.child("20261117-1432")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        #expect(throws: FileImageStore.StoreError.notAFile(folder)) {
            try store.remove(at: folder)
        }
        #expect(throws: FileImageStore.StoreError.self) {
            try store.remove(at: temporary.url)
        }
        #expect(FileManager.default.fileExists(atPath: folder.path()))
    }

    @Test
    func removeSessionsDeletesOnlyOldSessionFolders() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let manager = FileManager.default
        for name in ["20261101-0900", "20261109-2359", "20261110-0000", "20261117-1432", "notes", "2026-11-01"] {
            try manager.createDirectory(at: temporary.child(name), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: temporary.child(name).appending(path: "01.png"))
        }
        try Data("file".utf8).write(to: temporary.child("20261102-1000"))
        try Data("file".utf8).write(to: temporary.child("readme.txt"))
        let elsewhere = temporary.child("elsewhere")
        try manager.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let store = FileImageStore(root: temporary.url, timeZone: utc)
        let cutoff = try #require(ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z"))

        try store.removeSessions(before: cutoff)

        let remaining = try manager.contentsOfDirectory(atPath: temporary.url.path()).sorted()
        #expect(remaining == ["2026-11-01", "20261102-1000", "20261110-0000", "20261117-1432", "elsewhere", "notes", "readme.txt"])
    }

    @Test
    func removeSessionsDoesNotFollowSymbolicLinks() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let root = temporary.child("root")
        let target = temporary.child("target")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: target.appending(path: "01.png"))
        try FileManager.default.createSymbolicLink(at: root.appending(path: "20261101-0900"), withDestinationURL: target)
        let store = FileImageStore(root: root, timeZone: utc)
        let cutoff = try #require(ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z"))

        try store.removeSessions(before: cutoff)

        #expect(FileManager.default.fileExists(atPath: target.appending(path: "01.png").path()))
    }

    @Test
    func removeSessionsWithoutRootDoesNothing() throws {
        let temporary = try TemporaryDirectory()
        defer { temporary.remove() }
        let store = FileImageStore(root: temporary.child("missing"), timeZone: utc)
        try store.removeSessions(before: Date(timeIntervalSince1970: 2_000_000_000))
        #expect(!FileManager.default.fileExists(atPath: temporary.child("missing").path()))
    }

    @Test
    func defaultRootIsUserCachesFolder() {
        let root = FileImageStore.defaultRoot()
        #expect(root.lastPathComponent == "akapen")
        #expect(root.deletingLastPathComponent().path().hasSuffix("/Library/Caches/"))
    }
}
