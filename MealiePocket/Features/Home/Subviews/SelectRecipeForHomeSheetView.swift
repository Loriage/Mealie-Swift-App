import SwiftUI

struct SelectRecipeForHomeSheetView: View {
    @Bindable var viewModel: HomeViewModel
    let date: Date
    var apiClient: MealieAPIClient?

    @State private var selectedRecipe: RecipeSummary? = nil
    @State private var showingMealTypeSelection = false
    @State private var selectedMealType = "Dinner"
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Side"]

    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(viewModel.recipesForSelection) { recipe in
                        RecipeSelectionRow(recipe: recipe)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                self.selectedRecipe = recipe
                                self.showingMealTypeSelection = true
                            }
                    }
                }

                if viewModel.canLoadMoreForSelection && !viewModel.recipesForSelection.isEmpty {
                    Section {
                        if viewModel.isLoadingMoreRecipesForSelection { ProgressView().frame(maxWidth: .infinity) }
                        else {
                            Rectangle().fill(Color.clear).frame(height: 50)
                                .onAppear { Task { await viewModel.loadMoreRecipesForSelection(apiClient: apiClient) } }
                        }
                    }
                }

                if viewModel.isLoadingRecipesForSelection && viewModel.recipesForSelection.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchQueryForSelection, prompt: "Search for a recipe...")
            .navigationTitle("Add to \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale)))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showingMealTypeSelection) {
                 MealTypeSelectionView(
                     selectedMealType: $selectedMealType,
                     mealTypes: mealTypes,
                     onConfirm: {
                         if let recipe = selectedRecipe {
                             Task {
                                 await viewModel.addSelectedRecipeToPlan(recipe: recipe, mealType: selectedMealType, apiClient: apiClient)
                             }
                         }
                         showingMealTypeSelection = false
                     },
                     onCancel: { showingMealTypeSelection = false }
                 )
                 .presentationDetents([.height(200)])
            }
        }
    }
}
