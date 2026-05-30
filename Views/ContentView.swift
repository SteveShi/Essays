import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState: AppState
    @State private var showComposeSheet = false
    @AppStorage("theme") private var theme = "system"
    #if os(iOS)
    @StateObject private var quickActionService = QuickActionService.shared
    #endif

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
        .onReceive(NotificationCenter.default.publisher(for: .syncCompleted)) { _ in
            appState.loadLocalCachedMemos()
        }
        #if os(iOS)
        .onChange(of: quickActionService.pendingAction) { _, action in
            guard let action = action else { return }
            handleQuickAction(action)
            quickActionService.clearPendingAction()
        }
        #endif
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
                #else
                .navigationTitle(String(localized: "Timeline", comment: "Navigation title for the main list view"))
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
        if appState.isLocalMode {
            return
        }

        appState.isLoading = true
        defer { appState.isLoading = false }

        do {


            MemosAPIClient.shared.configure(
                serverURL: appState.serverURL,
                accessToken: appState.accessToken,
                apiVersion: appState.activeAccount?.apiVersion ?? .v027
            )

            _ = try await MemosAPIClient.shared.fetchMemos()
        } catch {
            if error.isCancellationLike {
                return
            }
            appState.errorMessage = error.localizedDescription
        }
    }

    #if os(iOS)
    private func handleQuickAction(_ action: QuickActionService.QuickAction) {
        switch action {
        case .newMemo:
            showComposeSheet = true
        case .search:
            NotificationCenter.default.post(name: .focusSearch, object: nil)
        case .quickCapture:
            // Quick capture is already visible in MemoListView, just focus it
            // Could add additional logic here if needed
            break
        }
    }
    #endif
}
