import Foundation
import SwiftUI
import Combine

@Observable
class EditRecipeViewModel {
    var allUnits: [RecipeIngredient.IngredientUnitStub] = []
    var foodSearchResults: [RecipeIngredient.IngredientFoodStub] = []

    private var originalRecipe: RecipeDetail
    
    var name: String
    var description: String
    var recipeYield: String
    var totalTime: String
    var prepTime: String
    var cookTime: String
    var performTime: String
    var ingredients: [RecipeIngredient]
    var instructions: [RecipeInstruction]
    var notes: [RecipeNote]
    var assets: [RecipeAsset]
    var tags: [RecipeTagInput]
    var categories: [RecipeCategoryInput]
    var tools: [RecipeToolInput]
    var settings: RecipeSettings

    private var id: UUID
    private var userId: String?
    private var householdId: String?
    private var groupId: String?
    private var slug: String
    private var image: String?
    private var recipeServings: Double?
    private var recipeYieldQuantity: Int?
    private var rating: Double?
    private var orgURL: String?
    private var dateAdded: String?
    private var dateUpdated: String?
    private var createdAt: String?
    private var updatedAt: String?
    private var lastMade: String?
    private var nutrition: Nutrition?
    private var extras: [String: String]?
    private var comments: [CommentStub]?
    
    
    var isLoading = false
    var errorMessage: String?
    var saveSuccessful = false
    
    init(recipe: RecipeDetail) {
        self.originalRecipe = recipe

        self.id = recipe.id
        self.userId = recipe.userId
        self.householdId = recipe.householdId
        self.groupId = recipe.groupId
        self.slug = recipe.slug
        self.image = recipe.image
        self.recipeServings = recipe.recipeServings
        self.recipeYieldQuantity = recipe.recipeYieldQuantity
        self.rating = recipe.rating
        self.orgURL = recipe.orgURL
        self.dateAdded = recipe.dateAdded
        self.dateUpdated = recipe.dateUpdated
        self.createdAt = recipe.createdAt
        self.lastMade = recipe.lastMade
        self.nutrition = recipe.nutrition
        self.extras = recipe.extras
        self.comments = recipe.comments

        self.name = recipe.name
        self.description = recipe.description ?? ""
        self.recipeYield = recipe.recipeYield ?? ""
        self.totalTime = recipe.totalTime ?? ""
        self.prepTime = recipe.prepTime ?? ""
        self.cookTime = recipe.cookTime ?? ""
        self.performTime = recipe.performTime ?? ""
        
        self.ingredients = recipe.recipeIngredient
        self.instructions = recipe.recipeInstructions
        self.notes = recipe.notes ?? []
        self.assets = recipe.assets ?? []
        self.tags = recipe.tags?.map { RecipeTagInput(name: $0.name) } ?? []
        self.categories = recipe.recipeCategory?.map { RecipeCategoryInput(name: $0.name) } ?? []
        self.tools = recipe.tools?.map { RecipeToolInput(name: $0.name) } ?? []
        self.settings = recipe.settings ?? RecipeSettings()
    }
    
    func addIngredient() { ingredients.append(RecipeIngredient()) }
    func removeIngredient(at offsets: IndexSet) { ingredients.remove(atOffsets: offsets) }
    func moveIngredients(from source: IndexSet, to destination: Int) { ingredients.move(fromOffsets: source, toOffset: destination) }
    
    func addInstruction() { instructions.append(RecipeInstruction()) }
    func removeInstruction(at offsets: IndexSet) { instructions.remove(atOffsets: offsets) }
    func moveInstructions(from source: IndexSet, to destination: Int) { instructions.move(fromOffsets: source, toOffset: destination) }
    
    func addNote() { notes.append(RecipeNote()) }
    func removeNote(at offsets: IndexSet) { notes.remove(atOffsets: offsets) }
    func moveNotes(from source: IndexSet, to destination: Int) { notes.move(fromOffsets: source, toOffset: destination) }
    
    func addTag() { tags.append(RecipeTagInput()) }
    func removeTag(at offsets: IndexSet) { tags.remove(atOffsets: offsets) }
    
    func addCategory() { categories.append(RecipeCategoryInput()) }
    func removeCategory(at offsets: IndexSet) { categories.remove(atOffsets: offsets) }

    func addTool() { tools.append(RecipeToolInput()) }
    func removeTool(at offsets: IndexSet) { tools.remove(atOffsets: offsets) }

    @MainActor
    func fetchAllUnits(apiClient: MealieAPIClient?) async {
        guard let apiClient else { return }
        do {
            let unitPagination = try await apiClient.getUnits(perPage: 500)
            
            self.allUnits = unitPagination.items
            
        } catch {}
    }

    func searchFoods(query: String, apiClient: MealieAPIClient?) async {
        guard let apiClient, !query.isEmpty else {
            self.foodSearchResults = []
            return
        }
        do {
            let foodPagination = try await apiClient.searchFoods(query: query)
            self.foodSearchResults = foodPagination.items
        } catch {}
    }

    @MainActor
    func createFood(name: String, apiClient: MealieAPIClient?) async -> RecipeIngredient.IngredientFoodStub? {
        guard let apiClient, !name.isEmpty else { return nil }
        
        do {
            let newFood = try await apiClient.createFood(name: name)
            return newFood
        } catch {
            return nil
        }
    }

    func saveChanges(apiClient: MealieAPIClient?) async -> Bool {
        guard let apiClient = apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        saveSuccessful = false
        var success = false

        let payload = MealieAPIClient.UpdateRecipePayload(
            id: id,
            userId: userId,
            householdId: householdId,
            groupId: groupId,
            name: name,
            slug: slug,
            image: image,
            recipeServings: recipeServings,
            recipeYieldQuantity: recipeYieldQuantity,
            recipeYield: recipeYield.isEmpty ? "" : recipeYield,
            totalTime: totalTime.isEmpty ? nil : totalTime,
            prepTime: prepTime.isEmpty ? nil : prepTime,
            cookTime: cookTime.isEmpty ? nil : cookTime,
            performTime: performTime.isEmpty ? nil : performTime,
            description: description.isEmpty ? "" : description,
            recipeCategory: categories.isEmpty ? [] : categories,
            tags: tags.isEmpty ? [] : tags,
            tools: tools.isEmpty ? [] : tools,
            rating: rating,
            orgURL: orgURL,
            dateAdded: dateAdded,
            dateUpdated: nil,
            createdAt: createdAt,
            updatedAt: nil,
            lastMade: lastMade,
            recipeIngredient: ingredients.map { ingredient in
                var updatedIngredient = ingredient
                updatedIngredient.title = ingredient.title?.isEmpty ?? true ? nil : ingredient.title
                updatedIngredient.originalText = ingredient.originalText?.isEmpty ?? true ? nil : ingredient.originalText
                return updatedIngredient
            },
            recipeInstructions: instructions.map { instruction in
                var updatedInstruction = instruction
                updatedInstruction.title = instruction.title ?? ""
                updatedInstruction.summary = instruction.summary ?? ""
                updatedInstruction.ingredientReferences = instruction.ingredientReferences ?? []
                return updatedInstruction
            },
            nutrition: nutrition,
            settings: settings,
            assets: assets,
            notes: notes.map { note in
                var updatedNote = note
                updatedNote.title = note.title ?? ""
                updatedNote.text = note.text ?? ""
                return updatedNote
            },
            extras: extras ?? [:],
            comments: comments ?? []
        )
        
        do {
            try await apiClient.updateRecipe(slug: originalRecipe.slug, payload: payload)
            
            await MainActor.run {
                self.isLoading = false
                self.saveSuccessful = true
                success = true
            }
        } catch APIError.unauthorized {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "error.savingRecipe"
                self.isLoading = false
            }
        }
        return success
    }
}
