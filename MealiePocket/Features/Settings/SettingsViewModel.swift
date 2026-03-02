import Foundation

@Observable
class SettingsViewModel {
    var appInfo: AppInfo?
    var householdStats: HouseholdStatistics?
    var isLoading = false
    var errorMessage: String?
    
    var isCleaning = false
    var isCreatingBackup = false
    var maintenanceMessage: String?
    
    @MainActor
    func loadInfo(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "error.apiClientUnavailable"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let appInfoTask = apiClient.fetchAppInfo()
            async let statsTask = apiClient.fetchHouseholdStatistics()

            self.appInfo = try await appInfoTask
            self.householdStats = try await statsTask

        } catch {
            errorMessage = "error.loadingSettings"
        }

        isLoading = false
    }

    @MainActor
    func createBackup(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = NSLocalizedString("error.apiClientUnavailable", bundle: AppLocale.bundle, comment: "")
            return
        }
        isCreatingBackup = true
        maintenanceMessage = nil

        do {
            let response = try await apiClient.createBackup()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = NSLocalizedString("error.maintenanceBackup", bundle: AppLocale.bundle, comment: "")
        }
        isCreatingBackup = false
    }

    @MainActor
    func runCleanImages(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = NSLocalizedString("error.apiClientUnavailable", bundle: AppLocale.bundle, comment: "")
            return
        }
        isCleaning = true
        maintenanceMessage = nil

        do {
            let response = try await apiClient.cleanImages()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = NSLocalizedString("error.maintenanceImages", bundle: AppLocale.bundle, comment: "")
        }
        isCleaning = false
    }

    @MainActor
    func runCleanTemp(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = NSLocalizedString("error.apiClientUnavailable", bundle: AppLocale.bundle, comment: "")
            return
        }
        isCleaning = true
        maintenanceMessage = nil

        do {
            let response = try await apiClient.cleanTempFiles()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = NSLocalizedString("error.maintenanceTemp", bundle: AppLocale.bundle, comment: "")
        }
        isCleaning = false
    }
}
