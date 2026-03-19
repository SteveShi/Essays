import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var showComposeSheet = false
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
        @Bindable var appState = appState
        return NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView()
                #if os(macOS)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
                #endif
        } content: {
            MemoListView()
                #if os(macOS)
                .frame(minWidth: 320, idealWidth: 360)
                #endif
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                // iPhone: default to showing the list column (not sidebar)
                appState.columnVisibility = .doubleColumn
            }
            #endif
        }
        .task {
            await refreshMemos()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let memo = appState.selectedMemoForDetail {
            MemoDetailView(memo: memo)
                .id(memo.id)
        } else {
            ContentUnavailableView {
                Label(String(localized: "Select a Memo", comment: "Placeholder when no memo is selected"), systemImage: "note.text")
            } description: {
                Text(String(localized: "Choose a memo from the list to view its details.", comment: "Instructional text under the placeholder"))
            }
            #if os(iOS)
            .background(LiquidGlassTheme.colors.background)
            #endif
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
