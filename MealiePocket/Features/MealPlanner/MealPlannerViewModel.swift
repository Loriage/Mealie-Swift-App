import Foundation
import SwiftUI

@Observable
class MealPlannerViewModel {
    enum ViewMode: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .day:   return "planner.viewMode.day"
            case .week:  return "planner.viewMode.week"
            case .month: return "planner.viewMode.month"
            }
        }
    }
    
    var selectedDate = Date()
    var viewMode: ViewMode = .month
    var mealPlanEntries: [Date: [ReadPlanEntry]] = [:]
    var isLoading = false
    var isLoadingPast = false
    var isLoadingFuture = false
    var errorMessage: String?
    var imageLoadID = UUID()
    
    var displayedMonths: [Date] = []
    
    private var apiClient: MealieAPIClient?
    
    private var currentMonthStart: Date {
        Date().startOfMonth()
    }
    
    var showingAddRecipeSheet = false
    var showingMealTypeSelection = false
    var dateForAddingRecipe: Date? = nil
    var recipesForSelection: [RecipeSummary] = []
    var isLoadingRecipesForSelection = false
    var isLoadingMoreRecipesForSelection = false
    var searchQueryForSelection = ""
    private var searchTaskForSelection: Task<Void, Never>? = nil
    private var currentPageForSelection = 1
    private var totalPagesForSelection = 1
    var canLoadMoreForSelection: Bool { currentPageForSelection < totalPagesForSelection }
    
    var showingShoppingListSelection = false
    var availableShoppingLists: [ShoppingListSummary] = []
    var isLoadingShoppingLists = false
    var showingDateRangePicker = false
    var dateRangeStart = Date()
    var dateRangeEnd = Date()
    var importErrorMessage: String?
    var isImporting = false
    var importingListId: UUID? = nil
    var importSuccess = false
    
    init() {
        setupInitialMonths()
    }
    
    func setupInitialMonths(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let currentMonthStart = referenceDate.startOfMonth()
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let nextMonth2 = calendar.date(byAdding: .month, value: 2, to: currentMonthStart)
        else {
            displayedMonths = [currentMonthStart]
            return
        }
        displayedMonths = [currentMonthStart, nextMonth, nextMonth2]
    }
    
    private var dateIntervalForAPI: DateInterval {
        let calendar = Calendar.current
        
        if viewMode != .month {
            let component: Calendar.Component = viewMode == .day ? .day : .weekOfYear
            guard let interval = calendar.dateInterval(of: component, for: selectedDate) else {
                return DateInterval(start: selectedDate, duration: 0)
            }
            return interval
        }
        
        guard let firstMonth = displayedMonths.first,
              let lastMonth = displayedMonths.last,
              let lastMonthInterval = calendar.dateInterval(of: .month, for: lastMonth),
              let endDayForAPI = calendar.date(byAdding: .day, value: 1, to: lastMonthInterval.end)
        else {
            return calendar.dateInterval(of: .month, for: Date()) ?? DateInterval()
        }
        
        return DateInterval(start: firstMonth.startOfMonth(), end: endDayForAPI)
    }
    
    var canChangeDateBack: Bool {
        let calendar = Calendar.current
        let component: Calendar.Component = viewMode == .day ? .day : .weekOfYear
        
        guard let newDate = calendar.date(byAdding: component, value: -1, to: selectedDate) else {
            return false
        }
        
        if viewMode == .day {
            return newDate >= currentMonthStart
        } else if viewMode == .week {
            guard let newWeekInterval = calendar.dateInterval(of: .weekOfYear, for: newDate) else {
                return false
            }
            return newWeekInterval.end > currentMonthStart
        }
        
        return false
    }
    
    var daysInSpecificMonth: (Date) -> [Date] = { date in
        Calendar.current.generateDaysInMonth(for: date)
    }
    
    var daysInWeek: [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return Calendar.current.generateDates(for: weekInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    func changeDate(_ direction: Int) {
        let component: Calendar.Component = viewMode == .day ? .day : (viewMode == .week ? .weekOfYear : .month)
        let dateToChange = selectedDate
        
        if let newDate = Calendar.current.date(byAdding: component, value: direction, to: dateToChange) {
            selectedDate = newDate
        }
    }
    
    func loadMoreMonths(direction: Int, apiClient: MealieAPIClient?) async {
        guard !isLoadingPast && !isLoadingFuture else { return }
        
        if direction < 0 {
            return
        }
        
        if direction > 0 { isLoadingFuture = true }
        
        let calendar = Calendar.current
        let monthsToAdd = 3
        
        if direction > 0, let lastMonth = displayedMonths.last {
            var newMonths: [Date] = []
            for i in 1...monthsToAdd {
                if let next = calendar.date(byAdding: .month, value: i, to: lastMonth) {
                    newMonths.append(next)
                }
            }
            if !newMonths.isEmpty {
                displayedMonths.append(contentsOf: newMonths)
                await loadMealPlan(apiClient: apiClient)
            }
        }
        
        if direction > 0 { isLoadingFuture = false }
    }
    
    
    func goToToday(apiClient: MealieAPIClient?) {
        let today = Date()
        let todayMonthStart = today.startOfMonth()
        selectedDate = today
        
        if viewMode != .month || !displayedMonths.contains(todayMonthStart) {
            if !displayedMonths.contains(todayMonthStart) {
                setupInitialMonths(referenceDate: today)
            }
            Task { await loadMealPlan(apiClient: apiClient) }
        }
    }
    
    func selectDateAndView(date: Date) {
        selectedDate = date
        viewMode = .day
    }

    func goToWeek(date: Date) {
        selectedDate = date
        viewMode = .week
    }
    
    func loadMealPlan(apiClient: MealieAPIClient? = nil) async {
        if let apiClient = apiClient {
            self.apiClient = apiClient
        }
        
        guard let client = self.apiClient else {
            errorMessage = String(localized: "error.apiClientUnavailable")
            isLoading = false
            isLoadingPast = false
            isLoadingFuture = false
            return
        }
        
        if !isLoadingPast && !isLoadingFuture {
            isLoading = true
        }
        errorMessage = nil
        
        let interval = dateIntervalForAPI
        let startDateString = dateFormatter.string(from: interval.start)
        let endDateString = dateFormatter.string(from: interval.end)
        
        do {
            let perPage = viewMode == .month ? 1000 : 100
            let response = try await client.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString, perPage: perPage)
            
            var groupedEntries: [Date: [ReadPlanEntry]] = [:]
            for entry in response.items {
                if let entryDate = dateFormatter.date(from: entry.date) {
                    let dayStart = Calendar.current.startOfDay(for: entryDate)
                    groupedEntries[dayStart, default: []].append(entry)
                } else {
                    print("Warning: Could not parse date string \(entry.date)")
                }
            }
            
            await MainActor.run {
                self.mealPlanEntries = groupedEntries
                self.isLoading = false
                self.isLoadingPast = false
                self.isLoadingFuture = false
                self.errorMessage = nil
                self.imageLoadID = UUID()
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "error.loadingPlan") + ": " + error.localizedDescription
                self.isLoading = false
                self.isLoadingPast = false
                self.isLoadingFuture = false
            }
        }
    }
    
    func presentAddRecipeSheet(for date: Date) {
        dateForAddingRecipe = date
        searchQueryForSelection = ""
        recipesForSelection = []
        currentPageForSelection = 1
        totalPagesForSelection = 1
        isLoadingRecipesForSelection = false
        isLoadingMoreRecipesForSelection = false
        showingAddRecipeSheet = true
    }
    
    func presentRandomMealTypeSheet(for date: Date) {
        dateForAddingRecipe = date
        showingMealTypeSelection = true
    }
    
    func searchRecipesForSelection(apiClient: MealieAPIClient?, loadMore: Bool = false) async {
        guard let apiClient = apiClient else { return }
        
        if !loadMore {
            searchTaskForSelection?.cancel()
            currentPageForSelection = 1
            isLoadingRecipesForSelection = true
            isLoadingMoreRecipesForSelection = false
        } else {
            guard canLoadMoreForSelection, !isLoadingMoreRecipesForSelection else { return }
            isLoadingMoreRecipesForSelection = true
            isLoadingRecipesForSelection = false
        }
        
        searchTaskForSelection = Task {
            do {
                if !loadMore {
                    try await Task.sleep(nanoseconds: 300_000_000)
                }
                
                let pageToLoad = loadMore ? currentPageForSelection + 1 : 1
                
                let response = try await apiClient.fetchRecipes(
                    page: pageToLoad,
                    orderBy: "name",
                    orderDirection: "asc",
                    paginationSeed: nil,
                    queryFilter: searchQueryForSelection.isEmpty ? nil : "name LIKE %\(searchQueryForSelection)%",
                    perPage: 25
                )
                
                let fetchedRecipes = response.items
                
                await MainActor.run {
                    if loadMore {
                        self.recipesForSelection.append(contentsOf: fetchedRecipes)
                        self.currentPageForSelection = pageToLoad
                    } else {
                        self.recipesForSelection = fetchedRecipes
                        self.currentPageForSelection = 1
                    }
                    self.totalPagesForSelection = response.totalPages
                    
                    self.isLoadingRecipesForSelection = false
                    self.isLoadingMoreRecipesForSelection = false
                }
            } catch APIError.unauthorized {
                await MainActor.run {
                    isLoadingRecipesForSelection = false
                    isLoadingMoreRecipesForSelection = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    if !loadMore { isLoadingRecipesForSelection = false }
                }
            } catch {
                await MainActor.run {
                    print("Error searching recipes for selection: \(error)")
                    if !loadMore { self.recipesForSelection = [] }
                    self.isLoadingRecipesForSelection = false
                    self.isLoadingMoreRecipesForSelection = false
                }
            }
        }
    }
    
    func loadMoreRecipesForSelection(apiClient: MealieAPIClient?) async {
        await searchRecipesForSelection(apiClient: apiClient, loadMore: true)
    }
    
    func addSelectedRecipeToPlan(recipe: RecipeSummary, mealType: String, apiClient: MealieAPIClient?) async {
        guard let date = dateForAddingRecipe, let apiClient = apiClient else {
            errorMessage = String(localized: "error.missingDateOrClient")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiClient.addMealPlanEntry(date: date, recipeId: recipe.id, entryType: mealType)
            await loadMealPlan(apiClient: apiClient)
            await MainActor.run {
                showingAddRecipeSheet = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "error.addingMeal") + ": " + error.localizedDescription
                isLoading = false
            }
        }
    }

    func addRandomMeal(date: Date, mealType: String) async {
        guard let date = dateForAddingRecipe, let apiClient = apiClient else {
            errorMessage = String(localized: "error.apiClientUnavailable")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let _ = try await apiClient.addRandomMealPlanEntry(date: date, entryType: mealType)
            await loadMealPlan(apiClient: apiClient)
            await MainActor.run {
                showingMealTypeSelection = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "error.randomMeal") + ": " + error.localizedDescription
                isLoading = false
            }
        }
    }

    func deleteMealEntry(entryID: Int) async {
        guard let client = self.apiClient else {
            errorMessage = String(localized: "error.apiClientUnavailable")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await client.deleteMealPlanEntry(entryID: entryID)
            await loadMealPlan(apiClient: client)
        } catch {
            await MainActor.run {
                errorMessage = String(localized: "error.deletingMeal") + ": " + error.localizedDescription
                isLoading = false
            }
        }
    }

    @MainActor
    private func prepareImport(startDate: Date, endDate: Date, apiClient: MealieAPIClient?) {
        guard apiClient != nil else {
            errorMessage = String(localized: "error.apiClientUnavailable")
            return
        }
        
        self.apiClient = apiClient
        self.dateRangeStart = startDate
        self.dateRangeEnd = endDate
        
        importErrorMessage = nil
        isImporting = false
        importSuccess = false
        
        Task {
            await loadShoppingLists()
            showingShoppingListSelection = true
        }
    }
    
    @MainActor
    func addDay(apiClient: MealieAPIClient?) {
        prepareImport(startDate: selectedDate, endDate: selectedDate, apiClient: apiClient)
    }
    
    @MainActor
    func addWeek(apiClient: MealieAPIClient?) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            errorMessage = "Could not determine week interval."
            return
        }
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        prepareImport(startDate: weekInterval.start, endDate: endDate, apiClient: apiClient)
    }
    
    @MainActor
    func addRange() {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) ?? DateInterval(start: selectedDate, end: selectedDate)
        dateRangeStart = monthInterval.start
        dateRangeEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start
        
        importErrorMessage = nil
        isImporting = false
        importSuccess = false
        
        showingDateRangePicker = true
    }
    
    @MainActor
    func loadShoppingLists() async {
        guard let apiClient else {
            importErrorMessage = String(localized: "error.apiClientUnavailable")
            return
        }
        
        isLoadingShoppingLists = true
        importErrorMessage = nil
        
        do {
            let response = try await apiClient.fetchShoppingLists(page: 1, perPage: 500)
            self.availableShoppingLists = response.items
        } catch {
            self.importErrorMessage = "Failed to load shopping lists: \(error.localizedDescription)"
        }
        
        isLoadingShoppingLists = false
    }
    
    @MainActor
    func importMealsToShoppingList(list: ShoppingListSummary) async {
        guard let apiClient else {
            importErrorMessage = String(localized: "error.apiClientUnavailable")
            return
        }
        
        isImporting = true
        importingListId = list.id
        importErrorMessage = nil
        importSuccess = false
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateRangeStart)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: dateRangeEnd) ?? dateRangeEnd
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startOfDay)
        let endDateString = dateFormatter.string(from: endOfDay)
        
        do {
            let mealPlanResponse = try await apiClient.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString)
            let recipeIds = mealPlanResponse.items.compactMap { $0.recipeId }
            let uniqueRecipeIds = Array(Set(recipeIds))
            
            if !uniqueRecipeIds.isEmpty {
                _ = try await apiClient.addRecipesToShoppingListBulk(listId: list.id, recipeIds: uniqueRecipeIds)
                importSuccess = true
            } else {
                importErrorMessage = "No recipes found in the selected date range."
            }
            
        } catch {
            importErrorMessage = "Failed to import ingredients: \(error.localizedDescription)"
        }
        
        isImporting = false
        importingListId = nil
        if importSuccess {
            showingShoppingListSelection = false
        }
    }
}
