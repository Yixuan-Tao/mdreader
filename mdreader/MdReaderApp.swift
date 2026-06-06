import SwiftUI

@main
struct MdReaderApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsStore)
        }
    }
}
