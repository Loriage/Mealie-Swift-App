import Foundation

struct ReadPlanEntry: Codable, Identifiable, Hashable {
    let id: Int
    let date: String
    let entryType: String
    let title: String
    let text: String
    let recipeId: UUID?
    let groupId: UUID
    let userId: UUID
    let householdId: UUID
    var recipe: RecipeSummary?

    var mealType: MealType {
        MealType(rawValue: entryType.lowercased()) ?? .dinner
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReadPlanEntry, rhs: ReadPlanEntry) -> Bool {
        lhs.id == rhs.id
    }
}

struct PlanEntryPagination: Decodable {
    let items: [ReadPlanEntry]
    let totalPages: Int
}
