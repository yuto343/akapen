/// アプリと UI テストが共有するアクセシビリティ識別子。
public enum AXID {
    /// Toolbar の操作対象。
    public enum Toolbar {
        public static let add = "toolbar.add"
        public static let list = "toolbar.list"
        public static let copyPrompt = "toolbar.copyPrompt"
    }
    /// Draw の操作対象。
    public enum Draw {
        public static let surface = "draw.surface"
        public static let hint = "draw.hint"
        /// ドラッグ中の大きさの表示（`332 × 88`）。
        public static let sizeLabel = "draw.sizeLabel"
    }
    /// Comment の操作対象。
    public enum Comment {
        public static let field = "comment.field"
        public static let confirm = "comment.confirm"
        public static let cancel = "comment.cancel"
    }
    /// Copied の操作対象。
    public enum Copied {
        public static let message = "copied.message"
    }
    /// MenuBar の操作対象。
    public enum MenuBar {
        public static let settings = "menuBar.settings"
        public static let quit = "menuBar.quit"
    }
    /// QuitConfirm の操作対象。
    public enum QuitConfirm {
        public static let confirm = "quitConfirm.confirm"
        public static let cancel = "quitConfirm.cancel"
    }
    /// Settings の操作対象。
    public enum Settings {
        public static let language = "settings.language"
        public static let hotkey = "settings.hotkey"
        public static let toolbarShortcut = "settings.toolbarShortcut"
        public static let confirmKey = "settings.confirmKey"
        public static let boilerplate = "settings.boilerplate"
        public static let imageRetentionDays = "settings.imageRetentionDays"
    }
    /// Setup の操作対象。
    public enum Setup {
        public static let hotkey = "setup.hotkey"
        public static let permission = "setup.permission"
        public static let requestPermission = "setup.requestPermission"
        public static let next = "setup.next"
        public static let done = "setup.done"
    }
    /// Sample の操作対象。
    public enum Sample {
        public static let button = "sample.button"
        public static let count = "sample.count"
    }
    /// 注釈の一覧。引数は表示順のゼロ始まりの番号。
    public enum List {
        public static func row(_ index: Int) -> String {
            "list.row.\(index)"
        }

        public static func edit(_ index: Int) -> String {
            "list.edit.\(index)"
        }

        public static func delete(_ index: Int) -> String {
            "list.delete.\(index)"
        }

        /// 編集中の行の入力欄。
        public static func field(_ index: Int) -> String {
            "list.field.\(index)"
        }

        /// 一覧のパネル。
        public static let panel = "list.panel"

        /// 注釈が 0 件のときの表示。
        public static let empty = "list.empty"
    }
}
