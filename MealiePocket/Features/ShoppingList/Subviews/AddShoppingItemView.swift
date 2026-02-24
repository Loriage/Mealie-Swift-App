import SwiftUI

struct AddShoppingItemView: View {
    @Bindable var viewModel: ShoppingListDetailViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationView {
            Form {
                Section("New Item") {
                    TextField("Name or Note", text: $viewModel.newItemNote)
                    Stepper("Quantity: \(formattedQuantity(viewModel.newItemQuantity))", value: $viewModel.newItemQuantity, in: 0.1...100, step: 0.1)
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        viewModel.resetNewItemFields()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                await viewModel.addItem()
                            }
                        }
                        .disabled(viewModel.newItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func formattedQuantity(_ quantity: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
    }
}
