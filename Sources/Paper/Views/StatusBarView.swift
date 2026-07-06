import SwiftUI

/// The bottom status bar: document/save state, caret position, tab width,
/// encoding, line ending, and character count. Encoding and line ending are
/// interactive menus.
struct StatusBarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.renderMock) private var renderMock

    private var anyDirty: Bool { app.documents.contains { $0.isDirty } }

    var body: some View {
        HStack(spacing: 0) {
            // Left: document count + save state
            HStack(spacing: 6) {
                Text("문서 \(app.documents.count)개")
                Text("·")
                HStack(spacing: 4) {
                    Circle()
                        .fill(anyDirty ? theme.accent.color : theme.secondaryText.color.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(anyDirty ? "저장 안 됨" : "모두 저장됨")
                }
            }

            Spacer(minLength: 12)

            // Center: caret position + selection
            if let doc = app.activeDocument {
                HStack(spacing: 6) {
                    Text("줄 \(doc.caretLine), 열 \(doc.caretColumn)")
                    if doc.selectedCount > 0 {
                        Text("·")
                        Text("\(doc.selectedCount)자 선택됨")
                            .foregroundStyle(theme.accent.color)
                    }
                }
            }

            Spacer(minLength: 12)

            // Right: tab width · encoding · line ending · char count
            if let doc = app.activeDocument {
                HStack(spacing: 8) {
                    Text("공백 \(app.settings.tabWidth)")
                    dot
                    encodingMenu(doc)
                    dot
                    lineEndingMenu(doc)
                    dot
                    Text("\(doc.characterCount)자")
                }
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(theme.secondaryText.color)
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(theme.statusBarBackground.color)
    }

    private var dot: some View {
        Text("·").foregroundStyle(theme.tertiaryText.color)
    }

    @ViewBuilder private func encodingMenu(_ doc: TextDocument) -> some View {
        if renderMock {
            Text(doc.encoding.shortName)
        } else {
        Menu {
            ForEach(TextEncoding.all) { enc in
                Button {
                    doc.encoding = enc
                    doc.isDirty = true
                } label: {
                    if enc.id == doc.encoding.id {
                        Label(enc.displayName, systemImage: "checkmark")
                    } else {
                        Text(enc.displayName)
                    }
                }
            }
        } label: {
            Text(doc.encoding.shortName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        }
    }

    @ViewBuilder private func lineEndingMenu(_ doc: TextDocument) -> some View {
        if renderMock {
            Text(doc.lineEnding.shortName)
        } else {
        Menu {
            ForEach(LineEnding.allCases) { le in
                Button {
                    doc.lineEnding = le
                    doc.isDirty = true
                } label: {
                    if le.id == doc.lineEnding.id {
                        Label(le.displayName, systemImage: "checkmark")
                    } else {
                        Text(le.displayName)
                    }
                }
            }
        } label: {
            Text(doc.lineEnding.shortName)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        }
    }
}
