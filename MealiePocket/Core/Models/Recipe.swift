import Foundation

struct RecipeSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
    let recipeYield: String?
    let totalTime: String?
    let prepTime: String?
    let rating: Double?
    var userRating: Double?
    var isFavorite: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, recipeYield, totalTime, prepTime, rating
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        recipeYield = try container.decodeIfPresent(String.self, forKey: .recipeYield)
        totalTime = try container.decodeIfPresent(String.self, forKey: .totalTime)
        prepTime = try container.decodeIfPresent(String.self, forKey: .prepTime)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        userRating = nil
        isFavorite = false
    }
    
    init(id: UUID, name: String, slug: String, recipeYield: String?, totalTime: String?, prepTime: String?, rating: Double?, userRating: Double?, isFavorite: Bool) {
        self.id = id
        self.name = name
        self.slug = slug
        self.recipeYield = recipeYield
        self.totalTime = totalTime
        self.prepTime = prepTime
        self.rating = rating
        self.userRating = userRating
        self.isFavorite = isFavorite
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RecipeSummary, rhs: RecipeSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.slug == rhs.slug &&
        lhs.rating == rhs.rating &&
        lhs.userRating == rhs.userRating &&
        lhs.isFavorite == rhs.isFavorite
    }
}

struct PaginatedRecipes: Decodable {
    let items: [RecipeSummary]
    let totalPages: Int
}

struct RecipeDetail: Decodable, Identifiable {
    let id: UUID
    let userId: String?
    let householdId: String?
    let groupId: String?
    let name: String
    let slug: String
    let image: String?
    let description: String?
    let rating: Double?
    var userRating: Double?
    let recipeServings: Double?
    let recipeYieldQuantity: Int?
    let recipeYield: String?
    let totalTime: String?
    let prepTime: String?
    let cookTime: String?
    let performTime: String?
    let recipeCategory: [RecipeCategory]?
    let tags: [RecipeTag]?
    let tools: [RecipeTool]?
    let orgURL: String?
    let dateAdded: String?
    let dateUpdated: String?
    let createdAt: String?
    let updatedAt: String?
    let lastMade: String?
    let recipeIngredient: [RecipeIngredient]
    let recipeInstructions: [RecipeInstruction]
    let nutrition: Nutrition?
    let settings: RecipeSettings?
    let assets: [RecipeAsset]?
    let notes: [RecipeNote]?
    let extras: [String: String]?
    let comments: [CommentStub]?
    
    private enum CodingKeys: String, CodingKey {
        case id, userId, householdId, groupId, name, slug, image, description, rating,
             recipeServings, recipeYieldQuantity, recipeYield, totalTime, prepTime, cookTime, performTime,
             recipeCategory, tags, tools, orgURL, dateAdded, dateUpdated, createdAt, updatedAt, lastMade,
             recipeIngredient, recipeInstructions, nutrition, settings, assets, notes, extras, comments
    }
}

struct RecipeIngredient: Codable, Identifiable, Hashable {
    var id = UUID()
    var referenceId: String?
    var display: String
    var title: String?
    var note: String?
    var quantity: Double?
    var unit: IngredientUnitStub?
    var food: IngredientFoodStub?
    var originalText: String?
    
    init(id: UUID = UUID(), referenceId: String? = nil, display: String = "", title: String? = nil, note: String? = nil, quantity: Double? = 0, unit: IngredientUnitStub? = nil, food: IngredientFoodStub? = nil, originalText: String? = nil) {
        self.id = id
        self.referenceId = referenceId
        self.display = display
        self.title = title
        self.note = note
        self.quantity = quantity ?? 0
        self.unit = unit
        self.food = food
        self.originalText = originalText
    }
    
    enum CodingKeys: String, CodingKey {
        case referenceId, display, title, note, quantity, unit, food, originalText
    }

    struct IngredientUnitStub: Codable, Hashable, Identifiable {
        var id: String
        var name: String
    }

    struct IngredientFoodStub: Codable, Hashable, Identifiable {
        var id: String
        var name: String
    }
}


struct RecipeInstruction: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String?
    var summary: String?
    var text: String
    var ingredientReferences: [IngredientReferenceStub]?
    
    init(id: UUID = UUID(), title: String? = "", summary: String? = "", text: String = "", ingredientReferences: [IngredientReferenceStub]? = []) {
        self.id = id
        self.title = title ?? ""
        self.summary = summary ?? ""
        self.text = text
        self.ingredientReferences = ingredientReferences ?? []
    }
    struct IngredientReferenceStub: Codable, Hashable {}
}

struct RecipeNote: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String?
    var text: String?

    init(id: UUID = UUID(), title: String? = nil, text: String? = nil) {
        self.id = id
        self.title = title ?? ""
        self.text = text ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
    }
}

struct RecipeAsset: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String?
    var icon: String?
    var fileName: String?

    init(id: UUID = UUID(), name: String? = nil, icon: String? = nil, fileName: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.fileName = fileName
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, fileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
    }
}

struct RecipeTagInput: Codable, Identifiable, Hashable {
    var id: UUID?
    var name: String
    
    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
    }
}

struct RecipeTag: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
}

struct RecipeCategoryInput: Codable, Identifiable, Hashable {
    var id: UUID?
    var name: String
    
    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
    }
}

struct RecipeCategory: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
}

struct RecipeTool: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
}

struct RecipeToolInput: Codable, Identifiable, Hashable {
    var id: UUID?
    var name: String
    
    init(id: UUID = UUID(), name: String = "") {
        self.id = id
        self.name = name
    }
    private enum CodingKeys: String, CodingKey { case name }
}


struct RecipeSettings: Codable, Hashable {
    var disableComments: Bool?
    var landscapeView: Bool?
    var locked: Bool?
    var publicRecipe: Bool?
    var showAssets: Bool?
    var showNutrition: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case disableComments, landscapeView, locked, showAssets, showNutrition
        case publicRecipe = "public"
    }
    
    init(disableComments: Bool? = false, landscapeView: Bool? = false, locked: Bool? = false, publicRecipe: Bool? = false, showAssets: Bool? = false, showNutrition: Bool? = false) {
        self.disableComments = disableComments ?? false
        self.landscapeView = landscapeView ?? false
        self.locked = locked ?? false
        self.publicRecipe = publicRecipe ?? false
        self.showAssets = showAssets ?? false
        self.showNutrition = showNutrition ?? false
    }
}

struct Nutrition: Codable, Hashable {
    var calories: String?
    var carbohydrateContent: String?
    var cholesterolContent: String?
    var fatContent: String?
    var fiberContent: String?
    var proteinContent: String?
    var saturatedFatContent: String?
    var sodiumContent: String?
    var sugarContent: String?
    var transFatContent: String?
    var unsaturatedFatContent: String?
}

struct CommentStub: Codable, Hashable {}

struct CreateIngredientFood: Codable, Hashable {
    let name: String
}

struct ShoppingListAddRecipeParamsBulkPayload: Codable {
    var recipeId: String
    var scale: Double = 1.0
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipeId"
        case scale
    }
}
