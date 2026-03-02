import SwiftUI

struct MealDayCardView: View {
    let date: Date
    let entries: [ReadPlanEntry]
    let baseURL: URL?
    let onAddRecipeTapped: (Date) -> Void

    @Environment(AppState.self) private var appState

    @Environment(MealPlannerViewModel.self) private var mealPlannerViewModel
    @Binding var selectedTab: Int
    let plannerTabIndex = 2

    private let maxEntriesToShow = 4
    private var sortedEntries: [ReadPlanEntry] {
        entries.sorted {
            let order1 = $0.mealType.sortOrder
            let order2 = $1.mealType.sortOrder
            if order1 != order2 { return order1 < order2 }
            return ($0.recipe?.name ?? $0.title) < ($1.recipe?.name ?? $1.title)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(date, format: .dateTime.weekday(.wide).day())
                    .font(.headline)

                Spacer()

                if sortedEntries.count >= maxEntriesToShow {
                    Button {
                        hapticImpact(style: .light)
                        mealPlannerViewModel.selectDateAndView(date: date)
                        selectedTab = plannerTabIndex
                    } label: {
                        Text("View more")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .frame(height: 25)
                            .glassEffect(.regular.tint(.clear).interactive())
                            
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        hapticImpact(style: .light)
                        onAddRecipeTapped(date)
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(width: 25, height: 25)
                            .glassEffect(.regular.tint(.accentColor), in: .circle)
                    }
                }
            }
            .frame(minWidth: 150)

            if sortedEntries.isEmpty {
                Text("Nothing planned")
                    .font(.callout)
                    .padding(.bottom, 10)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    let entriesToDisplay = sortedEntries.prefix(maxEntriesToShow)
                    ForEach(entriesToDisplay.prefix(sortedEntries.count >= maxEntriesToShow ? maxEntriesToShow - 1 : maxEntriesToShow)) { entry in
                        mealEntryRow(entry: entry)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func mealEntryRow(entry: ReadPlanEntry) -> some View {
        if let recipe = entry.recipe {
            NavigationLink(value: recipe) {
                VStack(alignment: .leading, spacing: 6) {
                    AsyncImageView(
                        url: .makeImageURL(
                            baseURL: baseURL,
                            recipeID: recipe.id,
                            imageName: "min-original.webp"
                        )
                    )
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(recipe.name)
                        .font(.subheadline)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 6)
                }
                .frame(width: 80)
            }
            .buttonStyle(.plain)
        } else {
            Text(entry.title.isEmpty ? entry.text : entry.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
    }
    
}
