import SwiftUI
import CoreLocation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ComposeMemoView: View {
    @Environment(AppState.self) var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("autoSave") private var autoSave = true
    
    var editingMemo: Memo? = nil
    var isCommentEditor = false
    
    init(editingMemo: Memo? = nil, isCommentEditor: Bool = false) {
        self.editingMemo = editingMemo
        self.isCommentEditor = isCommentEditor
    }
    
    @State private var content: String = "" {
        didSet {
            // 限制内容最大长度为 100,000 字符
            if content.count > 100_000 {
                content = String(content.prefix(100_000))
                errorMessage = String(localized: "Content exceeds maximum length (100,000 characters)", comment: "Error message for content too long")
            }
        }
    }
    @State private var visibility: MemoVisibility = .private
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isContentFocused: Bool
    
    @State private var currentLocation: Location?
    @State private var uploadedAttachments: [Attachment] = []
    @State private var isUploading = false
    @State private var attachmentNames: [String] = []
    @State private var suggestedTags: [String] = []
    @State private var showFilePicker = false
    
    private var locationManager = LocationManager.shared
    @State private var myRequestID: UUID?

    @State private var showMemoPicker = false
    @State private var showCamera = false
    @State private var autoSaveTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            #if os(iOS)
            NavigationView {
                VStack(spacing: 0) {
                    contentView

                    Divider()

                    if currentLocation != nil || !uploadedAttachments.isEmpty {
                        uploadPreview
                        Divider()
                    }

                    footerView
                }
                .navigationTitle(
                    editingMemo == nil
                        ? String(localized: "New Memo", comment: "Header title for new memo")
                        : (
                            isCommentEditor
                                ? String(localized: "Edit Comment", comment: "Header title for editing comment")
                                : String(localized: "Edit Memo", comment: "Header title for editing memo")
                        )
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel", comment: "Cancel button text")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveMemo()
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(String(localized: "Save", comment: "Save button text"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                }
            }
            #else
            VStack(spacing: 0) {
                headerView

                Divider()

                contentView

                Divider()

                if currentLocation != nil || !uploadedAttachments.isEmpty {
                    uploadPreview
                    Divider()
                }

                footerView
            }
            .frame(width: 560, height: 480)
            #endif
        }
        .onAppear {
            if let memo = editingMemo {
                content = memo.content
                visibility = memo.visibility
                // 恢复已有附件和定位，防止保存时被空值覆盖
                uploadedAttachments = memo.attachments
                currentLocation = memo.location
            }
            if isCommentEditor {
                suggestedTags = []
            }
            isContentFocused = true
        }
        .onChange(of: content, initial: false) { _, newValue in
            updateSuggestedTags(from: newValue)
            if autoSave && editingMemo != nil {
                autoSaveTask?.cancel()
                autoSaveTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    saveMemo()
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { data in
                uploadPhoto(data: data)
            }
        }
        .onChange(of: locationManager.location, initial: false) { _, newLocation in
            if let newLocation = newLocation, locationManager.lastRequestID == myRequestID {
                currentLocation = newLocation
            }
        }
        .onDisappear {
            autoSaveTask?.cancel()
            locationManager.clear()
        }
    }

    #if os(macOS)
    private var headerView: some View {
        HStack {
            Button(String(localized: "Cancel", comment: "Cancel button text")) {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            
            Spacer()
            
            
            Text(
                editingMemo == nil
                    ? String(localized: "New Memo", comment: "Header title for new memo")
                    : (
                        isCommentEditor
                            ? String(localized: "Edit Comment", comment: "Header title for editing comment")
                            : String(localized: "Edit Memo", comment: "Header title for editing memo")
                    )
            )
                .font(LiquidGlassTheme.typography.headline)
                .foregroundColor(LiquidGlassTheme.colors.text)
            
            Spacer()
            
            Button {
                saveMemo()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(String(localized: "Save", comment: "Save button text"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(width: 56, height: 28)
                .foregroundColor(.white)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.6))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        }
        .padding(16)
    }
    #endif

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $content)
                .font(.system(size: editorFontSize))
                .focused($isContentFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .overlay(
                    Group {
                        if content.isEmpty && !isContentFocused {
                            VStack {
                                HStack {
                                    Text(String(localized: "What's on your mind...", comment: "Placeholder for memo content editor"))
                                        .font(.system(size: editorFontSize))
                                        .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.top, 0)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                        }
                    }
                )
            
            if !isCommentEditor && !suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button {
                                insertTag(tag)
                            } label: {
                                Text("#\(tag)")
                                    .font(LiquidGlassTheme.typography.caption)
                                    .foregroundColor(LiquidGlassTheme.colors.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(LiquidGlassTheme.colors.tagBackground)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            if let error = errorMessage ?? locationManager.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(LiquidGlassTheme.colors.error)
                    
                    Text(error)
                        .font(LiquidGlassTheme.typography.callout)
                        .foregroundColor(LiquidGlassTheme.colors.error)
                }
            }
        }
        .padding(16)
    }
    
    private var footerView: some View {
        HStack(spacing: 16) {
            #if os(iOS)
            HStack(spacing: 4) {
                Image(systemName: visibility.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Menu {
                    ForEach(MemoVisibility.allCases, id: \.self) { vis in
                        Button {
                            visibility = vis
                        } label: {
                            Label(vis.displayName, systemImage: vis.icon)
                        }
                    }
                } label: {
                    Text(visibility.displayName)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            #else
            HStack(spacing: 4) {
                Image(systemName: visibility.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)

                Menu {
                    ForEach(MemoVisibility.allCases, id: \.self) { vis in
                        Button {
                            visibility = vis
                        } label: {
                            Label(vis.displayName, systemImage: vis.icon)
                        }
                    }
                } label: {
                    Text(visibility.displayName)
                        .font(LiquidGlassTheme.typography.callout)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            #endif

            Spacer()

            HStack(spacing: 12) {
                if !isCommentEditor {
                    Button {
                        insertTag("")
                    } label: {
                        Image(systemName: "number")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    #if os(iOS)
                    .foregroundColor(.secondary)
                    #else
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .help(String(localized: "Insert Tag", comment: "Help tooltip for tag button"))
                    #endif
                }

                Button {
                    content += "**bold**"
                } label: {
                    Image(systemName: "bold")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Bold", comment: "Help tooltip for bold button"))
                #endif

                Button {
                    content += "*italic*"
                } label: {
                    Image(systemName: "italic")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Italic", comment: "Help tooltip for italic button"))
                #endif

                Button {
                    content += "~~strikethrough~~"
                } label: {
                    Image(systemName: "strikethrough")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Strikethrough", comment: "Help tooltip for strikethrough button"))
                #endif

                Button {
                    content += "`code`"
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Inline Code", comment: "Help tooltip for inline code button"))
                #endif

                Button {
                    content += "\n```\n\n```\n"
                } label: {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Code Block", comment: "Help tooltip for code block button"))
                #endif

                Button {
                    content += "\n- "
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Unordered List", comment: "Help tooltip for unordered list button"))
                #endif

                Button {
                    content += "\n1. "
                } label: {
                    Image(systemName: "list.number")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Ordered List", comment: "Help tooltip for ordered list button"))
                #endif

                Button {
                    content += "\n- [ ] "
                } label: {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Task List", comment: "Help tooltip for task list button"))
                #endif

                Button {
                    content += "\n### "
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Heading", comment: "Help tooltip for heading button"))
                #endif

                Button {
                    showMemoPicker = true
                } label: {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(
                    String(
                        localized: "Link to Memo", comment: "Help tooltip for memo linking button")
                )
                #endif
                .popover(isPresented: $showMemoPicker) {
                    MemoPicker(onSelect: { memo in
                        content +=
                            " [\(String(localized: "Memo", comment: "Label for linked memo reference"))](\(memo.name))"
                        showMemoPicker = false
                    })
                    #if os(iOS)
                    .frame(width: 300, height: 400)
                    #else
                    .frame(width: 300, height: 400)
                    #endif
                }

                Button {
                    let id = UUID()
                    myRequestID = id
                    locationManager.requestLocation(id: id)
                } label: {
                    if locationManager.isFetching && locationManager.lastRequestID == myRequestID {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: locationManager.error) { _, newError in
                    if let newError = newError, locationManager.lastRequestID == myRequestID {
                        errorMessage = newError
                    }
                }
                #if os(iOS)
                .foregroundColor(
                    currentLocation != nil
                        ? .accentColor : .secondary
                )
                #else
                .foregroundColor(
                    currentLocation != nil
                        ? LiquidGlassTheme.colors.accent : LiquidGlassTheme.colors.secondaryText
                )
                .help(
                    String(localized: "Add Location", comment: "Help tooltip for location button"))
                #endif

                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Take Photo", comment: "Help tooltip for camera button"))
                #endif

                Button {
                    selectImages()
                } label: {
                    Group {
                        if isUploading {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .buttonStyle(.plain)
                #if os(iOS)
                .foregroundColor(.secondary)
                .disabled(isUploading)
                #else
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .disabled(isUploading)
                .help(
                    String(
                        localized: "Upload Image", comment: "Help tooltip for image upload button"))
                #endif
            }
        }
        .padding(16)
        #if os(iOS)
        .background(Color(uiColor: .systemGroupedBackground))
        #else
        .background(LiquidGlassTheme.colors.secondaryBackground)
        #endif
    }
    
    private func updateSuggestedTags(from text: String) {
        if isCommentEditor {
            suggestedTags = []
            return
        }

        var tags: [String] = []
        
        let tagPattern = "#([a-zA-Z0-9_\\u4e00-\\u9fff]+)"
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: []) else { return }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                tags.append(String(text[range]))
            }
        }
        
        suggestedTags = appState.tags
            .filter { tag in
                !tags.contains(tag.name.lowercased())
            }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0.name }
    }
    
    private func insertTag(_ tag: String) {
        if tag.isEmpty {
            content += "#"
        } else {
            content += " #\(tag) "
        }
    }
    
    private var uploadPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let location = currentLocation {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    if let placeholder = location.placeholder, !placeholder.isEmpty {
                        Text(placeholder)
                            .font(LiquidGlassTheme.typography.caption)
                            .lineLimit(1)
                    } else {
                        let coordStr = "[\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))]"
                        Text(coordStr)
                            .font(LiquidGlassTheme.typography.caption)
                            .lineLimit(1)
                    }
                    Button {
                        currentLocation = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if currentLocation != nil && !uploadedAttachments.isEmpty {
                Divider()
            }

            if !uploadedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(uploadedAttachments) { attachment in
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
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Button {
                                    uploadedAttachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                            }
                        }
                    }
                    .padding(12)
                }
                .background(LiquidGlassTheme.colors.secondaryBackground.opacity(0.5))
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                handleSelectedURLs(urls)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleSelectedURLs(_ urls: [URL]) {
        let maxFileSize = 10 * 1024 * 1024 // 10MB

        if appState.isLocalMode {
            let localAttachments = urls.compactMap { url -> Attachment? in
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }

                guard let data = try? Data(contentsOf: url) else { return nil }

                // 检查文件大小
                guard data.count <= maxFileSize else {
                    DispatchQueue.main.async {
                        self.errorMessage = String(localized: "File size exceeds limit (10MB)", comment: "Error message for file too large")
                    }
                    return nil
                }

                let ext = url.pathExtension.lowercased()
                let mimeType =
                    (ext == "jpg" || ext == "jpeg")
                    ? "image/jpeg"
                    : (ext == "gif"
                        ? "image/gif" : (ext == "webp" ? "image/webp" : "image/png"))

                return Attachment(
                    name: "local/attachments/\(UUID().uuidString)",
                    filename: url.lastPathComponent,
                    type: mimeType,
                    size: Int64(data.count),
                    content: data.base64EncodedString(),
                    externalLink: url.absoluteString
                )
            }
            uploadedAttachments.append(contentsOf: localAttachments)
            isUploading = false
            return
        }

        isUploading = true
        Task {
            for url in urls {
                // For iOS security scoped resources
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)

                    // 检查文件大小
                    guard data.count <= maxFileSize else {
                        await MainActor.run {
                            self.errorMessage = String(localized: "File size exceeds limit (10MB)", comment: "Error message for file too large")
                        }
                        continue
                    }

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
                    await MainActor.run {
                        self.uploadedAttachments.append(attachment)
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            await MainActor.run {
                self.isUploading = false
            }
        }
    }
    
    // Removed broken fetchLocation() inline implementation

    private func selectImages() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.image]

        if panel.runModal() == .OK {
            handleSelectedURLs(panel.urls)
        }
        #else
        showFilePicker = true
        #endif
    }

    private func uploadPhoto(data: Data) {
        if appState.isLocalMode {
            let attachment = Attachment(
                name: "local/attachments/\(UUID().uuidString)",
                filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
                type: "image/jpeg",
                size: Int64(data.count),
                content: data.base64EncodedString()
            )
            uploadedAttachments.append(attachment)
            isUploading = false
            return
        }

        isUploading = true
        Task {
            do {
                let attachment = try await MemosAPIClient.shared.uploadAttachment(
                    data: data,
                    filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                self.uploadedAttachments.append(attachment)
                self.isUploading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isUploading = false
            }
        }
    }

    private func saveMemo() {
        let extractedTags = isCommentEditor ? [] : MemoUtility.extractTags(from: content)
        let attachmentNames = uploadedAttachments.map { $0.name }
        
        do {
            if let memo = editingMemo {
                // 1. Update locally
                memo.content = content
                memo.visibility = visibility
                memo.tags = extractedTags
                memo.location = currentLocation
                memo.updatedAt = Date()
                
                // Save attachment relations locally
                for attr in uploadedAttachments {
                    attr.parentMemo = memo
                    memo.attachments.append(attr)
                }

                LocalDatabase.shared.syncReferenceRelations(for: memo, content: content)
                
                // 2. Enqueue OutboxTask
                let payload = MemoPayload(
                    content: content,
                    visibility: visibility.rawValue,
                    pinned: memo.pinned,
                    tags: extractedTags,
                    attachmentNames: attachmentNames,
                    locationPlaceholder: currentLocation?.placeholder,
                    locationLatitude: currentLocation?.latitude,
                    locationLongitude: currentLocation?.longitude,
                    accountID: appState.activeAccountID
                )
                if !appState.isLocalMode {
                    let payloadData = try JSONEncoder().encode(payload)
                    let task = OutboxTask(type: .updateMemo, payload: payloadData, memoId: memo.name)
                    LocalDatabase.shared.context.insert(task)
                }
                try LocalDatabase.shared.context.save()
                
            } else {
                // 1. Create locally with temporary ID
                let tempId = "local_\(UUID().uuidString)"
                let newMemo = Memo(
                    name: tempId,
                    numericID: "",
                    content: content,
                    createdAt: Date(),
                    updatedAt: Date(),
                    visibility: visibility,
                    pinned: false,
                    state: .normal,
                    tags: extractedTags,
                    attachments: uploadedAttachments,
                    location: currentLocation,
                    relations: [],
                    accountID: appState.activeAccountID
                )
                LocalDatabase.shared.context.insert(newMemo)
                LocalDatabase.shared.syncReferenceRelations(for: newMemo, content: content)
                
                // 2. Enqueue OutboxTask
                if !appState.isLocalMode {
                    let payload = MemoPayload(
                        content: content,
                        visibility: visibility.rawValue,
                        pinned: false,
                        tags: extractedTags,
                        attachmentNames: attachmentNames,
                        locationPlaceholder: currentLocation?.placeholder,
                        locationLatitude: currentLocation?.latitude,
                        locationLongitude: currentLocation?.longitude,
                        accountID: appState.activeAccountID
                    )
                    let payloadData = try JSONEncoder().encode(payload)
                    let task = OutboxTask(type: .createMemo, payload: payloadData, memoId: tempId)
                    LocalDatabase.shared.context.insert(task)
                }
                try LocalDatabase.shared.context.save()
            }
            
            // Trigger background sync
            SyncEngine.shared.triggerSync()
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

struct MemoPicker: View {
    @Environment(AppState.self) var appState: AppState
    var onSelect: (Memo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Recent Memos", comment: "Title for recent memos picker"))
                .font(.headline)
                .padding()

            Divider()

            List {
                ForEach(appState.memos.prefix(20)) { memo in
                    Button {
                        onSelect(memo)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.content)
                                .font(.system(size: 12))
                                .lineLimit(2)
                                .foregroundColor(LiquidGlassTheme.colors.text)

                            Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .background(LiquidGlassTheme.colors.secondaryBackground)
    }
}
