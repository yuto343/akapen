import Foundation
import Testing
@testable import AkapenCore

private typealias Harness = SessionHarness

// MARK: - 枠を描く

@Test
@MainActor
func hotkeyStartsDrawingFromHidden() async throws {
    let harness = try Harness()
    let model = harness.model
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
}

@Test
@MainActor
func dragCapturesWindowAndStartsCommenting() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.clock.advance(by: .seconds(5))
    await harness.drag()
    #expect(model.phase == .commenting)
    #expect(model.lastDrawnRect == Harness.frame)
    #expect(model.lastFailure == nil)
    let draft = try #require(model.draft)
    #expect(draft.comment == "")
    #expect(draft.rect == Harness.frame)
    #expect(draft.sourceAppName == "Sample App")
    #expect(draft.windowFrame == FakeCapturer.sampleWindow.frame)
    #expect(draft.createdAt == Harness.start.addingTimeInterval(5))
    #expect(draft.imagePath == "/akapen-test-cache/20261118-1432/01.png")
    #expect(harness.capturer.capturedWindows == [FakeCapturer.sampleWindow])
    // 保存された画像には、赤枠が描き込まれている。
    let saved = try #require(harness.images.files[draft.imagePath])
    let bitmap = try #require(TestImages.decode(saved))
    #expect(bitmap.width == 800)
    #expect(bitmap.height == 600)
    #expect(bitmap.frameRedBox() == TestImages.PixelBox(minX: 94, minY: 94, maxX: 305, maxY: 205))
    #expect(model.annotations.isEmpty)
}

@Test
@MainActor
func dragPicksWindowWithLargestOverlap() async throws {
    let front = CaptureWindow(id: 1, frame: ScreenRect(x: 0, y: 0, width: 160, height: 400), appName: "Front")
    let back = FakeCapturer.sampleWindow
    let harness = try Harness(windows: [front, back])
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(harness.capturer.capturedWindows == [back])
    #expect(harness.model.draft?.sourceAppName == "Sample App")
}

@Test
@MainActor
func tinyDragDoesNothing() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    for rect in [
        ScreenRect(x: 150, y: 100, width: 3.9, height: 50),
        ScreenRect(x: 150, y: 100, width: 50, height: 3.9),
        ScreenRect(x: 150, y: 100, width: 0, height: 0),
    ] {
        await harness.drag(rect)
        #expect(model.phase == .drawing)
        #expect(model.lastDrawnRect == rect)
        #expect(model.lastFailure == nil)
    }
    #expect(harness.capturer.windowsCalls == 0)
    // 4pt ちょうどは撮る。
    await harness.drag(ScreenRect(x: 150, y: 100, width: 4, height: 4))
    #expect(model.phase == .commenting)
}

@Test
@MainActor
func dragWithoutWindowUnderFrameFails() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    let outside = ScreenRect(x: 900, y: 700, width: 50, height: 50)
    await harness.drag(outside)
    #expect(model.phase == .drawing)
    #expect(model.lastFailure == .noWindowUnderFrame)
    #expect(model.lastDrawnRect == outside)
    #expect(model.draft == nil)
    #expect(harness.capturer.capturedWindows.isEmpty)
    #expect(harness.images.files.isEmpty)
    // 次の入力が成功したら失敗は消える。
    await harness.drag()
    #expect(model.phase == .commenting)
    #expect(model.lastFailure == nil)
}

@Test
@MainActor
func listingWindowsFailureIsCaptureFailed() async throws {
    let harness = try Harness()
    harness.capturer.windowsError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(harness.model.phase == .drawing)
    #expect(harness.model.lastFailure == .captureFailed)
    #expect(harness.model.draft == nil)
}

@Test
@MainActor
func captureFailureKeepsDrawing() async throws {
    let harness = try Harness()
    harness.capturer.captureError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(harness.model.phase == .drawing)
    #expect(harness.model.lastFailure == .captureFailed)
    #expect(harness.model.draft == nil)
    #expect(harness.images.saveCalls.isEmpty)
}

@Test
@MainActor
func unreadableCaptureIsCaptureFailed() async throws {
    let harness = try Harness()
    harness.capturer.pngOverride = Data("broken".utf8)
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(harness.model.phase == .drawing)
    #expect(harness.model.lastFailure == .captureFailed)
    #expect(harness.images.saveCalls.isEmpty)
}

@Test
@MainActor
func imageSaveFailureKeepsDrawing() async throws {
    let harness = try Harness()
    harness.images.saveError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(harness.model.phase == .drawing)
    #expect(harness.model.lastFailure == .imageSaveFailed)
    #expect(harness.model.draft == nil)
    // 失敗した番号は、次の撮影で使い直す。
    harness.images.saveError = nil
    await harness.drag()
    #expect(harness.model.draft?.imagePath == "/akapen-test-cache/20261118-1432/01.png")
}

@Test
@MainActor
func dragWithoutCaptureDependenciesFails() async throws {
    // 撮影に要る依存がないときは、撮影できなかったのと同じに扱い、`drawing` のまま。注釈も画像も作らない。
    let model = try SessionModel(settingsStore: FakeSettingsStore())
    model.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    let rect = ScreenRect(x: -30, y: 20, width: 50, height: 70)
    await model.send(.dragEnded(rect: rect, screen: ScreenDescriptor(id: 1, frame: rect))).value
    #expect(model.phase == .drawing)
    #expect(model.lastFailure == .captureFailed)
    #expect(model.lastDrawnRect == rect)
    #expect(model.draft == nil)
    #expect(model.annotations.isEmpty)
    #expect(model.isToolbarVisible)
}

@Test
@MainActor
func settingsChangedClampsRetentionDays() async throws {
    let harness = try Harness()
    var settings = harness.model.settings
    settings.imageRetentionDays = 0
    await harness.send(.settingsChanged(settings))
    #expect(harness.model.settings.imageRetentionDays == 1)
    #expect(harness.settingsStore.saved.last?.imageRetentionDays == 1)
    settings.imageRetentionDays = 366
    await harness.send(.settingsChanged(settings))
    #expect(harness.model.settings.imageRetentionDays == 365)
    #expect(harness.settingsStore.saved.last?.imageRetentionDays == 365)
    settings.imageRetentionDays = 30
    await harness.send(.settingsChanged(settings))
    #expect(harness.model.settings.imageRetentionDays == 30)
}

@Test
@MainActor
func loadedRetentionDaysAreClamped() throws {
    var stored = Settings()
    stored.imageRetentionDays = -4
    let harness = try Harness(settings: stored)
    #expect(harness.model.settings.imageRetentionDays == 1)
    try harness.model.performStartupCleanup()
    // 0 日以下で「いま」より前をすべて消すのではなく、1 日前より古い回だけを消す。
    #expect(harness.images.removedBefore == [Harness.start.addingTimeInterval(-86_400)])
}

@Test
@MainActor
func currentSessionIDFollowsSession() async throws {
    let harness = try Harness()
    #expect(harness.model.currentSessionID == nil)
    await harness.send(.hotkeyPressed)
    #expect(harness.model.currentSessionID == Harness.sessionID)
}

@Test
@MainActor
func escapeWhileDrawing() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    await harness.annotate("first")
    await harness.send(.addTapped)
    await harness.send(.escapePressed)
    #expect(model.phase == .idle)
    #expect(model.annotations.count == 1)
}

// MARK: - コメント

@Test
@MainActor
func confirmTrimsComment() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.drag()
    let draft = try #require(model.draft)
    await harness.send(.commentConfirmed(text: "  \n ボタンの余白\n2 行目 \n\t"))
    #expect(model.phase == .idle)
    #expect(model.draft == nil)
    #expect(model.isToolbarVisible)
    #expect(model.annotations.count == 1)
    #expect(model.annotations.first?.comment == "ボタンの余白\n2 行目")
    #expect(model.annotations.first?.id == draft.id)
    #expect(model.annotations.first?.imagePath == draft.imagePath)
}

@Test
@MainActor
func emptyCommentIsIgnored() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.drag()
    let draft = model.draft
    let changes = harness.changeCount
    await harness.send(.commentConfirmed(text: " \n\t "))
    #expect(model.phase == .commenting)
    #expect(model.draft == draft)
    #expect(model.annotations.isEmpty)
    #expect(harness.changeCount == changes)
}

@Test
@MainActor
func cancellingCommentDiscardsImage() async throws {
    for event in [SessionEvent.commentCancelled, .escapePressed] {
        let harness = try Harness()
        let model = harness.model
        await harness.send(.hotkeyPressed)
        await harness.drag()
        let path = try #require(model.draft?.imagePath)
        await harness.send(event)
        #expect(model.phase == .hidden)
        #expect(model.draft == nil)
        #expect(harness.images.removedPaths == [path])
        #expect(harness.images.files[path] == nil)
    }
}

@Test
@MainActor
func cancellingCommentWithAnnotationsReturnsToIdle() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("keep")
    let kept = try #require(model.annotations.first)
    await harness.send(.addTapped)
    await harness.drag()
    let discarded = try #require(model.draft?.imagePath)
    #expect(discarded == "/akapen-test-cache/20261118-1432/02.png")
    await harness.send(.commentCancelled)
    #expect(model.phase == .idle)
    #expect(model.annotations == [kept])
    #expect(harness.images.removedPaths == [discarded])
    #expect(harness.images.files[kept.imagePath] != nil)
}

@Test
@MainActor
func cancelStillLeavesWhenImageRemovalFails() async throws {
    let harness = try Harness()
    harness.images.removeError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    await harness.send(.commentCancelled)
    #expect(harness.model.phase == .hidden)
    #expect(harness.model.draft == nil)
}

@Test
@MainActor
func commentingIgnoresHotkeyAndAdd() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.drag()
    let draft = model.draft
    let changes = harness.changeCount
    for event in [SessionEvent.hotkeyPressed, .addTapped, .listToggled, .copyPromptTapped, .toolbarToggled] {
        await harness.send(event)
        #expect(model.phase == .commenting)
        #expect(model.draft == draft)
    }
    #expect(harness.changeCount == changes)
}

// MARK: - idle と一覧

@Test
@MainActor
func hotkeyAndAddStartDrawingFromIdleAndList() async throws {
    for event in [SessionEvent.hotkeyPressed, .addTapped] {
        let harness = try Harness()
        let model = harness.model
        await harness.annotate("one")
        await harness.send(event)
        #expect(model.phase == .drawing)
        await harness.send(.escapePressed)
        await harness.send(.listToggled)
        #expect(model.phase == .listOpen)
        await harness.send(event)
        #expect(model.phase == .drawing)
        #expect(model.annotations.count == 1)
    }
}

@Test
@MainActor
func hotkeyShowsHiddenToolbar() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(!model.isToolbarVisible)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
    await harness.send(.escapePressed)
    #expect(model.phase == .idle)
    #expect(model.isToolbarVisible)
}

@Test
@MainActor
func listOpensAndCloses() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.listToggled)
    #expect(model.phase == .listOpen)
    await harness.send(.listToggled)
    #expect(model.phase == .idle)
    await harness.send(.listToggled)
    await harness.send(.escapePressed)
    #expect(model.phase == .idle)
    // idle の Esc は何もしない。
    await harness.send(.escapePressed)
    #expect(model.phase == .idle)
}

@Test
@MainActor
func editingReplacesTrimmedComment() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.annotate("two")
    let target = model.annotations[1]
    // 一覧が開いていなければ何もしない。
    await harness.send(.annotationEdited(id: target.id, text: "changed"))
    #expect(model.annotations[1].comment == "two")
    await harness.send(.listToggled)
    await harness.send(.annotationEdited(id: target.id, text: "  changed \n"))
    #expect(model.annotations[1].comment == "changed")
    #expect(model.annotations[0].comment == "one")
    await harness.send(.annotationEdited(id: target.id, text: "   "))
    #expect(model.annotations[1].comment == "changed")
    await harness.send(.annotationEdited(id: UUID(), text: "unknown"))
    #expect(model.annotations.map(\.comment) == ["one", "changed"])
    #expect(model.phase == .listOpen)
}

@Test
@MainActor
func deletingRemovesAnnotationAndImage() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.annotate("two")
    await harness.send(.listToggled)
    let first = model.annotations[0]
    let second = model.annotations[1]
    await harness.send(.annotationDeleted(id: first.id))
    #expect(model.annotations == [second])
    #expect(harness.images.removedPaths == [first.imagePath])
    await harness.send(.annotationDeleted(id: second.id))
    #expect(model.annotations.isEmpty)
    #expect(model.phase == .listOpen)
    #expect(harness.images.removedPaths == [first.imagePath, second.imagePath])
}

// MARK: - コピー

@Test
@MainActor
func copyWritesPromptAndClearsAnnotations() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("ボタンの余白が左右で違う")
    await harness.annotate("ここの文言を「保存する」に")
    let paths = model.annotations.map(\.imagePath)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .copied)
    #expect(!model.isToolbarVisible)
    #expect(model.lastCopiedCount == 2)
    #expect(model.annotations.isEmpty)
    #expect(harness.pasteboard.writes.count == 1)
    #expect(harness.pasteboard.writes.first?.imageURLs == [])
    #expect(harness.pasteboard.lastText == """
        I annotated the screen. Please address the comments below.
        Open every image and check the area marked with the red frame before you start.

        /akapen-test-cache/20261118-1432/01.png
        ボタンの余白が左右で違う

        /akapen-test-cache/20261118-1432/02.png
        ここの文言を「保存する」に
        """)
    // 画像ファイルは消さない。
    #expect(harness.images.removedPaths.isEmpty)
    for path in paths {
        #expect(harness.images.files[path] != nil)
    }
}

@Test
@MainActor
func copyFromListUsesCurrentLanguage() async throws {
    var settings = Settings()
    settings.language = .ja
    let harness = try Harness(settings: settings)
    await harness.annotate("一覧から")
    await harness.send(.listToggled)
    await harness.send(.copyPromptTapped)
    #expect(harness.model.phase == .copied)
    #expect(harness.pasteboard.lastText?.hasPrefix(Boilerplate.japanese + "\n\n") == true)
}

@Test
@MainActor
func copyWithoutAnnotationsDoesNothing() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .idle)
    #expect(harness.pasteboard.writes.isEmpty)
    #expect(model.lastFailure == nil)
}

@Test
@MainActor
func copyAfterDeleteSkipsDeletedAnnotation() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.annotate("two")
    await harness.send(.listToggled)
    await harness.send(.annotationDeleted(id: model.annotations[0].id))
    await harness.send(.copyPromptTapped)
    #expect(model.lastCopiedCount == 1)
    let text = try #require(harness.pasteboard.lastText)
    #expect(text.hasSuffix("\n\n/akapen-test-cache/20261118-1432/02.png\ntwo"))
    #expect(!text.contains("01.png"))
    #expect(!text.contains("one"))
}

@Test
@MainActor
func copyAfterDeletingEverythingDoesNothing() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.listToggled)
    await harness.send(.annotationDeleted(id: model.annotations[0].id))
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .listOpen)
    #expect(harness.pasteboard.writes.isEmpty)
}

@Test
@MainActor
func pasteboardFailureKeepsState() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    let annotations = model.annotations
    harness.pasteboard.writeError = TestError()
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .idle)
    #expect(model.annotations == annotations)
    #expect(model.lastCopiedCount == 0)
    #expect(model.lastFailure == .pasteboardFailed)
    #expect(harness.clock.pendingSleepCount == 0)
    // 直ったあとのコピーで失敗が消える。
    harness.pasteboard.writeError = nil
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .copied)
    #expect(model.lastFailure == nil)
}

@Test
@MainActor
func copyWithoutPasteboardFails() async throws {
    let clock = ManualClock(now: Harness.start)
    let model = try SessionModel(
        settingsStore: FakeSettingsStore(),
        capturing: FakeCapturer(),
        images: FakeImageStore(),
        clock: clock,
        timeZone: Harness.timeZone
    )
    await model.send(.hotkeyPressed).value
    await model.send(.dragEnded(rect: Harness.frame, screen: Harness.screen)).value
    await model.send(.commentConfirmed(text: "one")).value
    await model.send(.copyPromptTapped).value
    #expect(model.phase == .idle)
    #expect(model.lastFailure == .pasteboardFailed)
    #expect(model.annotations.count == 1)
}

@Test
@MainActor
func copiedHidesAfterDisplayDuration() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.clock.waitForSleeper()
    harness.clock.advance(by: .milliseconds(2499))
    #expect(model.phase == .copied)
    #expect(harness.clock.pendingSleepCount == 1)
    await harness.expireCopiedTimer(after: .milliseconds(1))
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    #expect(model.lastCopiedCount == 1)
}

@Test
@MainActor
func copiedExpiredHides() async throws {
    let harness = try Harness()
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.clock.waitForSleeper()
    let timer = harness.model.copiedTimer
    await harness.send(.copiedExpired)
    #expect(harness.model.phase == .hidden)
    // 止めたタイマーは眠ったまま残らない。
    await timer?.value
    #expect(harness.clock.pendingSleepCount == 0)
}

@Test
@MainActor
func hotkeyWhileCopiedStartsNewSessionAndOldTimerDoesNotFire() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.clock.waitForSleeper()
    let oldTimer = model.copiedTimer
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
    // 2.5 秒が過ぎても、古いタイマーは drawing を hidden に戻さない。
    harness.clock.advance(by: .seconds(3))
    await oldTimer?.value
    #expect(model.phase == .drawing)
    // 新しい回で、もう一度コピーまで進める。
    await harness.drag()
    await harness.send(.commentConfirmed(text: "two"))
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .copied)
    #expect(model.lastCopiedCount == 1)
    await harness.expireCopiedTimer()
    #expect(model.phase == .hidden)
}

@Test
@MainActor
func staleTimerDoesNotHideNewerCopy() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.clock.waitForSleeper()
    let oldTimer = model.copiedTimer
    // 2 秒後に次の回を始めて、すぐにもう一度コピーする。
    harness.clock.advance(by: .seconds(2))
    await harness.send(.hotkeyPressed)
    await harness.drag()
    await harness.send(.commentConfirmed(text: "two"))
    await harness.send(.copyPromptTapped)
    await harness.clock.waitForSleeper()
    // 最初のコピーから 2.5 秒。古いタイマーの期限だが、新しいコピーの表示は消さない。
    harness.clock.advance(by: .milliseconds(500))
    await oldTimer?.value
    #expect(model.phase == .copied)
    await harness.expireCopiedTimer(after: .seconds(2))
    #expect(model.phase == .hidden)
}

@Test
@MainActor
func newSessionAfterCopyUsesNewFolder() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.expireCopiedTimer()
    harness.clock.advance(by: .seconds(60))
    await harness.annotate("next")
    #expect(model.annotations.first?.imagePath == "/akapen-test-cache/20261118-1433/01.png")
}

@Test
@MainActor
func newSessionInSameMinuteDoesNotOverwriteImages() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.send(.hotkeyPressed)
    await harness.drag()
    await harness.send(.commentConfirmed(text: "two"))
    #expect(model.annotations.first?.imagePath == "/akapen-test-cache/20261118-1432/02.png")
    #expect(harness.images.files.count == 2)
}

// MARK: - ボタン類の表示

@Test
@MainActor
func toolbarToggleFromHiddenShowsToolbarOnly() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(model.isToolbarVisible)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(!model.isToolbarVisible)
    await harness.send(.toolbarToggled)
    #expect(model.isToolbarVisible)
    // 新しい回が始まっているので、そのまま撮影できる。
    await harness.send(.addTapped)
    await harness.drag()
    #expect(model.draft?.imagePath == "/akapen-test-cache/20261118-1432/01.png")
}

@Test
@MainActor
func toolbarToggleFromListClosesListAndKeepsAnnotations() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.listToggled)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(!model.isToolbarVisible)
    #expect(model.annotations.count == 1)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(model.isToolbarVisible)
}

@Test
@MainActor
func toolbarToggleIsIgnoredWhileDrawingCommentingOrCopied() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
    await harness.drag()
    await harness.send(.toolbarToggled)
    #expect(model.phase == .commenting)
    #expect(model.isToolbarVisible)
    await harness.send(.commentConfirmed(text: "one"))
    await harness.send(.copyPromptTapped)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .copied)
    #expect(!model.isToolbarVisible)
}

// MARK: - 設定

@Test
@MainActor
func settingsChangeIsSaved() async throws {
    let harness = try Harness()
    var settings = Settings()
    settings.language = .ja
    settings.imageRetentionDays = 3
    await harness.send(.settingsChanged(settings))
    #expect(harness.model.settings == settings)
    #expect(harness.settingsStore.saved == [settings])
    #expect(harness.model.lastFailure == nil)
}

@Test
@MainActor
func settingsSaveFailureKeepsNewValueInMemory() async throws {
    let harness = try Harness()
    harness.settingsStore.saveError = TestError()
    var settings = Settings()
    settings.confirmKey = .commandEnter
    await harness.send(.settingsChanged(settings))
    #expect(harness.model.settings == settings)
    #expect(harness.model.lastFailure == .settingsSaveFailed)
    harness.settingsStore.saveError = nil
    await harness.send(.setupCompleted)
    #expect(harness.model.lastFailure == nil)
    #expect(harness.model.settings.setupCompleted)
    #expect(harness.model.settings.confirmKey == .commandEnter)
    #expect(harness.settingsStore.stored.setupCompleted)
}

@Test
@MainActor
func setupCompletedSaveFailure() async throws {
    let harness = try Harness()
    harness.settingsStore.saveError = TestError()
    await harness.send(.setupCompleted)
    #expect(harness.model.settings.setupCompleted)
    #expect(harness.model.lastFailure == .settingsSaveFailed)
    #expect(!harness.settingsStore.stored.setupCompleted)
}

// MARK: - 失敗の扱い

@Test
@MainActor
func failureIsKeptWhileInputsAreIgnored() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.drag(ScreenRect(x: 900, y: 700, width: 50, height: 50))
    #expect(model.lastFailure == .noWindowUnderFrame)
    // 何もしない入力では消えない。
    await harness.send(.hotkeyPressed)
    await harness.send(.listToggled)
    await harness.drag(ScreenRect(x: 150, y: 100, width: 2, height: 2))
    #expect(model.lastFailure == .noWindowUnderFrame)
    // 成功した入力で消える。
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
    #expect(model.lastFailure == nil)
}

// MARK: - 何もしない組み合わせと通知

@Test
@MainActor
func hiddenIgnoresEverythingButHotkeyToolbarAndSettings() async throws {
    let harness = try Harness()
    let model = harness.model
    let events: [SessionEvent] = [
        .addTapped,
        .escapePressed,
        .dragEnded(rect: Harness.frame, screen: Harness.screen),
        .commentConfirmed(text: "x"),
        .commentCancelled,
        .listToggled,
        .annotationEdited(id: UUID(), text: "x"),
        .annotationDeleted(id: UUID()),
        .copyPromptTapped,
        .copiedExpired,
    ]
    for event in events {
        await harness.send(event)
        #expect(model.phase == .hidden)
    }
    #expect(harness.changeCount == 0)
    #expect(model.lastDrawnRect == nil)
    #expect(harness.capturer.windowsCalls == 0)
}

@Test
@MainActor
func drawingIgnoresUnrelatedInputs() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    let changes = harness.changeCount
    let events: [SessionEvent] = [
        .hotkeyPressed,
        .addTapped,
        .commentConfirmed(text: "x"),
        .commentCancelled,
        .listToggled,
        .copyPromptTapped,
        .copiedExpired,
    ]
    for event in events {
        await harness.send(event)
        #expect(model.phase == .drawing)
    }
    #expect(harness.changeCount == changes)
}

@Test
@MainActor
func onChangeIsCalledOnlyWhenStateChanges() async throws {
    let harness = try Harness()
    await harness.send(.hotkeyPressed)
    #expect(harness.changeCount == 1)
    await harness.send(.hotkeyPressed)
    #expect(harness.changeCount == 1)
    // 撮影は、描いた枠の記録と、commenting への遷移で 2 回。
    await harness.drag()
    #expect(harness.changeCount == 3)
    await harness.send(.commentConfirmed(text: "x"))
    #expect(harness.changeCount == 4)
    // 同じ設定を送っても変わらない。
    await harness.send(.settingsChanged(harness.model.settings))
    #expect(harness.changeCount == 4)
}

@Test
@MainActor
func isToolbarVisibleFollowsPhase() async throws {
    let harness = try Harness()
    let model = harness.model
    #expect(!model.isToolbarVisible)
    await harness.send(.toolbarToggled)
    await harness.send(.toolbarToggled)
    #expect(model.phase == .idle)
    #expect(!model.isToolbarVisible)
    // drawing と commenting では、隠していても出る。
    await harness.send(.hotkeyPressed)
    #expect(model.isToolbarVisible)
    await harness.drag()
    #expect(model.phase == .commenting)
    #expect(model.isToolbarVisible)
    await harness.send(.commentConfirmed(text: "x"))
    await harness.send(.listToggled)
    #expect(model.isToolbarVisible)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .copied)
    #expect(!model.isToolbarVisible)
}

// MARK: - 順番

@Test
@MainActor
func inputsSentDuringCaptureAreProcessedInOrder() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.capturer.hold()
    let drag = model.send(.dragEnded(rect: Harness.frame, screen: Harness.screen))
    // 撮影の途中で、確定と一覧の切り替えを送る。
    let confirm = model.send(.commentConfirmed(text: "after capture"))
    let list = model.send(.listToggled)
    await harness.capturer.waitUntilCaptureStarts()
    #expect(model.phase == .drawing)
    #expect(model.annotations.isEmpty)
    harness.capturer.release()
    await drag.value
    await confirm.value
    #expect(model.annotations.map(\.comment) == ["after capture"])
    await list.value
    #expect(model.phase == .listOpen)
    // 待ち行列が空になれば、次の入力はその場で処理される。
    model.send(.listToggled)
    #expect(model.phase == .idle)
}

@Test
@MainActor
func synchronousInputsAreHandledImmediately() async throws {
    let harness = try Harness()
    let model = harness.model
    model.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    model.send(.escapePressed)
    #expect(model.phase == .hidden)
}

// MARK: - 起動時の掃除

@Test
@MainActor
func startupCleanupRemovesSessionsOlderThanRetention() async throws {
    var settings = Settings()
    settings.imageRetentionDays = 3
    let harness = try Harness(settings: settings)
    try harness.model.performStartupCleanup()
    #expect(harness.images.removedBefore == [Harness.start.addingTimeInterval(-3 * 86_400)])
}

@Test
@MainActor
func startupCleanupWithoutDependenciesDoesNothing() throws {
    let model = try SessionModel(settingsStore: FakeSettingsStore())
    try model.performStartupCleanup()
}

// MARK: - 既定値

@Test
@MainActor
func contractDefaults() throws {
    let model = try SessionModel(settingsStore: FakeSettingsStore())
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    #expect(model.lastCopiedCount == 0)
    #expect(model.lastFailure == nil)
    #expect(!model.settings.setupCompleted)
    model.send(.hotkeyPressed)
    #expect(model.isToolbarVisible)
}

@Test
func settingsDecodeWithoutSetupCompleted() throws {
    let json = Data(#"{"language":"ja","imageRetentionDays":3}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(settings.language == .ja)
    #expect(settings.imageRetentionDays == 3)
    #expect(!settings.setupCompleted)
}
