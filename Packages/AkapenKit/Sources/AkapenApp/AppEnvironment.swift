import Foundation
import AkapenCore
import AkapenPlatform

/// state.json v1: {schemaVersion:1, phase:String, annotations:[{id,imagePath,comment,rect}],
/// settings:Settings, lastDrawnRect:{x,y,width,height}|null}。矩形は共通左上原点のポイント。
/// Optional の矩形も null として出力する。書き出しは E2E のみ、Platform 越しに atomic。
public struct SessionSnapshot: Encodable {
    public let schemaVersion = 1
    public let phase: Phase
    public let annotations: [Annotation]
    public let settings: Settings
    public let lastDrawnRect: ScreenRect?
    @MainActor public init(model: SessionModel) {
        phase = model.phase; annotations = model.annotations; settings = model.settings; lastDrawnRect = model.lastDrawnRect
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, phase, annotations, settings, lastDrawnRect }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion); try c.encode(phase, forKey: .phase)
        try c.encode(annotations, forKey: .annotations); try c.encode(settings, forKey: .settings)
        try c.encode(lastDrawnRect, forKey: .lastDrawnRect)
    }
}
/// 本物の起動と結合テストで共有する組み立て。
@MainActor public final class AppEnvironment {
    public let model: SessionModel
    public let hotkey: any HotkeyRegistering
    public private(set) var stateWriteError: String?
    private let writer: (any StateWriting)?
    private init(model: SessionModel, writer: (any StateWriting)?) {
        self.model = model; self.writer = writer; hotkey = CarbonHotkey()
        model.onChange = { [weak self] in self?.writeState() }
        writeState()
    }
    /// E2E では書き出し先を必須にし、ユーザーの設定やキャッシュへフォールバックしない。
    public static func make(_ configuration: LaunchConfiguration) throws -> AppEnvironment {
        var writer: (any StateWriting)?
        if configuration.isE2E {
            guard let directory = configuration.stateDirectory else { throw ConfigurationError.missingStateDirectory }
            writer = AtomicStateWriter(url: directory.appendingPathComponent("state.json"))
        }
        // TODO(core): 永続設定・撮影・画像保存・コピー・時計の実装が揃ったらここで選択する。
        return try AppEnvironment(model: SessionModel(settingsStore: MemorySettingsStore()), writer: writer)
    }
    public enum ConfigurationError: Error { case missingStateDirectory }
    /// 現在の状態を書き出す。失敗は stateWriteError に保持し、黙って成功扱いにしない。
    public func writeState() {
        guard let writer else { return }
        do { try writer.write(JSONEncoder().encode(SessionSnapshot(model: model))); stateWriteError = nil }
        catch { stateWriteError = String(describing: error) }
    }
}
