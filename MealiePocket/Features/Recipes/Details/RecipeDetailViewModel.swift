import Foundation
import SwiftUI

@Observable
class RecipeDetailViewModel {
    var recipeDetail: RecipeDetail?
    var isFavorite: Bool = false
    var isLoading = false
    var errorMessage: String?
    var showingAddToPlanSheet = false
    var showingEditSheet = false
    var needsRefresh = false
    
    private var recipeSummary: RecipeSummary
    
    init(recipeSummary: RecipeSummary) {
        self.recipeSummary = recipeSummary
        self.isFavorite = recipeSummary.isFavorite
    }
    
    func loadRecipeDetail(slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "error.apiClientOrIDUnavailable"
            isLoading = false
            return
        }
        
        if !needsRefresh {
            isLoading = true
        }
        errorMessage = nil
        needsRefresh = false
        
        do {
            async let detailTask = apiClient.fetchRecipeDetail(slug: slug)
            async let ratingsTask = apiClient.fetchRatings(userID: userID)
            
            var detail = try await detailTask
            let allUserRatings = try await ratingsTask
            
            let currentUserRatingData = allUserRatings.first { $0.recipeId == detail.id }
            let currentFavoriteStatus = currentUserRatingData?.isFavorite ?? false
            
            detail.userRating = currentUserRatingData?.rating
            
            await MainActor.run {
                self.recipeDetail = detail
                self.isFavorite = currentFavoriteStatus
                self.isLoading = false
                self.needsRefresh = false
            }
            
        } catch APIError.unauthorized {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "error.loadingRecipeDetails"
                self.isLoading = false
                self.needsRefresh = false
            }
        }
    }
    
    func setRating(_ rating: Double, slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "error.apiClientOrIDUnavailable"
            return
        }
        
        let previousRating = recipeDetail?.userRating
        
        await MainActor.run {
            self.recipeDetail?.userRating = rating
        }
        
        do {
            try await apiClient.setRating(userID: userID, slug: slug, rating: rating)
        } catch APIError.unauthorized {
            await MainActor.run { self.recipeDetail?.userRating = previousRating }
        } catch {
            await MainActor.run {
                self.recipeDetail?.userRating = previousRating
                self.errorMessage = "error.settingRating"
            }
        }
    }
    
    func toggleFavorite(apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID, let detail = recipeDetail else {
            errorMessage = "error.toggleFavoriteMissingData"
            return
        }
        
        let slug = detail.slug
        let originalFavoriteStatus = isFavorite
        
        await MainActor.run {
            isFavorite.toggle()
        }
        
        do {
            if isFavorite {
                try await apiClient.addFavorite(userID: userID, slug: slug)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: slug)
            }
        } catch APIError.unauthorized {
            await MainActor.run { isFavorite = originalFavoriteStatus }
        } catch {
            await MainActor.run {
                isFavorite = originalFavoriteStatus
                errorMessage = "error.updatingFavorite"
            }
        }
    }
    
    func addToMealPlan(date: Date, mealType: MealType, apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient, let detail = recipeDetail else {
            errorMessage = "error.addToPlanMissingData"
            return
        }
        
        do {
            try await apiClient.addMealPlanEntry(date: date, recipeId: detail.id, entryType: mealType)
            await MainActor.run {
                showingAddToPlanSheet = false
            }
        } catch APIError.unauthorized {
        } catch {
            await MainActor.run {
                errorMessage = "error.addingToMealPlan"
            }
        }
    }
    
    // MARK: - Recipe Scaling
    
    var targetServings: Double? = nil
    
    var originalServings: Double? {
        recipeDetail?.recipeServings
    }
    
    var scaleFactor: Double {
        IngredientScaler.scaleFactor(originalServings: originalServings, targetServings: targetServings)
    }
    
    var isScaled: Bool {
        guard let target = targetServings, let original = originalServings else { return false }
        return abs(target - original) > 0.01
    }
    
    var currentServings: Double? {
        targetServings ?? originalServings
    }
    
    func incrementServings() {
        guard let current = currentServings else { return }
        targetServings = current + 1
    }
    
    func decrementServings() {
        guard let current = currentServings, current > 1 else { return }
        targetServings = current - 1
    }
    
    func resetServings() {
        targetServings = nil
    }
    
    func scaledDisplayText(for ingredient: RecipeIngredient) -> String {
        let scale = scaleFactor
        guard scale != 1.0, let originalQty = ingredient.quantity, originalQty > 0 else {
            return ingredient.display
        }
        
        let scaledQty = originalQty * scale
        let formattedQty = IngredientScaler.formatQuantity(scaledQty)
        
        var parts: [String] = [formattedQty]
        if let unit = ingredient.unit {
            parts.append(unit.name)
        }
        if let food = ingredient.food {
            parts.append(food.name)
        }
        if !ingredient.note.isEmpty {
            parts.append(ingredient.note)
        }
        
        return parts.joined(separator: " ")
    }
    
    @MainActor
    func markForRefresh() {
        needsRefresh = true
    }
}
