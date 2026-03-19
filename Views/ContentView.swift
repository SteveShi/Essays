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
                #if os(macOS)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
                #endif
        } content: {
            MemoListView()
                #if os(macOS)
                .frame(minWidth: 320, idealWidth: 360)
                #else
                .navigationTitle(String(localized: "Timeline", comment: "Navigation title for the main list view"))
                .navigationDestination(for: Memo.self) { memo in
                    MemoDetailView(memo: memo)
                }
                .navigationDestination(for: AppState.SidebarSelection.self) { selection in
                    // In a 3-column split view, selecting from sidebar usually 
                    // updates the content column. NavigationStack handles the push on iPhone.
                    MemoListView()
                }
                #endif
        } detail: {
            ZStack {
                if let memo = appState.selectedMemoForDetail {
                    MemoDetailView(memo: memo)
                        .id(memo.id) // Ensure view refreshes for different memos
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
            #if os(iOS)
            .navigationStack() // Using the same approach as ios-port if applicable, or wrapping
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                columnVisibility = .all
            }
            #endif
        }
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
