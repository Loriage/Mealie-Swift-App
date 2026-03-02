import SwiftUI

struct DateRangePickerView: View {
    @Bindable var viewModel: ShoppingListDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select dates to import") {
                    DatePicker("Start Date", selection: $viewModel.dateRangeStart, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.dateRangeEnd, in: viewModel.dateRangeStart..., displayedComponents: .date)
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(LocalizedStringKey(errorMessage)).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoadingImport {
                        ProgressView()
                    } else {
                        Button("Import") {
                            Task {
                                await viewModel.importMealPlanIngredients(startDate: viewModel.dateRangeStart, endDate: viewModel.dateRangeEnd)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
