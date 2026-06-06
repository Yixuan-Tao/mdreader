import Foundation
import SwiftUI

struct AppSettings: Equatable {
    enum DefaultEditorMode: String, CaseIterable, Identifiable {
        case edit
        case preview

        var id: String { rawValue }

        var title: String {
            switch self {
            case .edit:
                return "Edit"
            case .preview:
                return "Preview"
            }
        }
    }

    var editorFontSize: Double
    var previewFontSize: Double
    var defaultEditorMode: DefaultEditorMode

    static let defaults = AppSettings(
        editorFontSize: 17,
        previewFontSize: 17,
        defaultEditorMode: .preview
    )
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    private let userDefaults: UserDefaults

    private enum Key {
        static let editorFontSize = "settings.editorFontSize"
        static let previewFontSize = "settings.previewFontSize"
        static let defaultEditorMode = "settings.defaultEditorMode"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.load(from: userDefaults)
    }

    private static func load(from userDefaults: UserDefaults) -> AppSettings {
        var settings = AppSettings.defaults

        if userDefaults.object(forKey: Key.editorFontSize) != nil {
            settings.editorFontSize = userDefaults.double(forKey: Key.editorFontSize)
        }

        if userDefaults.object(forKey: Key.previewFontSize) != nil {
            settings.previewFontSize = userDefaults.double(forKey: Key.previewFontSize)
        }

        if let rawMode = userDefaults.string(forKey: Key.defaultEditorMode),
           let mode = AppSettings.DefaultEditorMode(rawValue: rawMode) {
            settings.defaultEditorMode = mode
        }

        return settings
    }

    private func persist() {
        userDefaults.set(settings.editorFontSize, forKey: Key.editorFontSize)
        userDefaults.set(settings.previewFontSize, forKey: Key.previewFontSize)
        userDefaults.set(settings.defaultEditorMode.rawValue, forKey: Key.defaultEditorMode)
    }
}
