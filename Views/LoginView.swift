import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) var appState
    @State private var serverURL: String = ""
    @State private var accessToken: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                headerView
                
                loginForm
            }
            .padding(40)
            .frame(maxWidth: 480)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.05),
                    Color.clear,
                    Color.accentColor.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            serverURL = appState.serverURL
            accessToken = appState.accessToken
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(String(localized: "Essays", comment: "Application name"))
                .font(LiquidGlassTheme.typography.largeTitle)
                .foregroundColor(LiquidGlassTheme.colors.text)
            
            Text(String(localized: "Connect to your Memos server", comment: "Subtitle for login screen"))
                .font(LiquidGlassTheme.typography.subheadline)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
        }
    }
    
    private var loginForm: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Server URL", comment: "Label for server URL field"))
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)
                
                TextField(
                    String(
                        localized: "https://your-memos-server.com",
                        comment: "Placeholder for server URL field"), text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .font(LiquidGlassTheme.typography.body)
                    .autocorrectionDisabled()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Access Token", comment: "Label for access token field"))
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)
                
                SecureField(String(localized: "Access Token", comment: "Placeholder for access token field"), text: $accessToken)
                    .textFieldStyle(.roundedBorder)
                    .font(LiquidGlassTheme.typography.body)
                    .onSubmit {
                        Task {
                            await signIn()
                        }
                    }
            }
            Text(String(localized: "Use personal access token for API authentication", comment: "Help text for access token"))
                .font(LiquidGlassTheme.typography.footnote)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(LiquidGlassTheme.colors.error)
                    
                    Text(error)
                        .font(LiquidGlassTheme.typography.callout)
                        .foregroundColor(LiquidGlassTheme.colors.error)
                }
                .padding(.top, 8)
            }
            
            Button {
                Task {
                    await signIn()
                }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    
                    Text(isLoading ? String(localized: "Signing in...", comment: "Button state during login") : String(localized: "Sign In", comment: "Button text to start login"))
                        .font(LiquidGlassTheme.typography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSignIn)
            .padding(.top, 8)
        }
    }

    private var canSignIn: Bool {
        let normalizedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isLoading, !normalizedServerURL.isEmpty else {
            return false
        }

        return !normalizedAccessToken.isEmpty
    }
    
    private func signIn() async {
        let normalizedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedServerURL.isEmpty else {
            errorMessage = String(localized: "Server URL is required")
            return
        }
        
        guard !normalizedAccessToken.isEmpty else {
            errorMessage = String(localized: "Access token is required")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            MemosAPIClient.shared.configure(
                serverURL: normalizedServerURL, accessToken: normalizedAccessToken)
            let user = try await MemosAPIClient.shared.getCurrentUser()

            appState.serverURL = normalizedServerURL
            appState.accessToken = normalizedAccessToken
            appState.currentUser = user
            appState.isLoggedIn = true
            appState.saveCredentials()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
