import SwiftUI
import CoreLocation
import QuickLook
import MapKit

struct MemoListView: View {
    @Environment(AppState.self) var appState
    @State private var showComposeSheet = false
    @State private var memoToEdit: Memo?
    @State private var showAIAssistant = false

    @State private var quickCaptureText: String = ""
    @State private var quickCaptureVisibility: MemoVisibility = .private
    @State private var isQuickCaptureSaving = false
    @State private var quickCaptureAttachments: [Attachment] = []
    @State private var quickCaptureLocation: Location? = nil
    @State private var showQuickMemoPicker = false
    @State private var showQuickCamera = false
    @State private var isQuickUploading = false
    @AppStorage("enableAIFeatures") private var enableAIFeatures = true
    
    @State private var locationManager = LocationManager()
    @State private var hoveredMemoId: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if appState.isGalleryMode {
                AttachmentsGridView()
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                appState.isGalleryMode = false
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
            } else {
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
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if appState.filteredMemos.isEmpty {
                                emptyStateView
                                    .padding(.top, 40)
                            } else {
                                if !appState.pinnedMemosList.isEmpty {
                                    pinnedSection
                                }

                                if !appState.timelineGroups.isEmpty {
                                    memosSection
                                }
                            }
                        }
                        .padding(24)
                    }
                    .onChange(of: appState.scrollToMemoID) { _, newValue in
                        if let id = newValue {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                            // Reset after scroll
                            appState.scrollToMemoID = nil
                        }
                    }
                }
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
                                if #available(macOS 26.0, *) {
                                    AIAssistantView(memo: memo)
                                } else {
                                    Text(
                                        String(
                                            localized: "AI Assistant requires macOS 26.0 or newer",
                                            comment: "AI assistant availability fallback")
                                    )
                                    .padding()
                                }
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
        }
        .sheet(isPresented: $showComposeSheet) {
            ComposeMemoView()
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

                if !quickCaptureAttachments.isEmpty || quickCaptureLocation != nil {
                    HStack(spacing: 8) {
                        if let location = quickCaptureLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10))
                                Text(
                                    String(
                                        format: "%.4f, %.4f", location.latitude, location.longitude)
                                )
                                .font(LiquidGlassTheme.typography.caption)
                                Button {
                                    quickCaptureLocation = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(LiquidGlassTheme.colors.tertiaryBackground))
                        }

                        ForEach(quickCaptureAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                if attachment.isImage {
                                    let attachmentURLs = attachment.resolvedURLs(
                                        serverURL: appState.serverURL)
                                    AuthAsyncImage(urls: attachmentURLs) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(LiquidGlassTheme.colors.tertiaryBackground)
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button {
                                    quickCaptureAttachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    Menu {
                        Button {
                            showQuickCamera = true
                        } label: {
                            Label(
                                String(localized: "Take Photo", comment: "Take photo menu item"),
                                systemImage: "camera")
                        }

                        Button {
                            selectQuickImages()
                        } label: {
                            Label(
                                String(localized: "Upload", comment: "Upload menu item"),
                                systemImage: "doc")
                        }

                        Button {
                            showQuickMemoPicker = true
                        } label: {
                            Label(
                                String(localized: "Link Memo", comment: "Link memo menu item"),
                                systemImage: "link")
                        }

                        Button {
                            locationManager.requestLocation()
                        } label: {
                            if locationManager.isFetching {
                                Label(
                                    String(
                                        localized: "Fetching Location...",
                                        comment: "Location fetching menu item"),
                                    systemImage: "location.fill"
                                )
                            } else {
                                Label(
                                    String(localized: "Location", comment: "Location menu item"),
                                    systemImage: "mappin.and.ellipse")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LiquidGlassTheme.colors.tertiaryBackground)
                            )
                    }
                    .menuStyle(.borderlessButton)
                    .popover(isPresented: $showQuickMemoPicker) {
                        MemoPicker(onSelect: { memo in
                            quickCaptureText += " [Memo](\(memo.name))"
                            showQuickMemoPicker = false
                        })
                        .frame(width: 300, height: 400)
                    }

                    Menu {
                        ForEach(MemoVisibility.allCases, id: \.self) { vis in
                            Button {
                                quickCaptureVisibility = vis
                            } label: {
                                Label(vis.displayName, systemImage: vis.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: quickCaptureVisibility.icon)
                            Text(quickCaptureVisibility.displayName)
                        }
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
                                Text(
                                    String(
                                        localized: "Save",
                                        comment: "Button text for quick capture save"))
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
                        .fill(LiquidGlassTheme.colors.cardFill(isHovered: false, colorScheme: colorScheme))
                        .glassEffect()
                }
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.4), lineWidth: 0.5)
                )
            )
        }
        .onChange(of: locationManager.location, initial: false) { _, newLocation in
            if newLocation != nil {
                withAnimation(LiquidGlassTheme.animation.spring) {
                    quickCaptureLocation = newLocation
                }
            }
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

            VStack(spacing: 12) {
                ForEach(appState.pinnedMemosList) { memo in
                    MemoCard(memo: memo, onEdit: {
                        memoToEdit = memo
                    })
                    .id(memo.name)
                }
            }
        }
    }

    private var memosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !appState.pinnedMemosList.isEmpty {
                SectionHeader(title: String(localized: "Timeline", comment: "Section header for the timeline of memos"))
            }

            ForEach(appState.timelineGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    DaySectionHeader(date: group.date)

                    VStack(spacing: 12) {
                        ForEach(group.memos) { memo in
                            MemoCard(memo: memo, onEdit: {
                                memoToEdit = memo
                            })
                            .id(memo.name)
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

        let extractedTags = MemoUtility.extractTags(from: trimmed)
        let attachmentNames = quickCaptureAttachments.map { $0.name }

        do {
            let memo = try await MemosAPIClient.shared.createMemo(
                content: trimmed,
                visibility: quickCaptureVisibility,
                tags: extractedTags,
                attachmentNames: attachmentNames,
                location: quickCaptureLocation
            )
            appState.memos.insert(memo, at: 0)
            quickCaptureText = ""
            quickCaptureAttachments = []
            quickCaptureLocation = nil
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }



    private func selectQuickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            isQuickUploading = true
            let urls = panel.urls
            Task {
                for url in urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let ext = url.pathExtension.lowercased()
                        let mimeType =
                            (ext == "jpg" || ext == "jpeg")
                            ? "image/jpeg"
                            : (ext == "gif"
                                ? "image/gif" : (ext == "webp" ? "image/webp" : "image/png"))
                        let attachment = try await MemosAPIClient.shared.uploadAttachment(
                            data: data,
                            filename: filename,
                            mimeType: mimeType
                        )
                        self.quickCaptureAttachments.append(attachment)
                    } catch {
                        self.appState.errorMessage = error.localizedDescription
                    }
                }
                self.isQuickUploading = false
            }
        }
    }
    private func uploadQuickPhoto(data: Data) {
        isQuickUploading = true
        Task {
            do {
                let attachment = try await MemosAPIClient.shared.uploadAttachment(
                    data: data,
                    filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                self.quickCaptureAttachments.append(attachment)
                self.isQuickUploading = false
            } catch {
                self.appState.errorMessage = error.localizedDescription
                self.isQuickUploading = false
            }
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
            
            let memos = try await MemosAPIClient.shared.fetchMemos()
            appState.memos = memos
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
        let calendar = Self.sharedCalendar
        if calendar.isDateInToday(date) {
            return String(localized: "Today", comment: "Day title for today")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday", comment: "Day title for yesterday")
        }
        return Self.weekdayFormatter.string(from: date)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let sharedCalendar = Calendar.current
}

struct MemoCard: View {
    @Environment(AppState.self) var appState
    @Environment(\.colorScheme) private var colorScheme
    let memo: Memo
    var onEdit: () -> Void

    @State private var isHovered = false
    @State private var showActions = false
    @State private var quickLookURL: URL?
    @State private var showMapPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if !memo.content.isEmpty {
                MemoMarkdownContent(content: memo.truncatedContent)
                    .textSelection(.enabled)
            }

            if !memo.tags.isEmpty {
                tagsView
            }

            if !memo.attachments.isEmpty {
                attachmentsView
            }

            if let location = memo.location {
                locationView(location)
            }

            if !memo.relations.isEmpty {
                relationsView
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LiquidGlassTheme.colors.cardFill(isHovered: isHovered, colorScheme: colorScheme))
                    .glassEffect()
            }
            .shadow(
                color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 16 : 10, x: 0,
                y: isHovered ? 6 : 3)
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
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appState.selectedMemoForDetail = memo
            }
        }
        .quickLookPreview($quickLookURL)
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(memo.relativeCreatedAtDescription)
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            if memo.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }

            Image(systemName: memo.visibility.icon)
                .font(.system(size: 10))
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            if memo.isPendingSync {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 10))
                    .foregroundColor(LiquidGlassTheme.colors.accent)
                    .help(
                        String(
                            localized: "Pending Sync", comment: "Tooltip for pending sync status"))
            }

            if memo.commentCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 10))
                                Text(String(localized: "\(memo.commentCount)", comment: "Comment count value"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(LiquidGlassTheme.colors.secondaryBackground.opacity(0.5))
                )
            }

            Spacer()

            Menu {
                Button {
                    Task { await togglePin() }
                } label: {
                    Label(
                        memo.pinned
                            ? String(localized: "Unpin", comment: "Context menu item to unpin memo")
                            : String(localized: "Pin", comment: "Context menu item to pin memo"),
                        systemImage: memo.pinned ? "pin.slash" : "pin")
                }

                Button {
                    onEdit()
                } label: {
                    Label(
                        String(localized: "Edit", comment: "Context menu item to edit memo"),
                        systemImage: "pencil")
                }
                
                Button {
                    Task {
                        if memo.state == .archived {
                            await appState.unarchiveMemo(memo)
                        } else {
                            await appState.archiveMemo(memo)
                        }
                    }
                } label: {
                    Label(
                        memo.state == .archived
                            ? String(localized: "Restore", comment: "Context menu item to restore memo")
                            : String(localized: "Archive", comment: "Context menu item to archive memo"),
                        systemImage: memo.state == .archived ? "arrow.up.bin" : "archivebox")
                }
                
                Button {
                    copyContent()
                } label: {
                    Label(
                        String(
                            localized: "Copy Content",
                            comment: "Context menu item to copy memo content"),
                        systemImage: "doc.on.doc")
                }

                Button {
                    copyLink()
                } label: {
                    Label(
                        String(
                            localized: "Copy Link",
                            comment: "Context menu item to copy memo link"),
                        systemImage: "link")
                }

                Divider()

                Button(role: .destructive) {
                    Task { await deleteMemo() }
                } label: {
                    Label(
                        String(localized: "Delete", comment: "Context menu item to delete memo"),
                        systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .opacity(isHovered ? 1 : 0.6)
        }
    }

    // Truncation logic moved to Memo model extension

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

    private var attachmentsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                Text(
                    String(
                        localized: "Attachments (\(memo.attachments.count))",
                        comment: "Label for attachments section")
                )
                .font(LiquidGlassTheme.typography.caption)
            }
            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(memo.attachments) { attachment in
                        if attachment.isImage {
                            let attachmentURLs = attachment.resolvedURLs(
                                serverURL: appState.serverURL)
                            AuthAsyncImage(urls: attachmentURLs) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(LiquidGlassTheme.colors.tertiaryBackground)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    if let local = await ImageStorageHelper.shared.ensureLocalImage(for: attachmentURLs) {
                                        quickLookURL = local
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 14))
                                Text(attachment.filename)
                                    .font(LiquidGlassTheme.typography.caption)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LiquidGlassTheme.colors.tertiaryBackground)
                            )
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    private func locationView(_ location: Location) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 11, weight: .medium))

            let coordStr =
                "[\(String(format: "%.2f°", location.latitude)), \(String(format: "%.2f°", location.longitude))]"
            if let placeholder = location.placeholder, !placeholder.isEmpty {
                Text("\(coordStr) \(placeholder)")
                    .font(LiquidGlassTheme.typography.caption)
                    .lineLimit(1)
            } else {
                Text(coordStr)
                    .font(LiquidGlassTheme.typography.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LiquidGlassTheme.colors.tertiaryBackground)
        )
        .onTapGesture {
            showMapPopover = true
        }
        .popover(isPresented: $showMapPopover) {
            VStack {
                let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(location.placeholder ?? String(localized: "Location", comment: "Map marker label"), coordinate: coordinate)
                }
                .frame(width: 300, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(8)
        }
        .padding(.bottom, 12)
        .padding(.leading, 16)
    }

    private var relationsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let outgoing = memo.relations.filter { $0.memo == memo.name && $0.type != .comment }
            let incoming = memo.relations.filter { $0.relatedMemo == memo.name && $0.type != .comment }

            if !outgoing.isEmpty {
                relationBlock(
                    title: String(localized: "References", comment: "Reference section"),
                    icon: "link", items: outgoing)
            }

            if !incoming.isEmpty {
                relationBlock(
                    title: String(localized: "Referenced By", comment: "Referenced by section"),
                    icon: "arrow.uturn.left", items: incoming)
            }
        }
    }

    private func relationBlock(title: String, icon: String, items: [Relation]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(String(localized: "\(title) (\(items.count))", comment: "Section title with item count"))
                    .font(LiquidGlassTheme.typography.caption)
            }
            .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            .padding(.horizontal, 10)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { relation in
                    let targetName =
                        relation.memo == memo.name ? relation.relatedMemo : relation.memo
                    let shortId =
                        targetName.split(separator: "/").last.map(String.init) ?? targetName

                    if let targetMemo = appState.memosByName[targetName] {
                        HStack(alignment: .top, spacing: 6) {
                            Text(shortId)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LiquidGlassTheme.colors.secondaryBackground)
                                )
                            Text(
                                targetMemo.truncatedContent.prefix(100)
                                    + (targetMemo.truncatedContent.count > 100 ? "..." : "")
                            )
                            .font(LiquidGlassTheme.typography.caption)
                            .lineLimit(2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6).fill(
                                LiquidGlassTheme.colors.tertiaryBackground)
                        )
                        .onTapGesture {
                            appState.scrollToMemoID = targetName
                        }
                        .help(String(localized: "Jump to this memo", comment: "Tooltip for jumping to referenced memo"))
                    } else {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text(targetName)
                                .font(LiquidGlassTheme.typography.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4).fill(
                                LiquidGlassTheme.colors.tertiaryBackground))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func togglePin() async {
        do {
            let updated = try await MemosAPIClient.shared.togglePinMemo(
                id: memo.numericID, pinned: !memo.pinned, memoName: memo.name)
            if let index = appState.memos.firstIndex(where: { $0.name == memo.name }) {
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

    private func copyLink() {
        let base = appState.serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let link = "\(base)/m/\(memo.name)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }

    private func deleteMemo() async {
        do {
            try await MemosAPIClient.shared.deleteMemo(id: memo.numericID, memoName: memo.name)
            appState.memos.removeAll { $0.name == memo.name }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

