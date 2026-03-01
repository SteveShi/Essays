import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var showComposeSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("theme") private var theme = "system"
    @Environment(\.openSettings) private var openSettings

    private var preferredColorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if appState.isLoggedIn {
                mainView
            } else {
                LoginView()
                    .environment(appState)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .createNewMemo)) { _ in
            showComposeSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openSettings()
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposeMemoView()
                .environment(appState)
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { shouldShow in
                    if !shouldShow {
                        appState.errorMessage = nil
                    }
                }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var mainView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .environment(appState)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
        } detail: {
            MemoListView()
                .environment(appState)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await refreshMemos()
        }
    }

    private func refreshMemos() async {
        appState.isLoading = true
        defer { appState.isLoading = false }

        do {
            MemosAPIClient.shared.configure(
                serverURL: appState.serverURL,
                accessToken: appState.accessToken
            )

            async let memos = try await MemosAPIClient.shared.fetchMemos()
            async let tags = try await MemosAPIClient.shared.fetchTags()

            appState.memos = try await memos
            appState.tags = try await tags
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}
