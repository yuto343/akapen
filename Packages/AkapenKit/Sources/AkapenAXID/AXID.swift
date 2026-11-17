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
        /// 画面上の赤枠（ドラッグ中の枠と、コメントを書いている間の枠）。
        public static let frame = "draw.frame"
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
        /// メニューバーのアイコン（`NSStatusItem` のボタン）。
        public static let icon = "menuBar.icon"
        /// メニューの見出しの 2 行目（`2 annotations waiting`）。
        public static let status = "menuBar.status"
    }
    /// QuitConfirm の操作対象。
    public enum QuitConfirm {
        public static let confirm = "quitConfirm.confirm"
        public static let cancel = "quitConfirm.cancel"
        /// 終了確認のパネル（画面の暗転を含む）。
        public static let panel = "quitConfirm.panel"
        /// 件数入りの説明文。
        public static let message = "quitConfirm.message"
    }
    /// Settings の操作対象。
    public enum Settings {
        public static let language = "settings.language"
        public static let hotkey = "settings.hotkey"
        public static let toolbarShortcut = "settings.toolbarShortcut"
        public static let confirmKey = "settings.confirmKey"
        public static let boilerplate = "settings.boilerplate"
        public static let imageRetentionDays = "settings.imageRetentionDays"
        /// 設定のウィンドウ。
        public static let window = "settings.window"
        /// 言語の選択肢の `English`。
        public static let languageEnglish = "settings.language.en"
        /// 言語の選択肢の `日本語`。
        public static let languageJapanese = "settings.language.ja"
        /// 確定キーの選択肢の `↵ Enter`。
        public static let confirmKeyEnter = "settings.confirmKey.enter"
        /// 確定キーの選択肢の `⌘ ↵ Enter`。
        public static let confirmKeyCommandEnter = "settings.confirmKey.commandEnter"
        /// ホットキーの記録欄の下に出す知らせ（`This shortcut is unavailable` など）。
        public static let hotkeyMessage = "settings.hotkey.message"
        /// ボタン類の表示切り替えの記録欄の下に出す知らせ。
        public static let toolbarShortcutMessage = "settings.toolbarShortcut.message"
    }
    /// Setup の操作対象。
    public enum Setup {
        public static let hotkey = "setup.hotkey"
        public static let permission = "setup.permission"
        public static let requestPermission = "setup.requestPermission"
        public static let next = "setup.next"
        public static let done = "setup.done"
        /// セットアップのウィンドウ。
        public static let window = "setup.window"
        /// 2 ページ目の `Back`。
        public static let back = "setup.back"
        /// ホットキーの記録欄の中に出す知らせ（`This shortcut is unavailable` など）。
        public static let hotkeyMessage = "setup.hotkey.message"
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

        /// 行のコメントの文。
        public static func comment(_ index: Int) -> String {
            "list.comment.\(index)"
        }

        /// 行のサムネイル（撮影した画像の縮小）。
        public static func thumbnail(_ index: Int) -> String {
            "list.thumbnail.\(index)"
        }

        /// 一覧のパネル。
        public static let panel = "list.panel"

        /// 注釈が 0 件のときの表示。
        public static let empty = "list.empty"

        /// 一覧の下の、画像を残す期間の案内（`Images are kept for 7 days`）。
        public static let retention = "list.retention"
    }
    /// アプリのメインメニュー（画面の上には出ない。`⌘Q`・`⌘,` と、入力欄の編集のキーを効かせるために置く）。
    public enum MainMenu {
        public static let settings = "mainMenu.settings"
        public static let quit = "mainMenu.quit"
        public static let undo = "mainMenu.undo"
        public static let redo = "mainMenu.redo"
        public static let cut = "mainMenu.cut"
        public static let copy = "mainMenu.copy"
        public static let paste = "mainMenu.paste"
        public static let selectAll = "mainMenu.selectAll"
    }
}
