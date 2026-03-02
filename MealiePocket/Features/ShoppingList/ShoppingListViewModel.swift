import Foundation
import SwiftUI

@Observable
class ShoppingListViewModel {
    var shoppingLists: [ShoppingListSummary] = []
    var isLoading = false
    var errorMessage: String?
    var listVersion = UUID()
    
    var showingCreateSheet = false
    var listToEdit: ShoppingListSummary? = nil
    var nameForNewOrEditList: String = ""
    
    private var currentPage = 1
    private var totalPages = 1
    var canLoadMore: Bool { currentPage < totalPages }
    var isLoadingMore = false
    
    @MainActor
    func loadShoppingLists(apiClient: MealieAPIClient?, loadMore: Bool = false) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }
        
        if loadMore {
            guard !isLoadingMore && canLoadMore else { return }
            isLoadingMore = true
        } else {
            isLoading = true
            currentPage = 1
        }
        errorMessage = nil
        
        let pageToLoad = loadMore ? currentPage + 1 : 1
        
        do {
            let response = try await apiClient.fetchShoppingLists(page: pageToLoad)
            
            if loadMore {
                var currentLists = shoppingLists
                currentLists.append(contentsOf: response.items)
                shoppingLists = currentLists
            } else {
                shoppingLists = response.items
            }
            currentPage = response.page
            totalPages = response.totalPages
            listVersion = UUID()
            
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "error.loadingShoppingLists"
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    @MainActor
    func createOrUpdateShoppingList(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        let nameToSave = nameForNewOrEditList.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = nameToSave.isEmpty ? nil : nameToSave
        let isUpdating = listToEdit != nil
        
        do {
            if let listToEdit = listToEdit {
                _ = try await apiClient.updateShoppingList(list: listToEdit, name: finalName)
                await loadShoppingLists(apiClient: apiClient, loadMore: false)
                
            } else {
                let newListDetail = try await apiClient.createShoppingList(name: finalName)
                let newListSummary = ShoppingListSummary(
                    id: newListDetail.id,
                    name: newListDetail.name,
                    createdAt: newListDetail.createdAt,
                    updatedAt: newListDetail.updatedAt,
                    groupId: newListDetail.groupId,
                    userId: newListDetail.userId,
                    householdId: newListDetail.householdId
                )
                
                var newShoppingLists = shoppingLists
                newShoppingLists.insert(newListSummary, at: 0)
                shoppingLists = newShoppingLists
                listVersion = UUID()
            }
            resetAndDismissSheet()
        } catch APIError.unauthorized {
            errorMessage = "error.unauthorized"
        } catch {
            errorMessage = isUpdating ? "error.updatingList" : "error.creatingList"
        }
        isLoading = false
    }
    
    
    @MainActor
    func deleteShoppingList(at offsets: IndexSet, apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }
        
        var listsToDelete: [ShoppingListSummary] = []
        let originalIndices = offsets.map { $0 }
        
        var tempShoppingLists = shoppingLists
        
        for index in offsets {
            listsToDelete.append(tempShoppingLists[index])
        }
        
        tempShoppingLists.remove(atOffsets: offsets)
        shoppingLists = tempShoppingLists
        
        
        for (index, list) in listsToDelete.enumerated() {
            do {
                try await apiClient.deleteShoppingList(listId: list.id)
                
            } catch {
                errorMessage = "error.deletingList"
                
                
                let originalIndex = originalIndices[index]
                var currentLists = shoppingLists
                let insertPos = min(originalIndex, currentLists.count)
                currentLists.insert(list, at: insertPos)
                shoppingLists = currentLists
                
                break
            }
        }
    }
    
    
    @MainActor
    func prepareCreateSheet() {
        listToEdit = nil
        nameForNewOrEditList = ""
        showingCreateSheet = true
    }
    
    @MainActor
    func prepareEditSheet(list: ShoppingListSummary) {
        listToEdit = list
        nameForNewOrEditList = list.name ?? ""
        showingCreateSheet = true
    }
    
    @MainActor
    func resetAndDismissSheet() {
        showingCreateSheet = false
        listToEdit = nil
        nameForNewOrEditList = ""
        errorMessage = nil
    }
}
