import SwiftUI

struct ShoppingListDetailView: View {
    @State private var viewModel: ShoppingListDetailViewModel
    @Environment(AppState.self) private var appState
    @State private var localEditMode: EditMode = .inactive
    @Namespace var buttonNamespace
    
    init(listSummary: ShoppingListSummary) {
        _viewModel = State(initialValue: ShoppingListDetailViewModel(listSummary: listSummary))
    }
    
    private var hasUncheckedItems: Bool {
        viewModel.shoppingListDetail?.listItems.contains { !$0.checked } ?? false
    }
    
    private var hasCheckedItems: Bool {
        viewModel.shoppingListDetail?.listItems.contains { $0.checked } ?? false
    }
    
    var body: some View {
        List {
            Section {
                if viewModel.isLoadingImport {
                    ProgressView("Importing...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
            }
            
            if viewModel.isLoading && viewModel.shoppingListDetail?.listItems.isEmpty ?? true {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Section {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            
            if let detail = viewModel.shoppingListDetail {
                Section("Items") {
                    if detail.listItems.isEmpty && !viewModel.isLoading && !viewModel.isLoadingImport {
                        Text("No items in this list yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(detail.listItems) { item in
                            ShoppingListItemRow(item: item, viewModel: viewModel)
                        }
                        .onDelete { indexSet in
                            Task {
                                await viewModel.deleteItems(at: indexSet)
                            }
                        }
                    }
                }

                Section("Recipes") {
                    if (detail.recipeReferences?.isEmpty ?? true) && !viewModel.isLoading && !viewModel.isLoadingImport {
                        Text("No recipes in this list yet.")
                            .foregroundColor(.secondary)
                    } else {
                        
                        if let references = detail.recipeReferences, !references.isEmpty {
                            ForEach(references) { ref in
                                if let recipeName = viewModel.recipeNameMap[ref.recipeId] {
                                    HStack(spacing: 3) {
                                        Image(systemName: "book.closed")
                                        Text(recipeName)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if !viewModel.isLoading {
                Text("Could not load list details.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(viewModel.shoppingListDetail?.name ?? "Shopping List")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if localEditMode.isEditing {
                    Button("Done") {
                        localEditMode = .inactive
                    }
                } else {
                    Button("Edit") {
                        localEditMode = .active
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.importCurrentWeekIngredients() }
                    } label: {
                        Label("Import Current Week", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)
                    
                    Button {
                        Task { await viewModel.importNextWeekIngredients() }
                    } label: {
                        Label("Import Next Week", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)
                    
                    Button {
                        viewModel.showingDateRangePicker = true
                    } label: {
                        Label("Import Date Range", systemImage: "calendar")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .environment(\.editMode, $localEditMode)
        .sheet(isPresented: $viewModel.showingAddItemSheet) {
            AddShoppingItemView(viewModel: viewModel)
                .presentationDetents([.height(250)])
        }
        .sheet(isPresented: $viewModel.showingDateRangePicker) {
            DateRangePickerView(viewModel: viewModel)
                .presentationDetents([.height(250)])
        }
        .task {
            await viewModel.loadListDetails(apiClient: appState.apiClient)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.prepareAddItemSheet()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .padding()
                    .foregroundStyle(Color.white)
                    .glassEffect(.regular.tint(.accentColor).interactive())
                    .clipShape(Circle())
            }
            .disabled(viewModel.isLoading || viewModel.isLoadingImport)
            .padding(.trailing, 20)
            .padding(.bottom, 10)
        }
    }
}

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let viewModel: ShoppingListDetailViewModel
    @Environment(\.editMode) private var editMode
    @State private var isCheckedLocal: Bool

    init(item: ShoppingListItem, viewModel: ShoppingListDetailViewModel) {
        self.item = item
        self.viewModel = viewModel
        _isCheckedLocal = State(initialValue: item.checked)
    }

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: isCheckedLocal ? "checkmark.circle.fill" : "circle")
                 .foregroundColor(isCheckedLocal ? .green : .secondary)
                 .font(.title3)
                 .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4){
                Text(item.display ?? "Unknown Item")
                     .strikethrough(isCheckedLocal, color: .secondary)
                     .foregroundColor(isCheckedLocal ? .secondary : .primary)

                VStack(alignment: .leading, spacing: 4) {
                      if let references = item.recipeReferences, !references.isEmpty {
                           ForEach(references) { ref in
                                if let recipeName = viewModel.recipeNameMap[ref.recipeId] {
                                     HStack(spacing: 3) {
                                         Image(systemName: "book.closed")
                                         Text(recipeName)
                                             .lineLimit(1)
                                     }
                                }
                           }
                      }
                 }
                 .font(.caption)
                 .foregroundColor(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isCheckedLocal.toggle()
            hapticImpact()
            viewModel.updateItemCheckedState(itemId: item.id, isChecked: isCheckedLocal)
        }
        .opacity(editMode?.wrappedValue.isEditing == true ? 0.5 : 1.0)
        .onChange(of: item.checked) { _, newValue in
             if isCheckedLocal != newValue {
                 isCheckedLocal = newValue
             }
        }
    }

     @Environment(\.locale) private var locale

     private func formattedQuantity(_ quantity: Double) -> String {
         let formatter = NumberFormatter()
         formatter.minimumFractionDigits = 0
         formatter.maximumFractionDigits = 2
         formatter.locale = locale
         return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
     }
}
