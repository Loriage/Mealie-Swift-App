import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(MealPlannerViewModel.self) private var mealPlannerViewModel
    @Environment(AppState.self) private var appState

    @Binding var selectedTab: Int
    let plannerTabIndex = 2

    enum HomeNavigation: Hashable {
        case favoritesList
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Section {
                    if viewModel.isLoading && viewModel.favoriteRecipes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Error",
                            systemImage: "exclamationmark.triangle",
                            description: Text(LocalizedStringKey(errorMessage))
                        )
                        .padding(.vertical, 40)
                    } else if !viewModel.favoriteRecipes.isEmpty {
                        HStack {
                            Text("Favorites")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            NavigationLink(value: HomeNavigation.favoritesList) {
                                Image(systemName: "chevron.right")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        favoritesCarousel
                    } else {
                        Text("Favorites")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ContentUnavailableView(
                            "No favorites found",
                            systemImage: "heart.slash",
                            description: Text("Your favorite recipes will appear here.")
                        )
                    }
                }
                
                Section {
                    if let weeklyError = viewModel.weeklyMealsErrorMessage {
                        ContentUnavailableView(
                            "Error",
                            systemImage: "exclamationmark.triangle",
                            description: Text(LocalizedStringKey(weeklyError))
                        )
                        .padding(.vertical, 40)
                    }
                    
                    if !viewModel.isLoadingWeeklyMeals || !viewModel.weeklyMeals.isEmpty {
                        HStack {
                            Text("This week")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button {
                                hapticImpact(style: .light)
                                mealPlannerViewModel.goToWeek(date: Date())
                                selectedTab = plannerTabIndex
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        weeklyMealsCarousel
                    } else if viewModel.isLoadingWeeklyMeals {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Home")
        .task {
            await viewModel.loadHomeData(apiClient: appState.apiClient, userID: appState.currentUserID)
        }
        .refreshable {
            await viewModel.loadHomeData(apiClient: appState.apiClient, userID: appState.currentUserID)
        }
        .navigationDestination(for: HomeNavigation.self) { destination in
            switch destination {
            case .favoritesList:
                FavoritesListView()
            }
        }
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeSummary: recipe)
        }
        .sheet(isPresented: $viewModel.showingAddRecipeSheet) {
            if let date = viewModel.dateForAddingRecipe {
                SelectRecipeForHomeSheetView(viewModel: viewModel, date: date, apiClient: appState.apiClient)
            } else {
                Text("Error: Date not selected.")
            }
        }
        .onChange(of: viewModel.searchQueryForSelection) { _, _ in
            Task { await viewModel.searchRecipesForSelection(apiClient: appState.apiClient, loadMore: false) }
        }
    }

    private var favoritesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach($viewModel.favoriteRecipes) { $recipe in
                    NavigationLink(value: recipe) {
                        FavoriteCardView(recipe: $recipe, baseURL: appState.apiClient?.baseURL, showFavoriteButton: false)
                            .frame(width: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var weeklyMealsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.daysOfWeek, id: \.self) { day in
                    MealDayCardView(
                        date: day,
                        entries: viewModel.weeklyMeals[day] ?? [],
                        baseURL: appState.apiClient?.baseURL,
                        onAddRecipeTapped: { selectedDate in
                            viewModel.presentAddRecipeSheet(apiClient: appState.apiClient, for: selectedDate)
                        },
                        selectedTab: $selectedTab
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}
