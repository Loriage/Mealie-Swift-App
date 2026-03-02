import Foundation
import SwiftUI

@Observable
class LoginViewModel {
    
    enum ServerScheme: String, CaseIterable, Identifiable {
        case http = "http://"
        case https = "https://"
        
        var id: String { self.rawValue }
    }
    
    var selectedScheme: ServerScheme = .https
    var serverAddress = ""
    var username = ""
    var password = ""
    var apiKey = ""
    var isLoading = false
    var errorMessage: String?
    
    func performLogin(appState: AppState, mode: LoginView.LoginMode) async {
        isLoading = true
        errorMessage = nil
        
        let fullURLString = selectedScheme.rawValue + serverAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        
        guard let url = URL(string: fullURLString), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            errorMessage = "error.login.invalidURL"
            isLoading = false
            return
        }

        components.path = ""
        guard let baseURL = components.url else {
            errorMessage = "error.login.cannotConstructURL"
            isLoading = false
            return
        }

        switch mode {
        case .password:
            guard !username.isEmpty, !password.isEmpty else {
                errorMessage = "error.login.credentialsRequired"
                isLoading = false
                return
            }
            let client = MealieAPIClient(baseURL: baseURL)
            do {
                let token = try await client.login(username: username, password: password)
                await appState.login(baseURL: baseURL, token: token)
            } catch {
                errorMessage = "error.login.failed"
            }

        case .apiKey:
            guard !apiKey.isEmpty else {
                errorMessage = "error.login.apiKeyRequired"
                isLoading = false
                return
            }
            await appState.loginWithApiKey(baseURL: baseURL, apiKey: apiKey)

            if !appState.isAuthenticated {
                errorMessage = "error.login.apiKeyFailed"
            }
        }
        
        if errorMessage != nil {
            isLoading = false
        }
    }
}
