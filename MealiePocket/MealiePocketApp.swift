import SwiftUI

@main
struct MealiePocketApp: App {
    @State private var appState = AppState()
    @State private var displaySettings = DisplaySettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(displaySettings)
                .preferredColorScheme(displaySettings.theme.colorScheme)
                .environment(\.locale, displaySettings.locale)
                .id(displaySettings.languageCode)
        }
    }
}
