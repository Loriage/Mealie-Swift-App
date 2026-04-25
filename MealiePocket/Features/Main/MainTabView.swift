import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var mealPlannerViewModel = MealPlannerViewModel()
    @State private var deepLinkedRecipe: RecipeSummary? = nil
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab("tab.home", systemImage: "house.fill", value: 0) {
                    NavigationStack() {
                        HomeView(selectedTab: $selectedTab)
                            .environment(mealPlannerViewModel)
                    }
                }
                Tab("tab.recipes", systemImage: "book.fill", value: 1) {
                    NavigationStack {
                        RecipeListView()
                    }
                }
                Tab("tab.planner", systemImage: "calendar", value: 2) {
                    NavigationStack {
                        MealPlannerView()
                            .environment(mealPlannerViewModel)
                    }
                }
                Tab("tab.lists", systemImage: "list.bullet", value: 3) {
                    NavigationStack {
                        ShoppingListView()
                    }
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
        }
        .onChange(of: appState.pendingAddMealDate) { _, date in
            guard let date else { return }
            selectedTab = 2
            mealPlannerViewModel.selectedDate = date
            mealPlannerViewModel.dateForAddingRecipe = date
            mealPlannerViewModel.showingAddRecipeSheet = true
            appState.pendingAddMealDate = nil
        }
        .onChange(of: appState.pendingRecipeSlug) { _, slug in
            guard let slug, !slug.isEmpty else { return }
            deepLinkedRecipe = RecipeSummary(
                id: UUID(),
                name: appState.pendingRecipeName,
                slug: slug,
                recipeYield: nil, totalTime: nil, prepTime: nil,
                rating: nil, userRating: nil, isFavorite: false
            )
            appState.pendingRecipeSlug = nil
            appState.pendingRecipeName = ""
        }
        .sheet(item: $deepLinkedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipeSummary: recipe)
            }
        }
    }
}

