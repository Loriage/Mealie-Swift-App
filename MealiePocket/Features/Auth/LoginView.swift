import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @Environment(AppState.self) private var appState

    enum LoginMode: String, CaseIterable, Identifiable {
        case password = "Password"
        case apiKey = "API Key"
        var id: String { self.rawValue }
    }
    
    @State private var selectedMode: LoginMode = .password

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Welcome to Pocket for Mealie")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom)

            Picker("Login Method", selection: $selectedMode) {
                ForEach(LoginMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom)

            VStack {
                HStack(spacing: 10) {
                    Picker("Scheme", selection: $viewModel.selectedScheme) {
                        ForEach(LoginViewModel.ServerScheme.allCases) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(height: 54)
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .tint(Color.primary)

                    TextField("mealie.domain.tld", text: $viewModel.serverAddress)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                }

                Group{
                    if selectedMode == .password {
                        TextField("Username", text: $viewModel.username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                    } else {
                        SecureField("API Key", text: $viewModel.apiKey)
                            .textContentType(.password)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)

                        Spacer().frame(height: 62)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(LocalizedStringKey(errorMessage))
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    Task {
                        await viewModel.performLogin(appState: appState, mode: selectedMode)
                    }
                }) {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .onChange(of: selectedMode) { _, _ in
             viewModel.errorMessage = nil
        }
    }
}
