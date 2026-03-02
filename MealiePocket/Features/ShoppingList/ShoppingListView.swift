import SwiftUI

struct ShoppingListView: View {
    @State private var viewModel = ShoppingListViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.shoppingLists) { list in
                    NavigationLink(value: list) {
                        ShoppingListRow(list: list)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                if let index = viewModel.shoppingLists.firstIndex(where: { $0.id == list.id }) {
                                    await viewModel.deleteShoppingList(at: IndexSet(integer: index), apiClient: appState.apiClient)
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.prepareEditSheet(list: list)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .id(viewModel.listVersion)
                
                if viewModel.canLoadMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            Task {
                                await viewModel.loadShoppingLists(apiClient: appState.apiClient, loadMore: true)
                            }
                        }
                }
                if let errorMessage = viewModel.errorMessage, !viewModel.shoppingLists.isEmpty {
                    Text(LocalizedStringKey(errorMessage))
                        .foregroundColor(.red)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Shopping Lists")
            .overlay {
                if viewModel.isLoading && viewModel.shoppingLists.isEmpty {
                    ProgressView()
                } else if viewModel.shoppingLists.isEmpty {
                    ContentUnavailableView(
                        "No Shopping Lists",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Create your first shopping list.")
                    )
                } else if let errorMessage = viewModel.errorMessage, viewModel.shoppingLists.isEmpty {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(LocalizedStringKey(errorMessage))
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.prepareCreateSheet()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadShoppingLists(apiClient: appState.apiClient)
            }
            .task {
                if viewModel.shoppingLists.isEmpty {
                    await viewModel.loadShoppingLists(apiClient: appState.apiClient)
                }
            }
            .sheet(isPresented: $viewModel.showingCreateSheet) {
                EditShoppingListView(viewModel: viewModel)
                    .presentationDetents([.height(180)])
            }
            .navigationDestination(for: ShoppingListSummary.self) { listSummary in
                ShoppingListDetailView(listSummary: listSummary)
            }
        }
    }
}

struct ShoppingListRow: View {
    let list: ShoppingListSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name ?? "Untitled List")
                .font(.headline)
            HStack {
                if let dateString = list.displayUpdatedAt {
                    Text("Updated \(dateString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let dateString = list.displayCreatedAt {
                    Text("Created \(dateString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditShoppingListView: View {
    @Bindable var viewModel: ShoppingListViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(viewModel.listToEdit == nil ? "Create a new list" : "Edit list name") {
                    TextField("List Name", text: $viewModel.nameForNewOrEditList)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(LocalizedStringKey(errorMessage))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(viewModel.listToEdit == nil ? "New List" : "Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.resetAndDismissSheet()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await viewModel.createOrUpdateShoppingList(apiClient: appState.apiClient)
                                
                            }
                        }
                    }
                }
            }
        }
    }
}
