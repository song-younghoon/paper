import SwiftUI

/// The tabbed Settings window (design 1f): 일반 / 편집기 / 파일.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gearshape") }
            EditorSettingsView()
                .tabItem { Label("편집기", systemImage: "textformat.size") }
            FileSettingsView()
                .tabItem { Label("파일", systemImage: "doc.text") }
        }
        .frame(width: 500)
        .frame(minHeight: 420)
        .preferredColorScheme(settings.activeTheme.colorScheme)
    }
}

// MARK: - General (theme + accent)

private struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("테마") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(ThemeSelection.allCases) { sel in
                        ThemeCard(selection: sel, isSelected: settings.themeSelection == sel) {
                            settings.themeSelection = sel
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("강조 색상") {
                Toggle("사용자 지정 색상 사용", isOn: $settings.useCustomAccent)
                if settings.useCustomAccent {
                    HStack(spacing: 10) {
                        ForEach(AccentSwatch.presets) { swatch in
                            AccentDot(
                                color: swatch.color,
                                selected: settings.customAccent.hexString == swatch.color.hexString
                            ) {
                                settings.customAccent = swatch.color
                            }
                        }
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { settings.customAccent.color },
                            set: { settings.customAccent = $0.paperColor }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                } else {
                    Text("선택한 테마의 기본 강조 색상을 사용합니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ThemeCard: View {
    let selection: ThemeSelection
    let isSelected: Bool
    let action: () -> Void

    private var theme: Theme {
        switch selection {
        case .warmPaper: return .warmPaper
        case .coolSystem: return .coolSystem
        case .darkGraphite: return .darkGraphite
        case .systemAuto: return .darkGraphite
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Mini editor preview
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.editorBackground.color)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(theme.sidebarBackground.color).frame(width: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 1).fill(theme.primaryText.color.opacity(0.7)).frame(width: 42, height: 3)
                            RoundedRectangle(cornerRadius: 1).fill(theme.accent.color).frame(width: 28, height: 3)
                            RoundedRectangle(cornerRadius: 1).fill(theme.secondaryText.color.opacity(0.5)).frame(width: 50, height: 3)
                        }
                        .padding(.vertical, 6)
                        Spacer()
                    }
                    .padding(4)
                }
                .frame(height: 56)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.08)))

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selection.displayName).font(.system(size: 12.5, weight: .medium))
                        Text(selection.subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.accent.color)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? theme.accent.color.opacity(0.10) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isSelected ? theme.accent.color : Color.primary.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AccentDot: View {
    let color: PaperColor
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0))
                .overlay(Circle().strokeBorder(color.color, lineWidth: selected ? 1 : 0).padding(-2))
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor

private struct EditorSettingsView: View {
    @Environment(AppSettings.self) private var settings

    private static let fontOptions: [(id: String, label: String)] = [
        ("", "시스템 기본 (SF Pro · Apple SD 산돌고딕)"),
        ("SF Mono", "SF Mono"),
        ("Menlo", "Menlo"),
        ("Monaco", "Monaco"),
        ("Courier New", "Courier New"),
        ("Helvetica Neue", "Helvetica Neue"),
        ("Georgia", "Georgia"),
    ]

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("글꼴") {
                Picker("본문 글꼴", selection: $settings.fontName) {
                    ForEach(Self.fontOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                HStack {
                    Text("크기")
                    Spacer()
                    Text("\(Int(settings.fontSize))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Stepper("", value: $settings.fontSize, in: AppSettings.minFontSize...AppSettings.maxFontSize, step: 1)
                        .labelsHidden()
                }
            }

            Section("편집") {
                Toggle("줄 번호 표시", isOn: $settings.showLineNumbers)
                Toggle("줄바꿈", isOn: $settings.lineWrap)
                HStack {
                    Text("자동 저장")
                    Spacer()
                    if settings.autoSaveEnabled {
                        Stepper("\(settings.autoSaveInterval)초마다", value: $settings.autoSaveInterval, in: 2...300, step: 1)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    Toggle("", isOn: $settings.autoSaveEnabled).labelsHidden()
                }
                HStack {
                    Text("탭 너비")
                    Spacer()
                    Picker("", selection: $settings.tabWidth) {
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - File

private struct FileSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("파일") {
                Picker("기본 인코딩", selection: $settings.defaultEncodingID) {
                    ForEach(TextEncoding.all) { enc in
                        Text(enc.displayName).tag(enc.id)
                    }
                }
                Picker("줄바꿈 형식", selection: $settings.defaultLineEnding) {
                    ForEach(LineEnding.allCases) { le in
                        Text(le.displayName).tag(le)
                    }
                }
            }
            Section {
                Text("새 문서와 인코딩을 감지하지 못한 파일에 적용됩니다. 각 문서의 인코딩·줄바꿈은 상태 바에서 개별적으로 바꿀 수 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
