import AkapenAXID

/// 同じパネルで提示する破壊的操作の種類。
public enum ConfirmationPurpose: Sendable {
    /// 未コピーの注釈を捨てて終了する。
    case quit
    /// 確定済みの注釈と画像をすべて消す。
    case clear

    var titleKey: StringKey {
        self == .quit ? .quitTitle : .clearTitle
    }

    var messageKey: PluralKey {
        self == .quit ? .quitMessage : .clearMessage
    }

    var confirmKey: StringKey {
        self == .quit ? .quit : .clearAll
    }

    var panelID: String {
        self == .quit ? AXID.QuitConfirm.panel : AXID.ClearConfirm.panel
    }

    var messageID: String {
        self == .quit ? AXID.QuitConfirm.message : AXID.ClearConfirm.message
    }

    var confirmID: String {
        self == .quit ? AXID.QuitConfirm.confirm : AXID.ClearConfirm.confirm
    }

    var cancelID: String {
        self == .quit ? AXID.QuitConfirm.cancel : AXID.ClearConfirm.cancel
    }

}

/// 破壊的操作の確認の答え。
public enum ConfirmationResult: Equatable, Sendable {
    /// 操作を確定する。
    case confirm
    /// 取りやめる。
    case cancel
}
