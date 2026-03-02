import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case side
    case snack
    case drink
    case dessert

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.fill"
        case .side:      return "fork.knife"
        case .snack:     return "carrot"
        case .drink:     return "cup.and.saucer.fill"
        case .dessert:   return "birthday.cake.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch:     return 1
        case .dinner:    return 2
        case .side:      return 3
        case .snack:     return 4
        case .drink:     return 5
        case .dessert:   return 6
        }
    }
}
