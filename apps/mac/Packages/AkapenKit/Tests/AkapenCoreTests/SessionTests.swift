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
    #expect(draft.rect == Harness.frame)
    #expect(draft.sourceAppName == "Sample App")
    #expect(draft.windowFrame == FakeCapturer.sampleWindow.frame)
    #expect(draft.createdAt == Harness.start.addingTimeInterval(5))
    #expect(draft.imagePath == "/akapen-test-cache/20261118-1432/01.png")
    // 枠内に見えているウィンドウ全体を、枠を描いたディスプレイで 1 回撮る。
    #expect(harness.capturer.capturedRegions.map(\.region) == [FakeCapturer.sampleWindow.frame])
    #expect(harness.capturer.capturedRegions.map(\.display) == [Harness.screen])
    // 保存された画像には、赤枠が描き込まれている。
    let path = try #require(draft.imagePath)
    let saved = try #require(harness.images.files[path])
    let bitmap = try #require(TestImages.decode(saved))
    #expect(bitmap.width == 800)
    #expect(bitmap.height == 600)
    #expect(bitmap.frameRedBox() == TestImages.PixelBox(minX: 94, minY: 94, maxX: 305, maxY: 205))
    #expect(model.annotations.isEmpty)
}

@Test
@MainActor
func dragCapturesAllWindowsVisibleInFrame() async throws {
    // 枠（x: 150〜250）の左 10pt が手前のウィンドウにかかる（枠の 10%）。両方を囲む範囲を撮る。
    let front = CaptureWindow(id: 1, frame: ScreenRect(x: 0, y: 0, width: 160, height: 400), appName: "Front")
    let back = FakeCapturer.sampleWindow
    let harness = try Harness(windows: [front, back])
    await harness.send(.hotkeyPressed)
    await harness.drag()
    let union = ScreenRect(x: 0, y: 0, width: 500, height: 400)
    #expect(harness.capturer.capturedRegions.map(\.region) == [union])
    let draft = try #require(harness.model.draft)
    #expect(draft.windowFrame == union)
    // 見えている面積の大きい順。
    #expect(draft.sourceAppName == "Sample App, Front")
    // 画像は範囲の大きさ × 倍率で、赤枠は範囲の中の枠の位置にある。
    let path = try #require(draft.imagePath)
    let saved = try #require(harness.images.files[path])
    let bitmap = try #require(TestImages.decode(saved))
    #expect(bitmap.width == 1000)
    #expect(bitmap.height == 800)
    #expect(bitmap.frameRedBox() == TestImages.PixelBox(minX: 294, minY: 194, maxX: 505, maxY: 305))
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
    #expect(harness.capturer.capturedRegions.isEmpty)
    #expect(harness.images.saveCalls.isEmpty)
    // 4pt ちょうどは撮る。
    await harness.drag(ScreenRect(x: 150, y: 100, width: 4, height: 4))
    #expect(model.phase == .commenting)
}

@Test
@MainActor
func dragWithoutWindowCapturesAroundFrame() async throws {
    // ウィンドウのない所に描いても、枠のまわり（上下左右に 200pt）を撮って入力欄を出す。範囲は画面の中に切り詰める。
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    let outside = ScreenRect(x: 900, y: 700, width: 50, height: 50)
    await harness.drag(outside)
    #expect(model.phase == .commenting)
    #expect(model.lastFailure == nil)
    #expect(model.lastDrawnRect == outside)
    let region = ScreenRect(x: 700, y: 500, width: 450, height: 400)
    #expect(harness.capturer.capturedRegions.map(\.region) == [region])
    let draft = try #require(model.draft)
    #expect(draft.windowFrame == region)
    #expect(draft.sourceAppName == "")
    #expect(draft.isCaptured)
    await harness.send(.commentConfirmed(text: "背景"))
    #expect(model.phase == .drawing)
    #expect(model.annotations.map(\.sourceAppName) == [""])
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
func escapeWhileDrawingHidesAndKeepsAnnotations() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    await harness.annotate("first")
    #expect(model.phase == .drawing)
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    // 隠しても注釈は消えない（回は copy prompt まで続く）。
    #expect(model.annotations.map(\.comment) == ["first"])
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
    // 確定したら、すぐ次の枠を描ける状態に戻る。
    #expect(model.phase == .drawing)
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
func cancellingCommentDiscardsImageAndReturnsToDrawing() async throws {
    for event in [SessionEvent.commentCancelled, .escapePressed] {
        let harness = try Harness()
        let model = harness.model
        await harness.send(.hotkeyPressed)
        await harness.drag()
        let path = try #require(model.draft?.imagePath)
        await harness.send(event)
        // 書きかけを捨てて、隠さずに枠を描ける状態へ戻る。
        #expect(model.phase == .drawing)
        #expect(model.isToolbarVisible)
        #expect(model.draft == nil)
        #expect(harness.images.removedPaths == [path])
        #expect(harness.images.files[path] == nil)
    }
}

@Test
@MainActor
func cancellingCommentKeepsConfirmedAnnotations() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("keep")
    let kept = try #require(model.annotations.first)
    await harness.drag()
    let discarded = try #require(model.draft?.imagePath)
    #expect(discarded == "/akapen-test-cache/20261118-1432/02.png")
    await harness.send(.commentCancelled)
    #expect(model.phase == .drawing)
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
    #expect(harness.model.phase == .drawing)
    #expect(harness.model.draft == nil)
}

@Test
@MainActor
func commentingIgnoresHotkeyListAndCopy() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.drag()
    let draft = model.draft
    let changes = harness.changeCount
    // ホットキーで隠すと書きかけを失うので、何もしない。
    for event in [SessionEvent.hotkeyPressed, .listToggled, .copyPromptTapped] {
        await harness.send(event)
        #expect(model.phase == .commenting)
        #expect(model.draft == draft)
    }
    #expect(harness.changeCount == changes)
    #expect(harness.pasteboard.writes.isEmpty)
}

@Test
@MainActor
func confirmedCommentLetsNextFrameBeDrawnRightAway() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.drag()
    await harness.send(.commentConfirmed(text: "one"))
    #expect(model.phase == .drawing)
    // ホットキーを押し直さずに、続けて枠を描いてコメントを入れられる。
    await harness.drag(ScreenRect(x: 300, y: 200, width: 80, height: 40))
    #expect(model.phase == .commenting)
    await harness.send(.commentConfirmed(text: "two"))
    #expect(model.phase == .drawing)
    #expect(model.annotations.map(\.comment) == ["one", "two"])
    #expect(model.annotations.map(\.imagePath) == [
        "/akapen-test-cache/20261118-1432/01.png",
        "/akapen-test-cache/20261118-1432/02.png",
    ])
}

// MARK: - ホットキーのトグルと一覧

@Test
@MainActor
func hotkeyTogglesToolbarAndKeepsSession() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    #expect(model.phase == .drawing)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    #expect(model.annotations.count == 1)
    // 時計が次の分に進んでも、注釈が残っていれば同じ回を続ける（回の ID と画像の番号を引き継ぐ）。
    harness.clock.advance(by: .seconds(120))
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
    #expect(model.currentSessionID == Harness.sessionID)
    await harness.drag()
    #expect(model.draft?.imagePath == "/akapen-test-cache/20261118-1432/02.png")
    await harness.send(.commentConfirmed(text: "two"))
    #expect(model.annotations.map(\.comment) == ["one", "two"])
}

@Test
@MainActor
func hotkeyFromHiddenWithoutAnnotationsStartsNewSession() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .hidden)
    harness.clock.advance(by: .seconds(60))
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    #expect(model.currentSessionID == "20261118-1433")
}

@Test
@MainActor
func hotkeyClosesListAndHides() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.listToggled)
    #expect(model.phase == .listOpen)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .hidden)
    #expect(model.annotations.count == 1)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
}

@Test
@MainActor
func listOpensAndClosesBackToDrawing() async throws {
    let harness = try Harness()
    let model = harness.model
    // 注釈が 0 件でも一覧は開ける（行の代わりに案内を出す）。
    await harness.send(.hotkeyPressed)
    await harness.send(.listToggled)
    #expect(model.phase == .listOpen)
    #expect(model.isToolbarVisible)
    await harness.send(.listToggled)
    #expect(model.phase == .drawing)
    await harness.send(.listToggled)
    await harness.send(.escapePressed)
    #expect(model.phase == .drawing)
    // drawing の Esc は隠す。
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
}

@Test
@MainActor
func listIgnoresDrag() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.listToggled)
    let changes = harness.changeCount
    await harness.drag()
    #expect(model.phase == .listOpen)
    #expect(model.draft == nil)
    #expect(harness.changeCount == changes)
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
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .drawing)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .drawing)
    await harness.send(.listToggled)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .listOpen)
    #expect(harness.pasteboard.writes.isEmpty)
    #expect(model.lastFailure == nil)
}

@Test
@MainActor
func copyWhileHiddenDoesNothing() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.send(.escapePressed)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .hidden)
    #expect(model.annotations.count == 1)
    #expect(harness.pasteboard.writes.isEmpty)
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
    #expect(model.phase == .drawing)
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
    #expect(model.phase == .drawing)
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

// MARK: - 浮く部品を下げる

@Test
@MainActor
func dismissHidesAndKeepsConfirmedAnnotations() async throws {
    for open in [Phase.drawing, .listOpen] {
        let harness = try Harness()
        let model = harness.model
        await harness.annotate("one")
        if open == .listOpen {
            await harness.send(.listToggled)
        }
        #expect(model.phase == open)
        await harness.send(.dismissRequested)
        #expect(model.phase == .hidden)
        #expect(model.annotations.count == 1)
    }
}

@Test
@MainActor
func dismissWhileCommentingDiscardsDraft() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.annotate("one")
    await harness.drag()
    let path = try #require(model.draft?.imagePath)
    await harness.send(.dismissRequested)
    #expect(model.phase == .hidden)
    #expect(model.draft == nil)
    #expect(model.annotations.count == 1)
    #expect(harness.images.removedPaths == [path])
}

@Test
@MainActor
func dismissIsIgnoredWhenNothingCoversTheScreen() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.dismissRequested)
    #expect(model.phase == .hidden)
    #expect(harness.changeCount == 0)
    await harness.annotate("one")
    await harness.send(.copyPromptTapped)
    await harness.send(.dismissRequested)
    #expect(model.phase == .copied)
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
    harness.capturer.captureError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(model.phase == .drawing)
    #expect(model.lastFailure == .captureFailed)
    // 何もしない入力では消えない。
    await harness.send(.copyPromptTapped)
    await harness.send(.commentConfirmed(text: "x"))
    await harness.drag(ScreenRect(x: 150, y: 100, width: 2, height: 2))
    #expect(model.lastFailure == .captureFailed)
    // 成功した入力で消える。
    await harness.send(.escapePressed)
    #expect(model.phase == .hidden)
    #expect(model.lastFailure == nil)
}

// MARK: - 何もしない組み合わせと通知

@Test
@MainActor
func hiddenIgnoresEverythingButHotkeyAndSettings() async throws {
    let harness = try Harness()
    let model = harness.model
    let events: [SessionEvent] = [
        .escapePressed,
        .dragEnded(rect: Harness.frame, screen: Harness.screen),
        .commentConfirmed(text: "x"),
        .commentCancelled,
        .listToggled,
        .annotationEdited(id: UUID(), text: "x"),
        .annotationDeleted(id: UUID()),
        .copyPromptTapped,
        .copiedExpired,
        .dismissRequested,
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
        .commentConfirmed(text: "x"),
        .commentCancelled,
        .annotationEdited(id: UUID(), text: "x"),
        .annotationDeleted(id: UUID()),
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
    await harness.send(.copyPromptTapped)
    #expect(harness.changeCount == 1)
    // 撮影は、描いた枠の記録、commenting への遷移、撮影の完了（画像のパスが入る）で 3 回。
    await harness.drag()
    #expect(harness.changeCount == 4)
    await harness.send(.commentConfirmed(text: "x"))
    #expect(harness.changeCount == 5)
    // 同じ設定を送っても変わらない。
    await harness.send(.settingsChanged(harness.model.settings))
    #expect(harness.changeCount == 5)
}

@Test
@MainActor
func isToolbarVisibleFollowsPhase() async throws {
    let harness = try Harness()
    let model = harness.model
    #expect(!model.isToolbarVisible)
    await harness.send(.hotkeyPressed)
    #expect(model.isToolbarVisible)
    await harness.drag()
    #expect(model.phase == .commenting)
    #expect(model.isToolbarVisible)
    await harness.send(.commentConfirmed(text: "x"))
    #expect(model.phase == .drawing)
    #expect(model.isToolbarVisible)
    await harness.send(.listToggled)
    #expect(model.isToolbarVisible)
    await harness.send(.hotkeyPressed)
    #expect(model.phase == .hidden)
    #expect(!model.isToolbarVisible)
    await harness.send(.hotkeyPressed)
    await harness.send(.copyPromptTapped)
    #expect(model.phase == .copied)
    #expect(!model.isToolbarVisible)
}

// MARK: - 順番

@Test
@MainActor
func inputsSentWhileWaitingForCaptureAreProcessedInOrder() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.capturer.hold()
    await harness.dragWithoutWaitingForCapture()
    #expect(model.phase == .commenting)
    // 撮影の途中で確定すると、撮影の完了を待つ。そのあいだに送った一覧の切り替えは、確定のあとに処理する。
    let confirm = model.send(.commentConfirmed(text: "after capture"))
    let list = model.send(.listToggled)
    await harness.capturer.waitUntilCaptureStarts()
    #expect(model.phase == .commenting)
    #expect(model.annotations.isEmpty)
    harness.capturer.release()
    await confirm.value
    #expect(model.annotations.map(\.comment) == ["after capture"])
    await list.value
    #expect(model.phase == .listOpen)
    // 待ち行列が空になれば、次の入力はその場で処理される。
    await harness.finishCapture()
    model.send(.listToggled)
    #expect(model.phase == .drawing)
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

// MARK: - 撮影の完了を待たずにコメントを書く

@Test
@MainActor
func dragStartsCommentingBeforeCaptureFinishes() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.clock.advance(by: .seconds(5))
    harness.capturer.hold()
    await harness.dragWithoutWaitingForCapture()
    await harness.capturer.waitUntilCaptureStarts()
    // 撮影の完了を待たずに、入力欄を出す状態になる。画像はまだない。
    #expect(model.phase == .commenting)
    #expect(model.lastFailure == nil)
    let pending = try #require(model.draft)
    #expect(pending.rect == Harness.frame)
    #expect(pending.createdAt == Harness.start.addingTimeInterval(5))
    #expect(!pending.isCaptured)
    #expect(pending.imagePath == nil)
    #expect(pending.sourceAppName == nil)
    #expect(pending.windowFrame == nil)
    #expect(harness.images.saveCalls.isEmpty)
    #expect(harness.capturer.capturedRegions.map(\.region) == [FakeCapturer.sampleWindow.frame])
    harness.capturer.release()
    await harness.finishCapture()
    // 撮影と保存が終わると、同じ書きかけに画像のパス・アプリ名・撮った範囲が入る。
    #expect(model.phase == .commenting)
    let captured = try #require(model.draft)
    #expect(captured.id == pending.id)
    #expect(captured.isCaptured)
    #expect(captured.imagePath == "/akapen-test-cache/20261118-1432/01.png")
    #expect(captured.sourceAppName == "Sample App")
    #expect(captured.windowFrame == FakeCapturer.sampleWindow.frame)
    let path = try #require(captured.imagePath)
    #expect(harness.images.files[path] != nil)
}

@Test
@MainActor
func dragWaitsForWindowListThatIsStillLoading() async throws {
    let harness = try Harness()
    let model = harness.model
    harness.capturer.holdListing()
    await harness.send(.hotkeyPressed)
    let drag = model.send(.dragEnded(rect: Harness.frame, screen: Harness.screen))
    // 一覧が取れるまでは、撮る範囲を決められないので `drawing` のまま待つ。
    await Task.yield()
    #expect(model.phase == .drawing)
    #expect(model.lastDrawnRect == Harness.frame)
    harness.capturer.releaseListing()
    await drag.value
    #expect(model.phase == .commenting)
    // 一覧は drawing に入ったときの 1 回だけ取る。
    #expect(harness.capturer.windowsCalls == 1)
}

@Test
@MainActor
func confirmBeforeCaptureFinishesWaitsAndKeepsComment() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.capturer.hold()
    await harness.dragWithoutWaitingForCapture()
    let draftID = try #require(model.draft?.id)
    let confirm = model.send(.commentConfirmed(text: "  ボタンの余白 \n"))
    // 二重に確定しても、一覧に入るのは 1 件だけ。
    let again = model.send(.commentConfirmed(text: "二回目"))
    await harness.capturer.waitUntilCaptureStarts()
    #expect(model.phase == .commenting)
    #expect(model.annotations.isEmpty)
    #expect(harness.images.saveCalls.isEmpty)
    harness.capturer.release()
    await confirm.value
    // 撮影の完了を待ってから一覧に入り、drawing に戻る。
    #expect(model.phase == .drawing)
    #expect(model.draft == nil)
    #expect(model.lastFailure == nil)
    let added = try #require(model.annotations.first)
    #expect(added.id == draftID)
    #expect(added.comment == "ボタンの余白")
    #expect(added.imagePath == "/akapen-test-cache/20261118-1432/01.png")
    #expect(added.sourceAppName == "Sample App")
    #expect(added.windowFrame == FakeCapturer.sampleWindow.frame)
    #expect(harness.images.files[added.imagePath] != nil)
    await again.value
    await harness.finishCapture()
    #expect(model.annotations.map(\.comment) == ["ボタンの余白"])
    #expect(harness.images.saveCalls.count == 1)
    #expect(model.phase == .drawing)
}

@Test
@MainActor
func leavingBeforeCaptureFinishesLeavesNoImage() async throws {
    let leaves: [[SessionEvent]] = [
        [.escapePressed],
        [.commentCancelled],
        [.dismissRequested],
        // Esc で drawing に戻り、ホットキーで隠す。
        [.escapePressed, .hotkeyPressed],
    ]
    for events in leaves {
        let harness = try Harness()
        let model = harness.model
        await harness.send(.hotkeyPressed)
        harness.capturer.hold()
        await harness.dragWithoutWaitingForCapture()
        await harness.capturer.waitUntilCaptureStarts()
        for event in events {
            await harness.send(event)
        }
        let phase = model.phase
        #expect(model.draft == nil)
        let changes = harness.changeCount
        harness.capturer.release()
        await harness.finishCapture()
        // 撮影が終わっても、画像のファイルは残らず、状態も書き換わらない。
        #expect(harness.images.saveCalls.isEmpty)
        #expect(harness.images.files.isEmpty)
        #expect(model.phase == phase)
        #expect(model.draft == nil)
        #expect(model.annotations.isEmpty)
        #expect(model.lastFailure == nil)
        #expect(harness.changeCount == changes)
    }
}

@Test
@MainActor
func captureFailureAfterCommentingStartedDiscardsDraft() async throws {
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.capturer.hold()
    harness.capturer.captureError = TestError()
    await harness.dragWithoutWaitingForCapture()
    #expect(model.phase == .commenting)
    harness.capturer.release()
    await harness.finishCapture()
    // 書きかけを捨てて drawing に戻り、失敗を出す。
    #expect(model.phase == .drawing)
    #expect(model.draft == nil)
    #expect(model.lastFailure == .captureFailed)
    #expect(harness.images.saveCalls.isEmpty)
    // 失敗のあとも続けて枠を描ける。
    harness.capturer.captureError = nil
    await harness.drag()
    #expect(model.phase == .commenting)
    #expect(model.lastFailure == nil)
    #expect(model.draft?.imagePath == "/akapen-test-cache/20261118-1432/01.png")
}

@Test
@MainActor
func failureWhileConfirmIsWaitingDiscardsDraft() async throws {
    for failure in [SessionFailure.captureFailed, .imageSaveFailed] {
        let harness = try Harness()
        let model = harness.model
        await harness.send(.hotkeyPressed)
        harness.capturer.hold()
        if failure == .captureFailed {
            harness.capturer.captureError = TestError()
        } else {
            harness.images.saveError = TestError()
        }
        await harness.dragWithoutWaitingForCapture()
        let confirm = model.send(.commentConfirmed(text: "書いた内容"))
        await harness.capturer.waitUntilCaptureStarts()
        harness.capturer.release()
        await confirm.value
        await harness.finishCapture()
        #expect(model.phase == .drawing)
        #expect(model.draft == nil)
        #expect(model.annotations.isEmpty)
        #expect(model.lastFailure == failure)
        #expect(harness.images.files.isEmpty)
    }
}

@Test
@MainActor
func staleCaptureDoesNotTouchNewerDraft() async throws {
    let other = CaptureWindow(id: 9, frame: ScreenRect(x: 600, y: 400, width: 300, height: 200), appName: "Other App")
    let harness = try Harness(windows: [FakeCapturer.sampleWindow, other])
    let model = harness.model
    await harness.send(.hotkeyPressed)
    harness.capturer.hold()
    await harness.dragWithoutWaitingForCapture()
    let firstCompletion = model.captureCompletion
    await harness.send(.escapePressed)
    // Esc で drawing に戻ると一覧を取り直す。その一覧が取れてから、別のウィンドウに次の枠を描く。
    await harness.finishListing()
    let second = ScreenRect(x: 650, y: 450, width: 60, height: 40)
    await harness.dragWithoutWaitingForCapture(second)
    let newer = try #require(model.draft)
    #expect(harness.capturer.capturedRegions.map(\.region) == [FakeCapturer.sampleWindow.frame, other.frame])
    // 両方の撮影を進める。先に終わる古い撮影の完了は、新しい書きかけを書き換えない。
    harness.capturer.release()
    await firstCompletion?.value
    await harness.finishCapture()
    let draft = try #require(model.draft)
    #expect(model.phase == .commenting)
    #expect(draft.id == newer.id)
    #expect(draft.rect == second)
    #expect(draft.sourceAppName == "Other App")
    #expect(draft.windowFrame == other.frame)
    #expect(draft.imagePath == "/akapen-test-cache/20261118-1432/01.png")
    #expect(harness.images.saveCalls.count == 1)
    #expect(harness.images.files.count == 1)
}

@Test
@MainActor
func windowListIsReloadedEachTimeDrawingStarts() async throws {
    let harness = try Harness()
    let model = harness.model
    let capturer = harness.capturer
    await harness.send(.hotkeyPressed)
    await harness.finishListing()
    #expect(capturer.windowsCalls == 1)
    // 一覧を開いて閉じると取り直す。
    await harness.send(.listToggled)
    await harness.send(.listToggled)
    await harness.finishListing()
    #expect(capturer.windowsCalls == 2)
    // コメントの確定のあと。
    await harness.drag()
    await harness.send(.commentConfirmed(text: "one"))
    await harness.finishListing()
    #expect(capturer.windowsCalls == 3)
    // 撮影には、先読みした一覧を使う（枠を描き終えたときに取り直さない）。
    #expect(model.phase == .drawing)
    // 隠して出し直したとき。
    await harness.send(.hotkeyPressed)
    #expect(model.windowListing == nil)
    await harness.send(.hotkeyPressed)
    await harness.finishListing()
    #expect(capturer.windowsCalls == 4)
}

@Test
@MainActor
func reloadedWindowListIsUsedForPicking() async throws {
    let moved = CaptureWindow(id: 8, frame: ScreenRect(x: 140, y: 90, width: 200, height: 100), appName: "Moved App")
    let harness = try Harness()
    let model = harness.model
    await harness.send(.hotkeyPressed)
    await harness.finishListing()
    // drawing に入った時点の一覧には `moved` がない。入り直すと、新しい一覧から選ぶ。
    harness.capturer.windowList = [moved, FakeCapturer.sampleWindow]
    await harness.send(.listToggled)
    await harness.send(.listToggled)
    await harness.drag()
    // `moved` が枠をすべて覆うので、奥のウィンドウは見えておらず範囲に入らない。
    #expect(harness.capturer.capturedRegions.map(\.region) == [moved.frame])
    #expect(model.draft?.sourceAppName == "Moved App")
}

@Test
@MainActor
func failedWindowListIsReloadedOnNextDrag() async throws {
    let harness = try Harness()
    let model = harness.model
    harness.capturer.windowsError = TestError()
    await harness.send(.hotkeyPressed)
    await harness.drag()
    #expect(model.phase == .drawing)
    #expect(model.lastFailure == .captureFailed)
    #expect(harness.capturer.windowsCalls == 1)
    // 取れなかった一覧は使い回さず、次のドラッグで取り直す。
    harness.capturer.windowsError = nil
    await harness.drag()
    #expect(harness.capturer.windowsCalls == 2)
    #expect(model.phase == .commenting)
    #expect(model.lastFailure == nil)
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

@Test
func settingsDecodeIgnoresRemovedToolbarShortcut() throws {
    // 古い版が保存した `toolbarShortcut` が残っていても、壊れた内容として扱わずに読む。
    let json = Data(#"{"language":"ja","toolbarShortcut":{"keyCode":11,"modifiers":3},"confirmKey":"commandEnter"}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(settings.language == .ja)
    #expect(settings.confirmKey == .commandEnter)
    let encoded = try #require(String(data: JSONEncoder().encode(settings), encoding: .utf8))
    #expect(!encoded.contains("toolbarShortcut"))
}

@Test(arguments: [false, true])
@MainActor
func clearAnnotationsKeepsPhase(listOpen: Bool) async throws {
    let harness = try Harness()
    await harness.annotate("first")
    await harness.annotate("second")
    if listOpen {
        await harness.send(.listToggled)
    }
    let phase = harness.model.phase
    let paths = harness.model.annotations.map(\.imagePath)
    await harness.send(.annotationsCleared)
    #expect(harness.model.annotations.isEmpty)
    #expect(harness.model.phase == phase)
    #expect(harness.images.removedPaths == paths)
    #expect(harness.images.files.isEmpty)
}

@Test(arguments: [Phase.hidden, .drawing, .listOpen, .commenting, .copied])
@MainActor
func clearAnnotationsIgnoresUnavailableStates(phase: Phase) async throws {
    let harness = try Harness()
    switch phase {
    case .drawing, .listOpen:
        await harness.send(.hotkeyPressed)
        if phase == .listOpen {
            await harness.send(.listToggled)
        }
    case .hidden, .commenting, .copied:
        await harness.annotate("kept")
        switch phase {
        case .hidden:
            await harness.send(.hotkeyPressed)
        case .commenting:
            await harness.drag()
        case .copied:
            await harness.send(.copyPromptTapped)
        default:
            break
        }
    }
    let annotations = harness.model.annotations
    let draft = harness.model.draft
    let files = harness.images.files
    let changes = harness.changeCount
    await harness.send(.annotationsCleared)
    #expect(harness.model.phase == phase)
    #expect(harness.model.annotations == annotations)
    #expect(harness.model.draft == draft)
    #expect(harness.images.files == files)
    #expect(harness.images.removedPaths.isEmpty)
    #expect(harness.changeCount == changes)
}
