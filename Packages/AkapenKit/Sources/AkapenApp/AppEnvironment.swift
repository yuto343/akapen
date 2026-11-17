import Foundation
import AkapenCore
import AkapenPlatform

/// 本物の起動と結合テストで共有する組み立て。
@MainActor public final class AppEnvironment {
    public let model: SessionModel
    public let hotkey: any HotkeyRegistering
    public private(set) var stateWriteError: String?
    private let writer: (any StateWriting)?

    private init(model: SessionModel, writer: (any StateWriting)?) {
        self.model = model
        self.writer = writer
        hotkey = CarbonHotkey()
        model.onChange = { [weak self] in
            self?.writeState()
        }
        writeState()
    }

    public enum ConfigurationError: Error {
        case missingStateDirectory
    }

    /// E2E では書き出し先を必須にし、ユーザーの設定やキャッシュへフォールバックしない。
    public static func make(_ configuration: LaunchConfiguration) throws -> AppEnvironment {
        var writer: (any StateWriting)?
        if configuration.isE2E {
            guard let directory = configuration.stateDirectory else {
                throw ConfigurationError.missingStateDirectory
            }
            writer = AtomicStateWriter(url: directory.appendingPathComponent("state.json"))
        }
        // TODO(core): 永続設定・撮影・画像保存・コピー・時計の実装が揃ったらここで選択する。
        let model = try SessionModel(settingsStore: MemorySettingsStore())
        return AppEnvironment(model: model, writer: writer)
    }

    /// 現在の状態を書き出す。失敗は stateWriteError に保持し、黙って成功扱いにしない。
    public func writeState() {
        guard let writer else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try writer.write(encoder.encode(SessionSnapshot(model: model)))
            stateWriteError = nil
        } catch {
            stateWriteError = String(describing: error)
        }
    }
}
