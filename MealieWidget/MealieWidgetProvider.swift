import WidgetKit
import Foundation

// MARK: - Timeline Entry

struct TodaysMealsEntry: TimelineEntry {
    let date: Date
    let displayDate: Date
    let meals: [WidgetMeal]
    let state: EntryState

    enum EntryState {
        case loaded
        case notConfigured
        case failed
    }

    static var placeholder: TodaysMealsEntry {
        TodaysMealsEntry(
            date: Date(),
            displayDate: Date(),
            meals: [
            WidgetMeal(recipeName: "Avocado Toast",    mealType: "breakfast", recipeSlug: nil),
                WidgetMeal(recipeName: "Caesar Salad",     mealType: "lunch",     recipeSlug: nil),
                WidgetMeal(recipeName: "Grilled Salmon",   mealType: "dinner",    recipeSlug: nil),
            ],
            state: .loaded
        )
    }

    static var notConfigured: TodaysMealsEntry {
        TodaysMealsEntry(date: Date(), displayDate: Date(), meals: [], state: .notConfigured)
    }
}

// MARK: - Widget Meal Model

struct WidgetMeal: Identifiable {
    let id = UUID()
    let recipeName: String
    let mealType: String
    let recipeSlug: String?   // nil for title-only entries

    var icon: String {
        switch mealType.lowercased() {
        case "breakfast": return "sun.horizon.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.fill"
        case "side":      return "fork.knife"
        case "snack":     return "carrot"
        case "drink":     return "cup.and.saucer.fill"
        case "dessert":   return "birthday.cake.fill"
        default:          return "fork.knife"
        }
    }

    var sortOrder: Int {
        switch mealType.lowercased() {
        case "breakfast": return 0
        case "lunch":     return 1
        case "dinner":    return 2
        case "side":      return 3
        case "snack":     return 4
        case "drink":     return 5
        case "dessert":   return 6
        default:          return 7
        }
    }
}

// MARK: - Shared Credentials

struct WidgetCredentials {
    static let suiteName  = "group.dev.karant.MealiePocket"
    static let baseURLKey = "widget_baseURL"
    static let tokenKey   = "widget_token"

    let baseURL: URL
    let token: String

    static func load() -> WidgetCredentials? {
        guard
            let defaults  = UserDefaults(suiteName: suiteName),
            let urlString = defaults.string(forKey: baseURLKey),
            let url       = URL(string: urlString),
            let token     = defaults.string(forKey: tokenKey),
            !token.isEmpty
        else { return nil }
        return WidgetCredentials(baseURL: url, token: token)
    }
}

// MARK: - Lightweight API Models

private struct WidgetPlanPagination: Decodable {
    let items: [WidgetPlanEntry]
}

private struct WidgetPlanEntry: Decodable {
    let entryType: String
    let title: String
    let recipe: WidgetRecipeSummary?
}

private struct WidgetRecipeSummary: Decodable {
    let name: String
    let slug: String
}

// MARK: - Lightweight API Client

private enum WidgetAPIError: Error {
    case invalidURL, requestFailed, unauthorized
}

private struct WidgetAPIClient {
    static func fetchMeals(credentials: WidgetCredentials, date: Date) async throws -> [WidgetMeal] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        // Use device local timezone — matches how the main app sends dates to Mealie

        let startString = fmt.string(from: date)
        // Mealie treats end_date as inclusive, so use the same date for both
        // to get exactly one day's worth of meals.
        let endString = startString

        var components = URLComponents(
            url: credentials.baseURL.appendingPathComponent("api/households/mealplans"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "start_date",     value: startString),
            URLQueryItem(name: "end_date",       value: endString),
            URLQueryItem(name: "page",           value: "1"),
            URLQueryItem(name: "perPage",        value: "20"),
            URLQueryItem(name: "orderBy",        value: "date"),
            URLQueryItem(name: "orderDirection", value: "asc"),
        ]

        guard let url = components?.url else { throw WidgetAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw WidgetAPIError.requestFailed }
        if http.statusCode == 401 { throw WidgetAPIError.unauthorized }
        guard (200...299).contains(http.statusCode) else { throw WidgetAPIError.requestFailed }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let pagination = try decoder.decode(WidgetPlanPagination.self, from: data)

        return pagination.items.compactMap { entry in
            let name = entry.recipe?.name ?? (entry.title.isEmpty ? nil : entry.title)
            guard let recipeName = name else { return nil }
            return WidgetMeal(
                recipeName: recipeName,
                mealType: entry.entryType,
                recipeSlug: entry.recipe?.slug
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Timeline Provider

struct TodaysMealsProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodaysMealsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysMealsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await buildEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysMealsEntry>) -> Void) {
        Task {
            let entry = await buildEntry()

            let now      = Date()
            let calendar = Calendar.current
            let hour     = calendar.component(.hour, from: now)

            // Refresh every 30 min, but also schedule a pinned entry at 9 PM
            // (switch to tomorrow) and at midnight (switch back to today).
            let thirtyMin = now.addingTimeInterval(30 * 60)
            let keyTime: Date
            if hour < 21 {
                keyTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? thirtyMin
            } else {
                keyTime = calendar.startOfDay(
                    for: calendar.date(byAdding: .day, value: 1, to: now) ?? now
                )
            }

            let timeline = Timeline(entries: [entry], policy: .after(min(thirtyMin, keyTime)))
            completion(timeline)
        }
    }

    // MARK: - Helpers

    private func displayDate(from now: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        if hour >= 21 {
            return calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: 1, to: now) ?? now
            )
        }
        return calendar.startOfDay(for: now)
    }

    private func buildEntry() async -> TodaysMealsEntry {
        let now    = Date()
        let target = displayDate(from: now)

        guard let credentials = WidgetCredentials.load() else {
            return .notConfigured
        }

        do {
            let meals = try await WidgetAPIClient.fetchMeals(credentials: credentials, date: target)
            return TodaysMealsEntry(date: now, displayDate: target, meals: meals, state: .loaded)
        } catch {
            return TodaysMealsEntry(date: now, displayDate: target, meals: [], state: .failed)
        }
    }
}
