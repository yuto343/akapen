/// 設定の読み書き。未保存なら既定値を返す。
@MainActor public protocol SettingsStore {
    /// 未保存なら Settings()。壊れた保存内容や I/O エラーは throws。
    func load() throws -> Settings

    /// 設定全体を置き換える。
    func save(_ settings: Settings) throws
}
