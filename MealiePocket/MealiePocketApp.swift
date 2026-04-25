import SwiftUI
import WidgetKit

@main
struct MealiePocketApp: App {
    @State private var appState = AppState()
    @State private var displaySettings = DisplaySettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(displaySettings)
                .preferredColorScheme(displaySettings.theme.colorScheme)
                .environment(\.locale, displaySettings.locale)
                .id(displaySettings.languageCode)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mealio" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if url.host == "add",
           let dateStr = items.first(where: { $0.name == "date" })?.value {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let date = fmt.date(from: dateStr) {
                appState.pendingAddMealDate = date
            }
        } else if url.host == "recipe",
                  let slug = items.first(where: { $0.name == "slug" })?.value {
            appState.pendingRecipeName = items.first(where: { $0.name == "name" })?.value ?? ""
            appState.pendingRecipeSlug = slug
        }
    }
}
