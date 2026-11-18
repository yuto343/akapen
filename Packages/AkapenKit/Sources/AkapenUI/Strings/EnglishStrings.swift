/// 英語の文言。Paper の資料の文言のとおり。
struct EnglishStrings: StringTable {
    func text(_ key: StringKey) -> String {
        switch key {
        case .list:
            "List"
        case .copyPrompt:
            "Copy prompt"
        case .listShortcut:
            "⌘L"
        case .copyPromptShortcut:
            "⌘C"
        case .listHelp:
            "Show or hide the list (⌘L)"
        case .copyPromptHelp:
            "Copy the prompt (⌘C)"
        case .quit:
            "Quit"
        case .drawHint:
            "Drag to frame"
        case .drawCancel:
            "esc to cancel"
        case .commentPlaceholder:
            "Add a comment…"
        case .commentHintEnter:
            "↵ Done · ⇧↵ New line"
        case .commentHintCommandEnter:
            "⌘↵ Done · ↵ New line"
        case .commentCancel:
            "esc"
        case .listTitle:
            "Annotations"
        case .listEmpty:
            "No annotations yet"
        case .listEditHintEnter:
            "↵ Save · esc Cancel"
        case .listEditHintCommandEnter:
            "⌘↵ Save · esc Cancel"
        case .listEdit:
            "Edit"
        case .listDelete:
            "Delete"
        case .copiedTitle:
            "Prompt copied"
        case .copiedShortcut:
            "⌘ V"
        case .appName:
            "akapen"
        case .menuSettings:
            "Settings…"
        case .menuQuit:
            "Quit akapen"
        case .menuNoAnnotations:
            "No annotations"
        case .quitTitle:
            "Quit akapen?"
        case .quitCancel:
            "Cancel"
        case .settingsTitle:
            "akapen Settings"
        case .settingsLanguage:
            "Language"
        case .languageEnglish:
            "English"
        case .languageJapanese:
            "日本語"
        case .settingsHotkey:
            "Hotkey"
        case .settingsConfirmKey:
            "Confirm comment with"
        case .confirmKeyEnter:
            "↵ Enter"
        case .confirmKeyCommandEnter:
            "⌘ ↵ Enter"
        case .settingsPromptHeader:
            "Prompt header"
        case .settingsPromptNote:
            "Edits the English version"
        case .settingsPromptCaption:
            "Each annotation is added below as an image path followed by its comment."
        case .settingsRetention:
            "Keep images for"
        case .recorderPlaceholder:
            "Record shortcut"
        case .recorderRecording:
            "Type shortcut…"
        case .recorderUnavailable:
            "This shortcut is unavailable"
        case .recorderInUse:
            "This shortcut is already in use"
        case .setupHotkeyTitle:
            "Choose your hotkey"
        case .setupHotkeyBody:
            "Press it anywhere to show the buttons and start drawing a frame. Press it again for the next frame."
        case .setupRecorderHint:
            "Click and press a new combination to change"
        case .setupConflictNote:
            "⌘; is also used by macOS text fields (jump to misspelling), VS Code and Photoshop. You can change it here or later in Settings."
        case .setupContinue:
            "Continue"
        case .setupPermissionTitle:
            "Allow Screen Recording"
        case .setupPermissionBody:
            "akapen captures the window under each frame. Images stay on this Mac in ~/Library/Caches/akapen."
        case .setupStepOpenSettings:
            "Open System Settings → Privacy & Security"
        case .setupStepTurnOn:
            "Turn on akapen under Screen Recording"
        case .setupStepComeBack:
            "Come back here"
        case .setupWaiting:
            "Waiting…"
        case .setupGranted:
            "Granted"
        case .setupBack:
            "Back"
        case .setupOpenSystemSettings:
            "Open System Settings"
        case .setupDone:
            "Done"
        case .noticeNoWindow:
            "No window under the frame"
        case .noticeCaptureFailed:
            "Couldn’t capture the window"
        case .noticeImageSaveFailed:
            "Couldn’t save the image"
        case .noticePasteboardFailed:
            "Couldn’t copy to the clipboard"
        case .noticeSettingsSaveFailed:
            "Couldn’t save the settings"
        case .menuEdit:
            "Edit"
        case .menuUndo:
            "Undo"
        case .menuRedo:
            "Redo"
        case .menuCut:
            "Cut"
        case .menuCopy:
            "Copy"
        case .menuPaste:
            "Paste"
        case .menuSelectAll:
            "Select All"
        }
    }

    /// 英語の複数形の決まり（CLDR）: 1 だけが単数。0 は複数。
    func plural(_ key: PluralKey, count: Int) -> String {
        let one = count == 1
        switch key {
        case .listItems:
            return one ? "1 ITEM" : "\(count) ITEMS"
        case .listRetention:
            return one ? "Images are kept for 1 day" : "Images are kept for \(count) days"
        case .copiedSummary:
            return one ? "1 annotation · paste it into your AI agent" : "\(count) annotations · paste it into your AI agent"
        case .menuWaiting:
            return one ? "1 annotation waiting" : "\(count) annotations waiting"
        case .quitMessage:
            return one
                ? "1 annotation hasn’t been copied yet.\nIt will be discarded."
                : "\(count) annotations haven’t been copied yet.\nThey will be discarded."
        case .retentionUnit:
            return one ? "day" : "days"
        }
    }

    func sizeLabel(width: Int, height: Int) -> String {
        "\(width) × \(height)"
    }

    func annotationMeta(appName: String, time: String) -> String {
        "\(appName) · \(time)"
    }

    func setupStep(current: Int, total: Int) -> String {
        "STEP \(current) OF \(total)"
    }
}
