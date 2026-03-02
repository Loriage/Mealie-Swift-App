import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(statusCode: Int, error: Error?)
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case encodingError(Error)
    case tokenRefreshFailed
    case timeout
    case unknown(Error)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        let b = AppLocale.bundle
        switch self {
        case .invalidURL:
            return NSLocalizedString("api.error.invalidURL", bundle: b, comment: "")
        case .requestFailed(let statusCode, _):
            return String(format: NSLocalizedString("api.error.requestFailed", bundle: b, comment: ""), statusCode)
        case .invalidResponse:
            return NSLocalizedString("api.error.invalidResponse", bundle: b, comment: "")
        case .decodingError:
            return NSLocalizedString("api.error.decodingError", bundle: b, comment: "")
        case .unauthorized:
            return NSLocalizedString("api.error.unauthorized", bundle: b, comment: "")
        case .encodingError:
            return NSLocalizedString("api.error.encodingError", bundle: b, comment: "")
        case .tokenRefreshFailed:
            return NSLocalizedString("api.error.tokenRefreshFailed", bundle: b, comment: "")
        case .timeout:
            return NSLocalizedString("api.error.timeout", bundle: b, comment: "")
        case .unknown:
            return NSLocalizedString("api.error.unknown", bundle: b, comment: "")
        }
    }
}

extension Notification.Name {
    static let userUnauthorizedNotification = Notification.Name("userUnauthorizedNotification")
    static let tokenRefreshedNotification = Notification.Name("tokenRefreshedNotification")
}

class MealieAPIClient {
    let baseURL: URL
    private var token: String?
    private let defaultRecipesPerPage = 20
    private let session: URLSession
    private let longTaskSession: URLSession
    private var isRefreshingToken = false
    private var requestQueue: [(URLRequest, (Result<Data, Error>) -> Void)] = []
    
    
    struct NoReply: Decodable {}
    struct RefreshResponse: Decodable {
        let accessToken: String
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }
    
    struct CreatePlanEntry: Codable {
        let date: String
        let recipeId: String
        let entryType: String
    }
    
    struct ReadPlanEntry: Codable {
        let id: Int
    }
    
    struct UpdateRecipePayload: Codable {
        var id: UUID
        var userId: String?
        var householdId: String?
        var groupId: String?
        var name: String
        var slug: String
        var image: String?
        var recipeServings: Double?
        var recipeYieldQuantity: Int?
        var recipeYield: String?
        var totalTime: String?
        var prepTime: String?
        var cookTime: String?
        var performTime: String?
        var description: String?
        var recipeCategory: [RecipeCategoryInput]?
        var tags: [RecipeTagInput]?
        var tools: [RecipeToolInput]?
        var rating: Double?
        var orgURL: String?
        var dateAdded: String?
        var dateUpdated: String?
        var createdAt: String?
        var updatedAt: String?
        var lastMade: String?
        var recipeIngredient: [RecipeIngredient]
        var recipeInstructions: [RecipeInstruction]
        var nutrition: Nutrition?
        var settings: RecipeSettings?
        var assets: [RecipeAsset]?
        var notes: [RecipeNote]?
        var extras: [String: String]?
        var comments: [CommentStub]?
    }
    
    struct CreateRandomEntry: Codable {
        let date: String
        let entryType: String
    }
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let longTaskConfig = URLSessionConfiguration.default
        longTaskConfig.timeoutIntervalForRequest = 300
        longTaskConfig.timeoutIntervalForResource = 600
        self.longTaskSession = URLSession(configuration: longTaskConfig)
    }
    
    func setToken(_ token: String?) {
        self.token = token
    }
    
    func getToken() -> String? {
        return self.token
    }

    private func _performRequest<T: Decodable>(for request: URLRequest, on session: URLSession) async throws -> T {
        var mutableRequest = request

        if let token = self.token {
            mutableRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: mutableRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                do {
                    let newToken = try await refreshToken()
                    mutableRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (newData, newResponse) = try await session.data(for: mutableRequest)
                    
                    guard let newHttpResponse = newResponse as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }
                    
                    guard (200...299).contains(newHttpResponse.statusCode) else {
                        if newHttpResponse.statusCode == 401 {
                            NotificationCenter.default.post(name: .userUnauthorizedNotification, object: nil)
                            throw APIError.unauthorized
                        } else {
                            throw APIError.requestFailed(statusCode: newHttpResponse.statusCode, error: nil)
                        }
                    }
                    return try decodeResponseData(newData)
                    
                } catch {
                    NotificationCenter.default.post(name: .userUnauthorizedNotification, object: nil)
                    throw APIError.tokenRefreshFailed
                }
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, error: nil)
            }
            
            return try decodeResponseData(data)
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw APIError.timeout
            }
            throw APIError.requestFailed(statusCode: urlError.code.rawValue, error: urlError)
        } catch {
            throw APIError.unknown(error)
        }
    }

    private func performRequest<T: Decodable>(for request: URLRequest) async throws -> T {
        return try await _performRequest(for: request, on: self.session)
    }

    private func performLongTaskRequest<T: Decodable>(for request: URLRequest) async throws -> T {
        return try await _performRequest(for: request, on: self.longTaskSession)
    }

    private func decodeResponseData<T: Decodable>(_ data: Data) throws -> T {
        if T.self == NoReply.self {
            if let noReply = NoReply() as? T {
                return noReply
            } else {
                throw APIError.decodingError(NSError(domain: "MealieAPIClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not cast to NoReply"]))
            }
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func refreshToken() async throws -> String {
        let url = baseURL.appendingPathComponent("api/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let currentToken = self.token else {
            throw APIError.unauthorized
        }
        request.addValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, error: nil)
            }
            
            let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
            let newToken = refreshResponse.accessToken
            
            self.token = newToken
            
            NotificationCenter.default.post(name: .tokenRefreshedNotification, object: newToken)
            
            return newToken
            
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError {
            throw APIError.requestFailed(statusCode: urlError.code.rawValue, error: urlError)
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    func login(username: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "username=\(username)&password=\(password)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, error: nil)
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            self.token = tokenResponse.accessToken
            return tokenResponse.accessToken
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    func fetchCurrentUser() async throws -> User {
        let url = baseURL.appendingPathComponent("api/users/self")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func fetchAllRecipes(orderBy: String, orderDirection: String, paginationSeed: String?) async throws -> [RecipeSummary] {
        var allRecipes: [RecipeSummary] = []
        var currentPage = 1
        var totalPages = 1
        
        repeat {
            let paginatedResponse: PaginatedRecipes = try await fetchRecipes(
                page: currentPage,
                orderBy: orderBy,
                orderDirection: orderDirection,
                paginationSeed: paginationSeed,
                perPage: 100
            )
            allRecipes.append(contentsOf: paginatedResponse.items)
            totalPages = paginatedResponse.totalPages
            currentPage += 1
        } while currentPage <= totalPages && totalPages > 0
        
        return allRecipes
    }
    
    func fetchRecipes(page: Int, orderBy: String, orderDirection: String, paginationSeed: String?, queryFilter: String? = nil, perPage: Int? = nil) async throws -> PaginatedRecipes {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/recipes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage ?? defaultRecipesPerPage)"),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "orderDirection", value: orderDirection)
        ]
        
        if let seed = paginationSeed {
            components?.queryItems?.append(URLQueryItem(name: "paginationSeed", value: seed))
        }
        
        if let filter = queryFilter, !filter.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "queryFilter", value: filter))
        }
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func fetchRatings(userID: String) async throws -> [UserRating] {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/ratings")
        let request = URLRequest(url: url)
        let response: UserRatingsResponse = try await performRequest(for: request)
        return response.ratings
    }
    
    func fetchFavorites(userID: String) async throws -> [UserRating] {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites")
        let request = URLRequest(url: url)
        let response: UserRatingsResponse = try await performRequest(for: request)
        return response.ratings
    }
    
    func fetchRecipeDetail(slug: String) async throws -> RecipeDetail {
        let url = baseURL.appendingPathComponent("api/recipes/\(slug)")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func addFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _: NoReply = try await performRequest(for: request)
    }
    
    func removeFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _: NoReply = try await performRequest(for: request)
    }
    
    func setRating(userID: String, slug: String, rating: Double) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/ratings/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["rating": rating]
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        let _: NoReply = try await performRequest(for: request)
    }
    
    func addMealPlanEntry(date: Date, recipeId: UUID, entryType: MealType) async throws {
        let url = baseURL.appendingPathComponent("api/households/mealplans")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let body = CreatePlanEntry(
            date: dateString,
            recipeId: recipeId.uuidString,
            entryType: entryType.rawValue
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        let _: ReadPlanEntry = try await performRequest(for: request)
    }
    
    func updateRecipe(slug: String, payload: UpdateRecipePayload) async throws {
        let url = baseURL.appendingPathComponent("api/recipes/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw APIError.encodingError(error)
        }
        
        let _: NoReply = try await performRequest(for: request)
    }
    
    func getUnits(page: Int = 1, perPage: Int = 500) async throws -> IngredientUnitPagination {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/units"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func searchFoods(query: String, page: Int = 1, perPage: Int = 50) async throws -> IngredientFoodPagination {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/foods"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func createFood(name: String) async throws -> RecipeIngredient.IngredientFoodStub {
        let url = baseURL.appendingPathComponent("api/foods")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateIngredientFood(name: name)
        
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func fetchMealPlanEntries(startDate: String, endDate: String, page: Int = 1, perPage: Int = 500) async throws -> PlanEntryPagination {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/households/mealplans"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)"),
            URLQueryItem(name: "orderBy", value: "date"),
            URLQueryItem(name: "orderDirection", value: "asc")
        ]
        
        guard let url = components?.url else { throw APIError.invalidURL }
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func deleteMealPlanEntry(entryID: Int) async throws {
        let url = baseURL.appendingPathComponent("api/households/mealplans/\(entryID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let _: ReadPlanEntry = try await performRequest(for: request)
    }
    
    func addRandomMealPlanEntry(date: Date, entryType: MealType) async throws -> ReadPlanEntry {
        let url = baseURL.appendingPathComponent("api/households/mealplans/random")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let body = CreateRandomEntry(
            date: dateString,
            entryType: entryType.rawValue
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        let createdEntry: ReadPlanEntry = try await performRequest(for: request)
        
        return createdEntry
    }
    
    func fetchShoppingLists(page: Int = 1, perPage: Int = 50) async throws -> ShoppingListPagination {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/households/shopping/lists"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage)"),
            URLQueryItem(name: "orderBy", value: "updatedAt"),
            URLQueryItem(name: "orderDirection", value: "desc")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func fetchShoppingListDetail(listId: UUID) async throws -> ShoppingListDetail {
        let url = baseURL.appendingPathComponent("api/households/shopping/lists/\(listId.uuidString.lowercased())")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func createShoppingList(name: String?) async throws -> ShoppingListDetail {
        let url = baseURL.appendingPathComponent("api/households/shopping/lists")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ShoppingListCreate(name: name)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func updateShoppingList(list: ShoppingListSummary, name: String?) async throws -> ShoppingListDetail {
        let url = baseURL.appendingPathComponent("api/households/shopping/lists/\(list.id.uuidString.lowercased())")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ShoppingListUpdate(
            name: name,
            id: list.id,
            groupId: list.groupId,
            userId: list.userId
        )
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func deleteShoppingList(listId: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/households/shopping/lists/\(listId.uuidString.lowercased())")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let _: NoReply = try await performRequest(for: request)
    }
    
    func addShoppingListItem(listId: UUID, note: String, quantity: Double = 1.0) async throws -> ShoppingListItemsCollectionResponse {
        let url = baseURL.appendingPathComponent("api/households/shopping/items")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ShoppingListItemCreatePayload(shoppingListId: listId.uuidString.lowercased(), note: note, quantity: quantity)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func updateShoppingListItem(item: ShoppingListItem) async throws -> ShoppingListItemsCollectionResponse {
        let url = baseURL.appendingPathComponent("api/households/shopping/items/\(item.id.uuidString.lowercased())")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        
        let body = ShoppingListItemUpdatePayload(
            id: item.id.uuidString.lowercased(),
            shoppingListId: item.shoppingListId.uuidString.lowercased(),
            note: item.note,
            quantity: item.quantity,
            checked: item.checked
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func updateShoppingListItemsBulk(items: [ShoppingListItem]) async throws -> ShoppingListItemsCollectionResponse {
        let url = baseURL.appendingPathComponent("api/households/shopping/items")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyPayloads = items.map { item in
            ShoppingListItemUpdatePayload(
                id: item.id.uuidString.lowercased(),
                shoppingListId: item.shoppingListId.uuidString.lowercased(),
                note: item.note,
                quantity: item.quantity,
                checked: item.checked
            )
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(bodyPayloads)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }
    
    func deleteShoppingListItem(itemId: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/households/shopping/items/\(itemId.uuidString.lowercased())")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let _: NoReply = try await performRequest(for: request)
    }
    
    func addRecipesToShoppingListBulk(listId: UUID, recipeIds: [UUID]) async throws -> ShoppingListDetail {
        guard !recipeIds.isEmpty else {
            
            throw APIError.invalidURL
        }
        
        let url = baseURL.appendingPathComponent("api/households/shopping/lists/\(listId.uuidString.lowercased())/recipe")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = recipeIds.map { ShoppingListAddRecipeParamsBulkPayload(recipeId: $0.uuidString.lowercased()) }
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw APIError.encodingError(error)
        }
        
        return try await performRequest(for: request)
    }

    func fetchAppInfo() async throws -> AppInfo {
        let url = baseURL.appendingPathComponent("api/app/about")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func fetchHouseholdStatistics() async throws -> HouseholdStatistics {
        let url = baseURL.appendingPathComponent("api/households/statistics")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func fetchReports(type: ReportCategory? = nil) async throws -> [ReportSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/groups/reports"), resolvingAgainstBaseURL: false)
        
        if let type = type {
            components?.queryItems = [URLQueryItem(name: "report_type", value: type.rawValue)]
        }
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func fetchReportDetail(id: UUID) async throws -> ReportOut {
        let url = baseURL.appendingPathComponent("api/groups/reports/\(id.uuidString.lowercased())")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func cleanImages() async throws -> SuccessResponse {
        let url = baseURL.appendingPathComponent("api/admin/maintenance/clean/images")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return try await performLongTaskRequest(for: request)
    }

    func cleanTempFiles() async throws -> SuccessResponse {
        let url = baseURL.appendingPathComponent("api/admin/maintenance/clean/temp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return try await performLongTaskRequest(for: request)
    }
 
    func createBackup() async throws -> SuccessResponse {
        let url = baseURL.appendingPathComponent("api/admin/backups")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return try await performLongTaskRequest(for: request)
    }

    func rescheduleMealPlanEntry(entryID: Int, toDate: Date, recipeId: UUID, entryType: MealType) async throws {
        try await addMealPlanEntry(date: toDate, recipeId: recipeId, entryType: entryType)
        try await deleteMealPlanEntry(entryID: entryID)
    }
}
