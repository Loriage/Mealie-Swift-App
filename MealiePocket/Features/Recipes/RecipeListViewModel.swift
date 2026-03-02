import Foundation
import Combine

@Observable
class RecipeListViewModel {
    var recipes: [RecipeSummary] = []
    var searchText: String = ""

    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    
    var sortOption: SortOption = .name
    var sortDirection: SortDirection = .asc
    
    private var paginationSeed: String?
    private var searchTask: Task<Void, Never>? = nil

    private var currentPage = 1
    private var totalPages = 1
    var canLoadMore: Bool { currentPage < totalPages }
    
    func setSortOption(_ newOption: SortOption) {
        sortOption = newOption
        sortDirection = newOption.defaultDirection
    }

    func triggerSearch(apiClient: MealieAPIClient?, userID: String?) {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                await performSearchOrLoad(apiClient: apiClient, userID: userID, isSearching: true, loadMore: false)
            } catch {}
        }
    }

    private func performSearchOrLoad(apiClient: MealieAPIClient?, userID: String?, isSearching: Bool, loadMore: Bool) async {
        guard let apiClient, let userID else {
            errorMessage = "error.apiClientOrIDUnavailable"
            return
        }
        
        if loadMore {
            guard !isLoadingMore && canLoadMore else { return }
            isLoadingMore = true
        } else {
            isLoading = true
            currentPage = 1
            recipes = []
        }
        errorMessage = nil
        
        if sortOption == .random && searchText.isEmpty {
            paginationSeed = UUID().uuidString
        } else {
            paginationSeed = nil
        }
        
        let pageToLoad = loadMore ? currentPage + 1 : 1
        
        do {
            let response = try await apiClient.fetchRecipes(
                page: pageToLoad,
                orderBy: sortOption.rawValue,
                orderDirection: sortDirection.rawValue,
                paginationSeed: paginationSeed,
                queryFilter: searchText.isEmpty ? nil : "name LIKE %\(searchText)%",
                perPage: 50
            )
            
            let fetchedRecipes = response.items
            
            let recipeIDs = fetchedRecipes.map { $0.id.uuidString }
            var userRatings: [UserRating] = []
            if !recipeIDs.isEmpty {
                let allUserRatings = try await apiClient.fetchRatings(userID: userID)
                userRatings = allUserRatings.filter { recipeIDs.contains($0.recipeId.uuidString) }
            }
            
            let userRatingsDict = Dictionary(uniqueKeysWithValues: userRatings.map { ($0.recipeId, $0) })
            
            var updatedRecipes = fetchedRecipes
            for i in updatedRecipes.indices {
                if let userRatingData = userRatingsDict[updatedRecipes[i].id] {
                    updatedRecipes[i].isFavorite = userRatingData.isFavorite
                    updatedRecipes[i].userRating = userRatingData.rating
                } else {
                    updatedRecipes[i].isFavorite = false
                    updatedRecipes[i].userRating = nil
                }
            }
            
            await MainActor.run {
                if loadMore {
                    self.recipes.append(contentsOf: updatedRecipes)
                    self.currentPage = pageToLoad
                } else {
                    self.recipes = updatedRecipes
                    self.currentPage = 1
                }
                self.totalPages = response.totalPages
                
                self.isLoading = false
                self.isLoadingMore = false
            }
            
        } catch APIError.unauthorized {
            await MainActor.run {
                isLoading = false
                isLoadingMore = false
            }
        } catch {
            guard !(error is CancellationError) else {
                await MainActor.run {
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }
            await MainActor.run {
                self.errorMessage = "error.loadingRecipes"
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }

    func applySort(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, isSearching: !searchText.isEmpty, loadMore: false)
    }

    func loadInitialOrRefreshRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, isSearching: !searchText.isEmpty, loadMore: false)
    }

    func loadMoreRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, isSearching: !searchText.isEmpty, loadMore: true)
    }

    func toggleFavorite(for recipeId: UUID, userID: String?, apiClient: MealieAPIClient?) async {
        guard let apiClient, let userID else { return }
        
        updateFavoriteStatus(for: recipeId, in: &recipes)
        
        guard let recipe = recipes.first(where: { $0.id == recipeId }) else { return }
        
        do {
            if recipe.isFavorite {
                try await apiClient.addFavorite(userID: userID, slug: recipe.slug)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: recipe.slug)
            }
        } catch {
            updateFavoriteStatus(for: recipeId, in: &recipes)
            await MainActor.run {
                self.errorMessage = "error.updatingFavorite"
            }
        }
    }
    
    private func updateFavoriteStatus(for recipeId: UUID, in list: inout [RecipeSummary]) {
        if let index = list.firstIndex(where: { $0.id == recipeId }) {
            list[index].isFavorite.toggle()
        }
    }
}


enum SortOption: String, CaseIterable, Identifiable {
    case name = "name"
    case createdAt = "createdAt"
    case lastMade = "lastMade"
    case updatedAt = "updatedAt"
    case rating = "rating"
    case random = "random"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .name: "Name"
        case .createdAt: "Date Created"
        case .lastMade: "Last Made"
        case .updatedAt: "Date Updated"
        case .rating: "Rating"
        case .random: "Random"
        }
    }
    
    var defaultDirection: SortDirection {
        switch self {
        case .name:
            return .asc
        case .createdAt, .lastMade, .updatedAt, .rating:
            return .desc
        case .random:
            return .asc
        }
    }
}

enum SortDirection: String {
    case asc = "asc"
    case desc = "desc"
}
