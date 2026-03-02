import Foundation

@Observable
class ReportDetailViewModel {
    var reportDetail: ReportOut?
    var isLoading = false
    var errorMessage: String?

    let reportSummary: ReportSummary

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case success = "Success"
        case failure = "Failure"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .success: return "checkmark.circle"
            case .failure: return "xmark.circle"
            }
        }
    }

    var selectedFilter: FilterOption = .all
    
    init(reportSummary: ReportSummary) {
        self.reportSummary = reportSummary
    }

    var filteredEntries: [ReportEntryOut] {
        guard let entries = reportDetail?.entries else { return [] }
        
        switch selectedFilter {
        case .all:
            return entries
        case .success:
            return entries.filter { $0.success }
        case .failure:
            return entries.filter { !$0.success }
        }
    }
    
    @MainActor
    func loadReportDetail(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            self.reportDetail = try await apiClient.fetchReportDetail(id: reportSummary.id)
        } catch {
            errorMessage = "error.loadingReportDetails"
        }
        
        isLoading = false
    }
}
