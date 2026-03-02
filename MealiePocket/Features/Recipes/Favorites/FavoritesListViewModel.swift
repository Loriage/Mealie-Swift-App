import Foundation
import Combine

@Observable
class FavoritesListViewModel {
    var recipes: [RecipeSummary] = []
    var searchText: String = ""
    
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    
    var sortOption: SortOption = .name
    var sortDirection: SortDirection = .asc
    
    private var searchTask: Task<Void, Never>? = nil
    private var favoriteRatings: [UserRating] = []
    
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
                await performSearchOrLoad(apiClient: apiClient, userID: userID, loadMore: false)
            } catch {}
        }
    }
    
    private func performSearchOrLoad(apiClient: MealieAPIClient?, userID: String?, loadMore: Bool) async {
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
        
        let pageToLoad = loadMore ? currentPage + 1 : 1
        
        do {
            if !loadMore {
                self.favoriteRatings = try await apiClient.fetchFavorites(userID: userID)
            }
            
            if self.favoriteRatings.isEmpty {
                await MainActor.run {
                    self.recipes = []
                    self.isLoading = false
                    self.isLoadingMore = false
                    self.totalPages = 1
                    self.currentPage = 1
                }
                return
            }
            
            let favoriteIDs = self.favoriteRatings.map { $0.recipeId.uuidString }
            let favoritesFilter = "id IN [\"\(favoriteIDs.joined(separator: "\",\""))\"]"
            let searchFilter = searchText.isEmpty ? nil : "name LIKE %\(searchText)%"
            let queryFilter = [favoritesFilter, searchFilter].compactMap { $0 }.joined(separator: " AND ")
            
            let response = try await apiClient.fetchRecipes(
                page: pageToLoad,
                orderBy: sortOption.rawValue,
                orderDirection: sortDirection.rawValue,
                paginationSeed: nil,
                queryFilter: queryFilter,
                perPage: 50
            )
            
            let fetchedRecipes = response.items
            let userRatingsDict = Dictionary(uniqueKeysWithValues: self.favoriteRatings.map { ($0.recipeId, $0) })
            
            var updatedRecipes = fetchedRecipes
            for i in updatedRecipes.indices {
                if let userRatingData = userRatingsDict[updatedRecipes[i].id] {
                    updatedRecipes[i].isFavorite = userRatingData.isFavorite
                    updatedRecipes[i].userRating = userRatingData.rating
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
                self.errorMessage = "error.loadingFavorites"
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }
    
    func applySort(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, loadMore: false)
    }
    
    func loadInitialOrRefreshRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, loadMore: false)
    }
    
    func loadMoreRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        await performSearchOrLoad(apiClient: apiClient, userID: userID, loadMore: true)
    }
    
    func toggleFavorite(for recipeId: UUID, userID: String?, apiClient: MealieAPIClient?) async {
        guard let apiClient, let userID else { return }
        
        guard let recipe = recipes.first(where: { $0.id == recipeId }) else { return }
        
        do {
            try await apiClient.removeFavorite(userID: userID, slug: recipe.slug)
            await MainActor.run {
                self.recipes.removeAll { $0.id == recipeId }
                self.favoriteRatings.removeAll { $0.recipeId == recipeId }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "error.updatingFavorite"
            }
        }
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case name = "name"
        case createdAt = "createdAt"
        case lastMade = "lastMade"
        case updatedAt = "updatedAt"
        case rating = "rating"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .name: "Name"
            case .createdAt: "Date Created"
            case .lastMade: "Last Made"
            case .updatedAt: "Date Updated"
            case .rating: "Rating"
            }
        }
        
        var defaultDirection: SortDirection {
            switch self {
            case .name:
                return .asc
            case .createdAt, .lastMade, .updatedAt, .rating:
                return .desc
            }
        }
    }
    
    enum SortDirection: String {
        case asc = "asc"
        case desc = "desc"
    }
}
