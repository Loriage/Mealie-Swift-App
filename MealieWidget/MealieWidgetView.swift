import SwiftUI
import WidgetKit

// MARK: - Widget Declaration

struct TodaysMealsWidget: Widget {
    let kind: String = "TodaysMealsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysMealsProvider()) { entry in
            TodaysMealsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Meals")
        .description("See what's on the menu today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root View (family-aware)

struct TodaysMealsWidgetView: View {
    let entry: TodaysMealsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .notConfigured:
            NotConfiguredView(compact: family == .systemSmall)
        case .loaded, .failed:
            if family == .systemSmall {
                SmallMealsContentView(entry: entry)
            } else {
                MealsContentView(entry: entry)
            }
        }
    }
}

// MARK: - Not Configured

private struct NotConfiguredView: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: compact ? 28 : 36))
                .foregroundStyle(.orange)
            Text("Sign in to Pocket for Mealie")
                .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
                .multilineTextAlignment(.center)
            if !compact {
                Text("Open the app to get started")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium: Meals Content

private struct MealsContentView: View {
    let entry: TodaysMealsEntry

    private var isTomorrow: Bool { !Calendar.current.isDateInToday(entry.displayDate) }
    private var headerTitle: String { isTomorrow ? "Tomorrow's Meals" : "Today's Meals" }
    private var formattedDate: String {
        entry.displayDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
    private var addMealURL: URL? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return URL(string: "mealio://add?date=\(fmt.string(from: entry.displayDate))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label(headerTitle, systemImage: "fork.knife")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let url = addMealURL {
                    Link(destination: url) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    }
                    .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 10)

            if entry.meals.isEmpty {
                EmptyMealsView(isTomorrow: isTomorrow, compact: false)
            } else {
                MediumMealsListView(meals: entry.meals)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mealio://planner"))
    }
}

// MARK: - Small: Meals Content

private struct SmallMealsContentView: View {
    let entry: TodaysMealsEntry

    private var isTomorrow: Bool { !Calendar.current.isDateInToday(entry.displayDate) }
    private var headerTitle: String { isTomorrow ? "Tomorrow" : "Today" }
    private var formattedDate: String {
        entry.displayDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
    private var addMealURL: URL? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return URL(string: "mealio://add?date=\(fmt.string(from: entry.displayDate))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Compact header: title+date on left, '+' top-right
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(headerTitle, systemImage: "fork.knife")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = addMealURL {
                    Link(destination: url) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)

            Divider().padding(.top, 3)

            if entry.meals.isEmpty {
                EmptyMealsView(isTomorrow: isTomorrow, compact: true)
            } else {
                SmallMealsListView(meals: entry.meals)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "mealio://planner"))
    }
}

// MARK: - Medium: Meals List

private struct MediumMealsListView: View {
    let meals: [WidgetMeal]

    private var displayedMeals: [WidgetMeal] { Array(meals.prefix(4)) }
    private var overflow: Int { max(0, meals.count - 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(displayedMeals) { meal in
                MediumMealRowView(meal: meal)
            }
            if overflow > 0 {
                Text("+ \(overflow) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Small: Meals List

private struct SmallMealsListView: View {
    let meals: [WidgetMeal]

    // Small widget fits 4 rows comfortably with tighter padding
    private var displayedMeals: [WidgetMeal] { Array(meals.prefix(4)) }
    private var overflow: Int { max(0, meals.count - 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(displayedMeals) { meal in
                SmallMealRowView(meal: meal)
            }
            if overflow > 0 {
                Text("+ \(overflow) more")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Medium: Meal Row

private struct MediumMealRowView: View {
    let meal: WidgetMeal

    private var recipeURL: URL? {
        guard let slug = meal.recipeSlug else { return nil }
        let name = meal.recipeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mealio://recipe?slug=\(slug)&name=\(name)")
    }

    var body: some View {
        let row = HStack(spacing: 8) {
            Image(systemName: meal.icon)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 18)

            Text(meal.mealType.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(meal.recipeName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)

        if let url = recipeURL {
            Link(destination: url) { row }
        } else {
            row
        }
    }
}

// MARK: - Small: Meal Row (no type label, just icon + name)

private struct SmallMealRowView: View {
    let meal: WidgetMeal

    private var recipeURL: URL? {
        guard let slug = meal.recipeSlug else { return nil }
        let name = meal.recipeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mealio://recipe?slug=\(slug)&name=\(name)")
    }

    var body: some View {
        let row = HStack(spacing: 6) {
            Image(systemName: meal.icon)
                .font(.system(size: 10))
                .foregroundStyle(.orange)
                .frame(width: 14)

            Text(meal.recipeName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)

        if let url = recipeURL {
            Link(destination: url) { row }
        } else {
            row
        }
    }
}

// MARK: - Empty State

private struct EmptyMealsView: View {
    let isTomorrow: Bool
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            Image(systemName: "calendar.badge.plus")
                .font(compact ? .body : .title2)
                .foregroundStyle(.secondary)
            Text(isTomorrow ? "Nothing planned for tomorrow" : "Nothing planned for today")
                .font(compact ? .system(size: 10) : .caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    TodaysMealsWidget()
} timeline: {
    TodaysMealsEntry.placeholder
    TodaysMealsEntry.notConfigured
    TodaysMealsEntry(
        date: Date(),
        displayDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
        meals: [],
        state: .loaded
    )
}

#Preview("Small", as: .systemSmall) {
    TodaysMealsWidget()
} timeline: {
    TodaysMealsEntry.placeholder
    TodaysMealsEntry.notConfigured
    TodaysMealsEntry(
        date: Date(),
        displayDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
        meals: [],
        state: .loaded
    )
}
