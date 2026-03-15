import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var showComposeSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("theme") private var theme = "system"

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
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .createNewMemo)) { _ in
            showComposeSheet = true
        }
        .environment(appState)
        .sheet(isPresented: $showComposeSheet) {
            ComposeMemoView()
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
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
        } detail: {
            if let memo = appState.selectedMemoForDetail {
                MemoDetailView(memo: memo)
                    .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
            } else {
                MemoListView()
                    .transition(AnyTransition.move(edge: .leading).combined(with: .opacity))
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await refreshMemos()
        }
    }

    @MainActor
    private func refreshMemos() async {
        appState.isLoading = true
        defer { appState.isLoading = false }

        do {
            MemosAPIClient.shared.configure(
                serverURL: appState.serverURL,
                accessToken: appState.accessToken
            )

            let fetchedMemos = try await MemosAPIClient.shared.fetchMemos()
            let fetchedTags = try await MemosAPIClient.shared.fetchTags()

            appState.memos = fetchedMemos
            appState.tags = fetchedTags
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}
