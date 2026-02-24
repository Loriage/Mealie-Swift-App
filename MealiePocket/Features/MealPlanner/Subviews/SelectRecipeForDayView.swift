import SwiftUI

struct SelectRecipeForDayView: View {
    @Bindable var viewModel: MealPlannerViewModel
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
                ForEach(viewModel.recipesForSelection) { recipe in
                    RecipeSelectionRow(recipe: recipe)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.selectedRecipe = recipe
                            self.showingMealTypeSelection = true
                        }
                        .listSectionSeparator(.hidden, edges: .top)
                }
                if viewModel.canLoadMoreForSelection && !viewModel.recipesForSelection.isEmpty {
                    Section {
                        if viewModel.isLoadingMoreRecipesForSelection {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 50)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreRecipesForSelection(apiClient: apiClient)
                                    }
                                }
                        }
                    }
                }
                if viewModel.isLoadingRecipesForSelection && viewModel.recipesForSelection.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchQueryForSelection, prompt: "Search for a recipe...")
            .navigationTitle("Add to \(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale)))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
                    onCancel: {
                        showingMealTypeSelection = false
                    }
                )
                .presentationDetents([.height(200)])
            }
        }
        .onChange(of: viewModel.searchQueryForSelection) { _, _ in
            Task { await viewModel.searchRecipesForSelection(apiClient: apiClient, loadMore: false) }
        }
        .task {
            if viewModel.recipesForSelection.isEmpty && viewModel.searchQueryForSelection.isEmpty && !viewModel.isLoadingRecipesForSelection {
                await viewModel.searchRecipesForSelection(apiClient: apiClient, loadMore: false)
            }
        }
    }
}

struct RecipeSelectionRow: View {
    let recipe: RecipeSummary
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(
                url: .makeImageURL(
                    baseURL: appState.apiClient?.baseURL,
                    recipeID: recipe.id,
                    imageName: "min-original.webp"
                )
            )
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(2)
                if let time = recipe.totalTime, !time.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(time)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct MealTypeSelectionView: View {
    @Binding var selectedMealType: String
    let mealTypes: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(mealTypes, id: \.self) { type in
                        Text(LocalizedStringKey(type)).tag(type)
                    }
                }
                .pickerStyle(.wheel)
                
                Spacer()
            }
            .navigationTitle("Select meal type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add", action: onConfirm)
                }
            }
        }
    }
}
