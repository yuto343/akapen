import Carbon
import Testing
@testable import AkapenPlatform

/// 実際の登録（OS のグローバルホットキー）はここでは行わない。インスタンスごとの ID の振り分けだけを見る。
@MainActor
struct HotkeyTests {
    @Test
    func eachInstanceHasDistinctIdentifier() {
        let draw = CarbonHotkey()
        let toolbar = CarbonHotkey()
        #expect(draw.identifier != toolbar.identifier)
    }

    @Test
    func ignoresEventsForOtherHotkeys() {
        let draw = CarbonHotkey()
        let toolbar = CarbonHotkey()
        let notHandled = OSStatus(eventNotHandledErr)
        #expect(draw.handle(signature: CarbonHotkey.signature, identifier: toolbar.identifier) == notHandled)
        #expect(toolbar.handle(signature: CarbonHotkey.signature, identifier: draw.identifier) == notHandled)
        #expect(draw.handle(signature: 0, identifier: draw.identifier) == notHandled)
    }
}
