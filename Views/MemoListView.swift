import SwiftUI

struct MemoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showComposeSheet = false
    @State private var memoToEdit: Memo?
    @State private var showAIAssistant = false

    @State private var quickCaptureText: String = ""
    @State private var quickCaptureVisibility: MemoVisibility = .private
    @State private var isQuickCaptureSaving = false
    @AppStorage("enableAIFeatures") private var enableAIFeatures = true

    private var timelineGroups: [(date: Date, memos: [Memo])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: appState.unpinnedMemos) { memo in
            calendar.startOfDay(for: memo.createdAt)
        }

        return grouped
            .map { (date: $0.key, memos: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed Quick Capture Box
            VStack(spacing: 0) {
                quickCaptureView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                
                Divider()
                    .opacity(0.3)
            }
            .background(.ultraThinMaterial)
            .zIndex(1)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if appState.filteredMemos.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        if !appState.pinnedMemos.isEmpty {
                            pinnedSection
                        }

                        if !timelineGroups.isEmpty {
                            memosSection
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(String(localized: "Timeline", comment: "Navigation title for the main list view"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if enableAIFeatures {
                        Button {
                            showAIAssistant.toggle()
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.linearGradient(
                                    colors: [.purple, .blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        }
                        .help(String(localized: "AI Assistant", comment: "Help text for AI assistant button"))
                        .popover(isPresented: $showAIAssistant) {
                            if let memo = appState.selectedMemo ?? appState.filteredMemos.first {
                                AIAssistantView(memo: memo)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text(String(localized: "No memo selected", comment: "AI assistant empty state"))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 200, height: 100)
                            }
                        }
                    }

                    Button {
                        Task {
                            await refreshMemos()
                        }
                    } label: {
                        Group {
                            if appState.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .disabled(appState.isLoading)
                    .help(String(localized: "Refresh", comment: "Help text for refresh button"))

                    Button {
                        showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help(String(localized: "Compose (⌘N)", comment: "Help text for compose button"))
                }
            }
        }
        .background(LiquidGlassTheme.colors.background)
        .sheet(item: $memoToEdit) { memo in
            ComposeMemoView(editingMemo: memo)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposeMemoView()
                .environmentObject(appState)
        }
    }

    private var quickCaptureView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Quick Capture", comment: "Label for quick capture box"))
                .font(LiquidGlassTheme.typography.callout)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)

            VStack(spacing: 10) {
                TextField(String(localized: "Write a thought, press ⌘↩ to save...", comment: "Placeholder for quick capture text field"), text: $quickCaptureText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .font(LiquidGlassTheme.typography.body)

                HStack(spacing: 10) {
                    Menu {
                        ForEach(MemoVisibility.allCases, id: \.self) { vis in
                            Button {
                                quickCaptureVisibility = vis
                            } label: {
                                Label(vis.displayName, systemImage: vis.icon)
                            }
                        }
                    } label: {
                        Label(quickCaptureVisibility.displayName, systemImage: quickCaptureVisibility.icon)
                            .font(LiquidGlassTheme.typography.caption)
                            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    }
                    .menuStyle(.borderlessButton)

                    Spacer()

                    Button {
                        Task {
                            await quickCaptureMemo()
                        }
                    } label: {
                        Group {
                            if isQuickCaptureSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 70, height: 28)
                            } else {
                                Text(String(localized: "Capture", comment: "Button text for quick capture save"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(height: 28)
                                    .padding(.horizontal, 14)
                            }
                        }
                        .background(
                            Capsule()
                                .fill(LiquidGlassTheme.colors.accent)
                                .overlay(Capsule().fill(.white.opacity(0.15)))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isQuickCaptureSaving)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LiquidGlassTheme.colors.cardBackground.opacity(0.6))
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.4), lineWidth: 0.5)
                )
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            VStack(spacing: 8) {
                Text(String(localized: "No Memos Yet", comment: "Title for empty state view"))
                    .font(LiquidGlassTheme.typography.title3)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)

                Text(String(localized: "Capture your thoughts first, organize later", comment: "Description for empty state view"))
                    .font(LiquidGlassTheme.typography.subheadline)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            }

            Button {
                showComposeSheet = true
            } label: {
                Label(String(localized: "Open Full Editor", comment: "Button text to open full compose view"), systemImage: "square.and.pencil")
                    .font(LiquidGlassTheme.typography.callout)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Pinned Inspiration", comment: "Section header for pinned memos"))

            LazyVStack(spacing: 12) {
                ForEach(appState.pinnedMemos) { memo in
                    MemoCard(memo: memo)
                        .environmentObject(appState)
                        .onTapGesture {
                            memoToEdit = memo
                        }
                }
            }
        }
    }

    private var memosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !appState.pinnedMemos.isEmpty {
                SectionHeader(title: String(localized: "Timeline", comment: "Section header for the timeline of memos"))
            }

            ForEach(timelineGroups, id: \.date) { group in
                VStack(alignment: .leading, spacing: 10) {
                    DaySectionHeader(date: group.date)

                    LazyVStack(spacing: 12) {
                        ForEach(group.memos) { memo in
                            MemoCard(memo: memo)
                                .environmentObject(appState)
                                .onTapGesture {
                                    memoToEdit = memo
                                }
                        }
                    }
                }
            }
        }
    }

    private func quickCaptureMemo() async {
        let trimmed = quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isQuickCaptureSaving = true
        defer { isQuickCaptureSaving = false }

        do {
            let memo = try await MemosAPIClient.shared.createMemo(
                content: trimmed,
                visibility: quickCaptureVisibility
            )
            appState.memos.insert(memo, at: 0)
            quickCaptureText = ""
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
    private func refreshMemos() async {
        appState.isLoading = true
        defer { appState.isLoading = false }

        do {
            await MemosAPIClient.shared.configure(
                serverURL: appState.serverURL,
                accessToken: appState.accessToken
            )
            
            async let memos = try await MemosAPIClient.shared.fetchMemos()
            appState.memos = try await memos
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

private struct DaySectionHeader: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(dayTitle(for: date))
                .font(LiquidGlassTheme.typography.callout)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)

            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today", comment: "Day title for today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday", comment: "Day title for yesterday")
        }
        return date.formatted(.dateTime.weekday(.wide))
    }
}

struct MemoCard: View {
    @EnvironmentObject var appState: AppState
    let memo: Memo

    @State private var isHovered = false
    @State private var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if !memo.content.isEmpty {
                MarkdownView(content: memo.content, fontSize: 13)
                    .lineLimit(8)
            }

            if !memo.tags.isEmpty {
                tagsView
            }

            if !memo.resources.isEmpty {
                resourcesView
            }

            footerView
        }
        .padding(16)
        .frame(minHeight: 110, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered
                        ? LiquidGlassTheme.colors.cardBackground.opacity(0.8)
                        : LiquidGlassTheme.colors.cardBackground.opacity(0.55))
            }
            .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 16 : 10, x: 0, y: isHovered ? 6 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isHovered
                            ? LiquidGlassTheme.colors.accent.opacity(0.5)
                            : LiquidGlassTheme.colors.border.opacity(0.35),
                        lineWidth: 0.5
                    )
            )
        )
        .onHover { hovering in
            withAnimation(LiquidGlassTheme.animation.easeOut) {
                isHovered = hovering
                showActions = hovering
            }
        }
        .contextMenu {
            Button {
                Task {
                    await togglePin()
                }
            } label: {
                Label(
                    memo.pinned ? String(localized: "Unpin", comment: "Action to unpin memo") : String(localized: "Pin", comment: "Action to pin memo"),
                    systemImage: memo.pinned ? "pin.slash" : "pin"
                )
            }

            Button {
                copyContent()
            } label: {
                Label(String(localized: "Copy Content", comment: "Action to copy memo content"), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await deleteMemo()
                }
            } label: {
                Label(String(localized: "Delete", comment: "Action to delete memo"), systemImage: "trash")
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            if memo.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.yellow)
            }

            Image(systemName: memo.visibility.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            Spacer()

            if showActions {
                Button {
                    Task {
                        await togglePin()
                    }
                } label: {
                    Image(systemName: memo.pinned ? "pin.slash" : "pin")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            }
        }
    }

    private var tagsView: some View {
        FlowLayout(spacing: 6) {
            ForEach(memo.tags.prefix(5), id: \.self) { tag in
                Text("#\(tag)")
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(LiquidGlassTheme.colors.tagBackground)
                    )
            }

            if memo.tags.count > 5 {
                Text("+\(memo.tags.count - 5)")
                    .font(LiquidGlassTheme.typography.caption2)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            }
        }
    }

    private var resourcesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(memo.resources.prefix(4)) { resource in
                    if resource.isImage {
                        let resourceURL: URL? = {
                            if let link = resource.externalLink, !link.isEmpty {
                                return URL(string: link)
                            }
                            return URL(string: appState.serverURL + "/file/" + resource.name)
                        }()

                        AsyncImage(url: resourceURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(LiquidGlassTheme.colors.tertiaryBackground)
                                .overlay(
                                    ProgressView()
                                        .controlSize(.small)
                                )
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                                .font(.system(size: 12))

                            Text(resource.name)
                                .font(LiquidGlassTheme.typography.caption)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LiquidGlassTheme.colors.tertiaryBackground)
                        )
                    }
                }
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: 6) {
            Text(memo.relativeCreatedAtDescription)
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            Text("·")
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            
            if let location = memo.location {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                        .font(LiquidGlassTheme.typography.caption)
                }
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)

                Text("·")
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            }

            Text(memo.createdAt.formatted(date: .omitted, time: .shortened))
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            Spacer()
        }
    }

    private func togglePin() async {
        do {
            let updated = try await MemosAPIClient.shared.togglePinMemo(id: memo.id, pinned: !memo.pinned, memoName: memo.name)
            if let index = appState.memos.firstIndex(where: { $0.id == memo.id }) {
                appState.memos[index] = updated
            }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(memo.content, forType: .string)
    }

    private func deleteMemo() async {
        do {
            try await MemosAPIClient.shared.deleteMemo(id: memo.id)
            appState.memos.removeAll { $0.id == memo.id }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

private extension Memo {
    var relativeCreatedAtDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = .current
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
