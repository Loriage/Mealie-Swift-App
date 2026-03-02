import Foundation
import SwiftUI

@Observable
class ShoppingListDetailViewModel {
    var shoppingListDetail: ShoppingListDetail?
    var recipeNameMap: [UUID: String] = [:]
    var isLoading = false
    var isLoadingBulkUpdate = false
    var isLoadingImport = false
    var errorMessage: String?
    
    var showingAddItemSheet = false
    var newItemNote: String = ""
    var newItemQuantity: Double = 1.0
    
    var showingDateRangePicker = false
    var dateRangeStart = Date()
    var dateRangeEnd = Date()
    
    private let listSummary: ShoppingListSummary
    private var apiClient: MealieAPIClient?
    
    var hasUncheckedItems: Bool {
        shoppingListDetail?.listItems.contains { !$0.checked } ?? false
    }
    
    init(listSummary: ShoppingListSummary) {
        self.listSummary = listSummary
        self.shoppingListDetail = ShoppingListDetail(
            id: listSummary.id,
            name: listSummary.name,
            createdAt: listSummary.createdAt,
            updatedAt: listSummary.updatedAt,
            groupId: listSummary.groupId,
            userId: listSummary.userId,
            householdId: listSummary.householdId,
            listItems: [],
            recipeReferences: []
        )
        
        if let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) {
            self.dateRangeStart = weekInterval.start
            self.dateRangeEnd = weekInterval.end > weekInterval.start ? Calendar.current.date(byAdding: .day, value: -1, to: weekInterval.end)! : weekInterval.start
        }
    }
    
    @MainActor
    func loadListDetails(apiClient: MealieAPIClient?) async {
        self.apiClient = apiClient
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }
        guard shoppingListDetail != nil else {
            errorMessage = "error.listNotInitialized"
            return
        }
        
        if !isLoadingImport {
            isLoading = true
        }
        errorMessage = nil
        recipeNameMap = [:]
        
        do {
            let fullDetails = try await apiClient.fetchShoppingListDetail(listId: listSummary.id)
            var items = fullDetails.listItems
            items.sort { !$0.checked && $1.checked }
            
            var nameMap: [UUID: String] = [:]
            if let topLevelRefs = fullDetails.recipeReferences {
                for ref in topLevelRefs {
                    if let recipe = ref.recipe {
                        nameMap[ref.recipeId] = recipe.name
                    }
                }
            }
            self.recipeNameMap = nameMap
            
            self.shoppingListDetail = ShoppingListDetail(
                id: fullDetails.id,
                name: fullDetails.name,
                createdAt: fullDetails.createdAt,
                updatedAt: fullDetails.updatedAt,
                groupId: fullDetails.groupId,
                userId: fullDetails.userId,
                householdId: fullDetails.householdId,
                listItems: items,
                recipeReferences: fullDetails.recipeReferences
            )
            
            
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "error.loadingListDetails"
        }
        
        isLoading = false
        isLoadingImport = false
    }
    
    @MainActor
    func addItem() async {
        guard let apiClient, let listId = shoppingListDetail?.id else {
            errorMessage = "error.cannotAddItem"
            return
        }
        guard !newItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "error.itemNameEmpty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.addShoppingListItem(listId: listId, note: newItemNote, quantity: newItemQuantity)
            if let newItem = response.createdItems?.first {
                if shoppingListDetail != nil {
                    var currentItems = shoppingListDetail!.listItems
                    currentItems.insert(newItem, at: 0)
                    currentItems.sort { !$0.checked && $1.checked }
                    shoppingListDetail!.listItems = currentItems
                    
                }
            }
            showingAddItemSheet = false
            resetNewItemFields()
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "error.addingItem"
        }
        isLoading = false
    }
    
    @MainActor
    func updateItemCheckedState(itemId: UUID, isChecked: Bool) {
        guard shoppingListDetail != nil,
              let index = shoppingListDetail!.listItems.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        
        if shoppingListDetail!.listItems[index].checked != isChecked {
            var updatedItems = shoppingListDetail!.listItems
            updatedItems[index].checked = isChecked
            updatedItems.sort { !$0.checked && $1.checked }
            shoppingListDetail!.listItems = updatedItems
            
            let itemToSend = updatedItems.first { $0.id == itemId } ?? updatedItems[index]
            
            
            Task {
                await updateItem(itemToSend)
            }
        }
    }
    
    @MainActor
    func updateItem(_ item: ShoppingListItem) async {
        guard let apiClient else {
            errorMessage = "error.cannotUpdateItem"
            return
        }
        errorMessage = nil
        
        var itemToSend = item
        itemToSend.quantity = nil
        
        do {
            _ = try await apiClient.updateShoppingListItem(item: itemToSend)
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "error.updatingItem"
        }
    }
    
    @MainActor
    func importMealPlanIngredients(startDate: Date, endDate: Date) async {
        guard let apiClient, let listId = shoppingListDetail?.id else {
            errorMessage = "error.cannotImport"
            return
        }
        
        isLoadingImport = true
        errorMessage = nil
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        
        
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startOfDay)
        let endDateString = dateFormatter.string(from: endOfDay)
        
        do {
            let mealPlanResponse = try await apiClient.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString)
            let recipeIds = mealPlanResponse.items.compactMap { $0.recipeId }
            let uniqueRecipeIds = Array(Set(recipeIds))
            
            if !uniqueRecipeIds.isEmpty {
                _ = try await apiClient.addRecipesToShoppingListBulk(listId: listId, recipeIds: uniqueRecipeIds)
                
                await loadListDetails(apiClient: apiClient)
            } else {
                
                isLoadingImport = false
            }
            
        } catch APIError.unauthorized {
            isLoadingImport = false
        } catch {
            errorMessage = "error.importingIngredients"
            isLoadingImport = false
        }
        
        
    }
    
    @MainActor
    func importCurrentWeekIngredients() async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            errorMessage = "error.weekIntervalUnavailable"
            return
        }
        let startDate = weekInterval.start
        
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        
        await importMealPlanIngredients(startDate: startDate, endDate: endDate)
    }

    @MainActor
    func importNextWeekIngredients() async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: (Date() + (3600 * 24 * 8))) else {
            errorMessage = "error.weekIntervalUnavailable"
            return
        }
        let startDate = weekInterval.start
        
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        
        await importMealPlanIngredients(startDate: startDate, endDate: endDate)
    }
    
    @MainActor
    func deleteItems(at offsets: IndexSet) async {
        guard let apiClient, let items = shoppingListDetail?.listItems else {
            errorMessage = "error.cannotDeleteItems"
            return
        }
        
        let itemsToDelete = offsets.map { items[$0] }
        let originalIndices = offsets.map { $0 }
        
        shoppingListDetail?.listItems.remove(atOffsets: offsets)
        
        for (idx, item) in itemsToDelete.enumerated() {
            errorMessage = nil
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                if shoppingListDetail != nil {
                    let originalIndex = originalIndices[idx]
                    let insertPos = min(originalIndex, shoppingListDetail!.listItems.count)
                    shoppingListDetail!.listItems.insert(item, at: insertPos)
                }
                break
            } catch {
                errorMessage = "error.deletingItem"
                if shoppingListDetail != nil {
                    let originalIndex = originalIndices[idx]
                    let insertPos = min(originalIndex, shoppingListDetail!.listItems.count)
                    shoppingListDetail!.listItems.insert(item, at: insertPos)
                }
                break
            }
        }
    }
    
    @MainActor
    func prepareAddItemSheet() {
        resetNewItemFields()
        showingAddItemSheet = true
    }
    
    @MainActor
    func resetNewItemFields() {
        newItemNote = ""
        newItemQuantity = 1.0
        errorMessage = nil
    }
    
    
    var displayCreatedAt: String? {
        formatDateString(shoppingListDetail?.createdAt)
    }
    var displayUpdatedAt: String? {
        formatDateString(shoppingListDetail?.updatedAt)
    }
    
    private func formatDateString(_ dateString: String?) -> String? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        return dateString
    }
}
