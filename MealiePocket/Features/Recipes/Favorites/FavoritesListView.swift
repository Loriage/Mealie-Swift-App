import SwiftUI

struct FavoritesListView: View {
    @State private var viewModel = FavoritesListViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recipes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage {
                contentUnavailable(title: "Error", message: errorMessage)
            } else if viewModel.recipes.isEmpty && !viewModel.searchText.isEmpty {
                contentUnavailable(title: "No Results", message: "No favorites match \"\(viewModel.searchText)\".", systemImage: "magnifyingglass")
            } else if viewModel.recipes.isEmpty && viewModel.searchText.isEmpty {
                contentUnavailable(title: "No Favorites", message: "Your favorite recipes will appear here.", systemImage: "heart")
            } else {
                recipeGrid
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.triggerSearch(apiClient: appState.apiClient, userID: appState.currentUserID)
        }
        .task {
            await viewModel.loadInitialOrRefreshRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
        }
        .refreshable {
            await viewModel.loadInitialOrRefreshRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
        }
    }

    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach($viewModel.recipes) { $recipe in
                    NavigationLink(value: recipe) {
                        RecipeCardView(recipe: $recipe, baseURL: appState.apiClient?.baseURL) {
                            Task {
                                await viewModel.toggleFavorite(for: recipe.id, userID: appState.currentUserID, apiClient: appState.apiClient)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.canLoadMore {
                    Rectangle()
                         .fill(Color.clear)
                         .frame(height: 50)
                         .onAppear {
                              Task {
                                   await viewModel.loadMoreRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
                              }
                         }
                         .overlay {
                             if viewModel.isLoadingMore {
                                  ProgressView()
                             }
                         }
                }
            }
            .padding()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $viewModel.sortOption) {
                ForEach(FavoritesListViewModel.SortOption.allCases) { option in
                    Text(LocalizedStringKey(option.displayName)).tag(option)
                }
            }
            
            Picker("Sort", selection: $viewModel.sortDirection) {
                Text(LocalizedStringKey("Ascending")).tag(FavoritesListViewModel.SortDirection.asc)
                Text(LocalizedStringKey("Descending")).tag(FavoritesListViewModel.SortDirection.desc)
            }
            
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .onChange(of: viewModel.sortOption) { _, _ in
             viewModel.setSortOption(viewModel.sortOption)
             Task { await viewModel.applySort(apiClient: appState.apiClient, userID: appState.currentUserID) }
         }
         .onChange(of: viewModel.sortDirection) { _, _ in
             Task { await viewModel.applySort(apiClient: appState.apiClient, userID: appState.currentUserID) }
         }
    }
    
    private func contentUnavailable(title: LocalizedStringKey, message: String, systemImage: String? = "exclamationmark.triangle") -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage ?? "exclamationmark.triangle")
        } description: {
            Text(LocalizedStringKey(message))
        }
    }
}
