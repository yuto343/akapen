import SwiftUI
import AkapenCore
import AkapenAXID

/// 一覧の、どの行を編集しているか。入力欄の中身（`GrowingTextController`）も持つ。
@MainActor @Observable final class ListEditingController {
    /// 編集中の注釈。nil なら編集していない。
    private(set) var editingID: UUID?
    @ObservationIgnored let editor: GrowingTextController
    /// 編集を確定したとき。
    @ObservationIgnored var onSave: ((UUID, String) -> Void)?

    /// 文字が並ぶ幅（行の幅から、サムネイル・余白・入力欄の内側の余白を引いたもの）。
    static let textWidth = Tokens.List.width
        - Tokens.List.rowPaddingX * 2
        - Tokens.List.thumbnailWidth
        - Tokens.List.rowGap
        - Tokens.List.fieldPaddingX * 2

    init() {
        editor = GrowingTextController(
            style: Tokens.Typography.listComment,
            maxLines: Tokens.Comment.maxLines,
            width: Self.textWidth,
            textColor: Tokens.List.comment,
            caretColor: Tokens.Comment.caret,
            placeholderColor: Tokens.Comment.placeholder
        )
        editor.textView.onConfirm = { [weak self] text in
            self?.save(text)
        }
        editor.textView.onCancel = { [weak self] in
            self?.end()
        }
    }

    /// 行の編集を始める（鉛筆のボタンだけから始める。`DECISIONS.md` 23）。
    func begin(_ annotation: Annotation, index: Int) {
        editingID = annotation.id
        editor.setText(annotation.comment)
        editor.textView.setAccessibilityIdentifier(AXID.List.field(index))
        editor.focus()
    }

    /// 編集をやめる。
    func end() {
        editingID = nil
    }

    private func save(_ text: String) {
        guard let id = editingID else {
            return
        }
        onSave?(id, text)
        end()
    }
}

/// 注釈の一覧（App 03）。見出し、行、フッター。行が 4 件を超える分は行の部分だけがスクロールする。
struct ListView: View {
    let annotations: [Annotation]
    let retentionDays: Int
    let confirmKey: ConfirmKey
    let strings: UIStrings
    let timeZone: TimeZone
    let editing: ListEditingController
    let thumbnails: any ThumbnailProviding
    let onDelete: (UUID) -> Void
    @State private var rowHeights: [UUID: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            rows
            footer
        }
        .frame(width: Tokens.List.width)
        .glassSurface(radius: Tokens.Radius.large)
        .clipShape(RoundedBox(cornerRadius: Tokens.Radius.large))
        .boxShadow(Tokens.List.shadows, cornerRadius: Tokens.Radius.large)
        .lightAppearance()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AXID.List.panel)
    }

    private var header: some View {
        HStack {
            Text(strings[.listTitle])
                .textStyle(Tokens.Typography.listTitle)
                .foregroundStyle(Tokens.List.title.color)
            Spacer(minLength: Tokens.Spacing.s2)
            Text(strings.plural(.listItems, count: annotations.count))
                .textStyle(Tokens.Typography.meta)
                .foregroundStyle(Tokens.List.count.color)
        }
        .padding(.top, Tokens.List.headerPaddingTop)
        .padding(.horizontal, Tokens.List.headerPaddingX)
        .padding(.bottom, Tokens.List.headerPaddingBottom)
    }

    @ViewBuilder private var rows: some View {
        if annotations.isEmpty {
            empty
        } else if annotations.count > Tokens.List.maxVisibleRows {
            ScrollView(.vertical) {
                rowStack
            }
            .frame(height: scrollHeight)
        } else {
            rowStack
        }
    }

    private var rowStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(annotations.enumerated()), id: \.element.id) { index, annotation in
                ListRowView(
                    index: index,
                    annotation: annotation,
                    isEditing: editing.editingID == annotation.id,
                    thumbnail: thumbnails.thumbnail(for: annotation),
                    meta: strings.annotationMeta(
                        appName: annotation.sourceAppName,
                        time: AnnotationTime.string(from: annotation.createdAt, timeZone: timeZone)
                    ),
                    strings: strings,
                    confirmKey: confirmKey,
                    editor: editing.editor,
                    onEdit: {
                        editing.begin(annotation, index: index)
                    },
                    onDelete: {
                        if editing.editingID == annotation.id {
                            editing.end()
                        }
                        onDelete(annotation.id)
                    }
                )
                .staggeredEntrance(delay: Double(index) * Tokens.Motion.rowDelay)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    rowHeights[annotation.id] = height
                }
            }
        }
    }

    /// スクロールする部分の高さ。先頭から 4 行分（測る前は見積もりの高さ）。
    private var scrollHeight: CGFloat {
        annotations
            .prefix(Tokens.List.maxVisibleRows)
            .map { rowHeights[$0.id] ?? Tokens.List.estimatedRowHeight }
            .reduce(0, +)
    }

    private var empty: some View {
        VStack(spacing: 0) {
            divider
            Text(strings[.listEmpty])
                .textStyle(Tokens.Typography.listComment)
                .foregroundStyle(Tokens.List.emptyText.color)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.List.thumbnailHeight)
                .padding(.vertical, Tokens.List.rowPaddingY)
                .accessibilityIdentifier(AXID.List.empty)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            divider
            Text(strings.plural(.listRetention, count: retentionDays))
                .textStyle(Tokens.Typography.listFooter)
                .foregroundStyle(Tokens.List.footerText.color)
                .accessibilityValue(String(retentionDays))
                .accessibilityIdentifier(AXID.List.retention)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Tokens.List.footerPaddingY)
                .padding(.horizontal, Tokens.List.footerPaddingX)
        }
        .background(Tokens.List.footerBackground.color)
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.List.divider.color)
            .frame(height: Tokens.Stroke.hairline)
    }
}

/// 一覧の 1 行。通常の行と、編集中の行。
struct ListRowView: View {
    let index: Int
    let annotation: Annotation
    let isEditing: Bool
    let thumbnail: NSImage?
    let meta: String
    let strings: UIStrings
    let confirmKey: ConfirmKey
    let editor: GrowingTextController
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Tokens.List.divider.color)
                .frame(height: Tokens.Stroke.hairline)
            HStack(alignment: .top, spacing: Tokens.List.rowGap) {
                thumbnailView
                if isEditing {
                    editField
                } else {
                    texts
                    buttons
                }
            }
            .padding(.vertical, Tokens.List.rowPaddingY)
            .padding(.horizontal, Tokens.List.rowPaddingX)
        }
        .background(isEditing ? Tokens.List.editingBackground.color : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AXID.List.row(index))
    }

    private var thumbnailView: some View {
        ZStack {
            Tokens.List.thumbnailBackground.color
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            }
        }
        .frame(width: Tokens.List.thumbnailWidth, height: Tokens.List.thumbnailHeight)
        .clipShape(RoundedBox(cornerRadius: Tokens.Radius.field))
        .accessibilityElement()
        .accessibilityAddTraits(.isImage)
        .accessibilityValue(thumbnail == nil ? "" : annotation.imagePath)
        .accessibilityIdentifier(AXID.List.thumbnail(index))
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: Tokens.List.textGap) {
            Text(annotation.comment)
                .textStyle(Tokens.Typography.listComment)
                .foregroundStyle(Tokens.List.comment.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AXID.List.comment(index))
            Text(meta)
                .textStyle(Tokens.Typography.meta)
                .foregroundStyle(Tokens.List.meta.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        HStack(alignment: .top, spacing: Tokens.List.buttonGap) {
            rowButton(glyph: .pencil, label: strings[.listEdit], identifier: AXID.List.edit(index), action: onEdit)
            rowButton(glyph: .trash, label: strings[.listDelete], identifier: AXID.List.delete(index), action: onDelete)
        }
    }

    private func rowButton(glyph: IconGlyph, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IconView(
                glyph: glyph,
                size: Tokens.List.buttonIconSize,
                color: Tokens.List.buttonIcon,
                lineWidth: Tokens.Stroke.rowIcon
            )
            .frame(width: Tokens.List.buttonSize, height: Tokens.List.buttonSize)
            .background(Capsule().fill(Tokens.Glass.white))
            .boxShadow(Tokens.Shadows.segmentSelected, cornerRadius: Tokens.Radius.pill)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.field))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var editField: some View {
        VStack(alignment: .leading, spacing: Tokens.List.textGap) {
            GrowingTextField(controller: editor)
                .frame(width: ListEditingController.textWidth, height: editor.height)
                .padding(.vertical, Tokens.List.fieldPaddingY)
                .padding(.horizontal, Tokens.List.fieldPaddingX)
                .background(RoundedBox(cornerRadius: Tokens.Radius.field).fill(Tokens.List.fieldBackground.color))
                .insetOutline(Tokens.List.fieldOutline, width: Tokens.Stroke.emphasis, cornerRadius: Tokens.Radius.field)
                .boxShadow([Tokens.Frame.glow], cornerRadius: Tokens.Radius.field)
            KeyHintRow(hints: strings.listEditHints(for: confirmKey), spacing: Tokens.List.editHintGap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
