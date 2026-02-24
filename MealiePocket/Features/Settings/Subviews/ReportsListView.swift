import SwiftUI

struct ReportsListView: View {
    @State private var viewModel = ReportsListViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if viewModel.reports.isEmpty {
                ContentUnavailableView(
                    "No Reports",
                    systemImage: "text.book.closed",
                    description: Text(viewModel.selectedCategory == nil ? "No reports found on the server." : "No reports found for this category.")
                )
            } else {
                List(viewModel.reports) { report in
                    NavigationLink(destination: ReportDetailView(viewModel: ReportDetailViewModel(reportSummary: report))) {
                        ReportRowView(report: report)
                    }
                }
                .refreshable {
                    await viewModel.loadReports(apiClient: appState.apiClient)
                }
            }
        }
        .navigationTitle("Server Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $viewModel.selectedCategory) {
                        Text("All").tag(nil as ReportCategory?)
                        
                        ForEach(ReportCategory.allCases) { category in
                            Text(category.displayName).tag(category as ReportCategory?)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.selectedCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .task {
            await viewModel.loadReports(apiClient: appState.apiClient)
        }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            Task {
                await viewModel.loadReports(apiClient: appState.apiClient)
            }
        }
    }
}

struct ReportRowView: View {
    let report: ReportSummary
    @Environment(\.locale) private var locale
    
    var body: some View {
        HStack {
            Image(systemName: iconForStatus(report.status))
                .font(.title2)
                .foregroundStyle(colorForStatus(report.status))

            Text(report.name)
                .font(.headline)

            Spacer()
            
            Text(formattedDate(report.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    func iconForStatus(_ status: ReportSummaryStatus) -> String {
        switch status {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .partial: "exclamationmark.triangle.fill"
        case .inProgress: "hourglass"
        }
    }
    
    func colorForStatus(_ status: ReportSummaryStatus) -> Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .partial: .orange
        case .inProgress: .blue
        }
    }
    
    func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date.formatted(Date.FormatStyle(date: .numeric, time: .shortened, locale: locale))
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return date.formatted(Date.FormatStyle(date: .numeric, time: .shortened, locale: locale))
        }
        return "Invalid Date"
    }
}
