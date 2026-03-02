import Foundation

@Observable
class ReportsListViewModel {
    var reports: [ReportSummary] = []
    var isLoading = false
    var errorMessage: String?

    var selectedCategory: ReportCategory? = nil
    
    @MainActor
    func loadReports(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let category = selectedCategory {
                self.reports = try await apiClient.fetchReports(type: category)
            } else {
                self.reports = try await fetchAllReportsMerged(apiClient: apiClient)
            }
        } catch {
            errorMessage = "error.loadingReports"
        }
        
        isLoading = false
    }

    private func fetchAllReportsMerged(apiClient: MealieAPIClient) async throws -> [ReportSummary] {
        var allReports: [ReportSummary] = []
        
        try await withThrowingTaskGroup(of: [ReportSummary].self) { group in
            for category in ReportCategory.allCases {
                group.addTask {
                    try await apiClient.fetchReports(type: category)
                }
            }
            
            for try await categoryReports in group {
                allReports.append(contentsOf: categoryReports)
            }
        }
        return allReports.sorted { $0.timestamp > $1.timestamp }
    }
}
