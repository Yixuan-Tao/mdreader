import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Editor") {
                    fontSizeRow(
                        title: "Editor Font Size",
                        value: Binding(
                            get: { settingsStore.settings.editorFontSize },
                            set: { settingsStore.settings.editorFontSize = $0 }
                        )
                    )
                }

                Section("Preview") {
                    fontSizeRow(
                        title: "Preview Font Size",
                        value: Binding(
                            get: { settingsStore.settings.previewFontSize },
                            set: { settingsStore.settings.previewFontSize = $0 }
                        )
                    )
                }

                Section("Default Mode") {
                    Picker("Open Documents In", selection: Binding(
                        get: { settingsStore.settings.defaultEditorMode },
                        set: { settingsStore.settings.defaultEditorMode = $0 }
                    )) {
                        ForEach(AppSettings.DefaultEditorMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func fontSizeRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) pt")
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: 13...28, step: 1)
        }
        .padding(.vertical, 4)
    }
}
