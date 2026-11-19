import Testing
import AkapenPlatform

@MainActor
struct PermissionTests {
    @Test
    func fixedPermissionCanBeSwitched() {
        let permission = FixedScreenRecordingPermission(isGranted: false)
        #expect(!permission.isGranted)
        #expect(!permission.request())
        permission.openSystemSettings()
        permission.isGranted = true
        #expect(permission.isGranted)
        #expect(permission.request())
    }

    @Test
    func noopLoginItemRemembersValueOnly() throws {
        let item = NoopLoginItem()
        #expect(!item.isEnabled)
        try item.setEnabled(true)
        #expect(item.isEnabled)
    }
}
