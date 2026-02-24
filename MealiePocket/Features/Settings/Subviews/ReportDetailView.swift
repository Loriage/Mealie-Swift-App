import SwiftUI

struct ReportDetailView: View {
    @State var viewModel: ReportDetailViewModel
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let _ = viewModel.reportDetail {
                if viewModel.filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("No logs match the '\(viewModel.selectedFilter.rawValue)' filter.")
                    )
                } else {
                    List(viewModel.filteredEntries) { entry in
                        LogEntryView(entry: entry)
                    }
                }
            } else {
                ContentUnavailableView("No Data", systemImage: "doc.text", description: Text("Could not load report data."))
            }
        }
        .navigationTitle(viewModel.reportSummary.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(ReportDetailViewModel.FilterOption.allCases) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: viewModel.selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .task {
            await viewModel.loadReportDetail(apiClient: appState.apiClient)
        }
    }
}

struct LogEntryView: View {
    let entry: ReportEntryOut
    @Environment(\.locale) private var locale
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.body)
                
                Text(formattedDate(entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                if let exception = entry.exception, !exception.isEmpty {
                    Text(exception)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
