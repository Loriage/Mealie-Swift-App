import SwiftUI

struct CalendarMonthView: View {
    let days: [Date]
    let mealPlanEntries: [Date: [ReadPlanEntry]]
    let selectedMonthDate: Date
    let baseURL: URL?
    let onDateSelected: (Date) -> Void

    @Environment(\.locale) private var locale

    private var daysOfWeek: [String] {
        var cal = Calendar.current
        cal.locale = locale
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(days, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        entries: mealPlanEntries[Calendar.current.startOfDay(for: date)] ?? [],
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedMonthDate, toGranularity: .month),
                        onTap: { onDateSelected(date) }
                    )
                    .frame(minHeight: 100, alignment: .topLeading)
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let entries: [ReadPlanEntry]
    let isCurrentMonth: Bool
    let onTap: () -> Void

    @Environment(\.locale) private var locale
    
    private var sortedEntries: [ReadPlanEntry] {
        entries.sorted {
            let typeOrder: [String: Int] = ["breakfast": 0, "lunch": 1, "dinner": 2, "side": 3]
            let order1 = typeOrder[$0.entryType.lowercased()] ?? 4
            let order2 = typeOrder[$1.entryType.lowercased()] ?? 4
            if order1 != order2 {
                return order1 < order2
            }
            let name1 = $0.recipe?.name ?? $0.title
            let name2 = $1.recipe?.name ?? $1.title
            return name1 < name2
        }
    }
    
    private let maxIconsToShow = 4
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if isCurrentMonth {
                    Text(date.formatted(.dateTime.locale(locale).day()))
                        .font(.callout.bold())
                        .fontWeight(Calendar.current.isDateInToday(date) ? .heavy : .regular)
                        .foregroundColor(foregroundColorForDate)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 5)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedEntries.prefix(maxIconsToShow)) { entry in
                            Image(systemName: iconForEntryType(entry.entryType))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                                .foregroundColor(entry.entryType.lowercased() == "note" ? .gray : .accentColor)
                        }
                        if entries.count > maxIconsToShow {
                            Text("...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                } else {
                    Spacer()
                }
            }
            .padding(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth)
    }
    
    private var foregroundColorForDate: Color {
        if Calendar.current.isDateInToday(date) {
            return .red
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private func iconForEntryType(_ type: String) -> String {
        switch type.lowercased() {
        case "breakfast": return "sun.horizon.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "side": return "fork.knife"
        default: return "note.text"
        }
    }
}
