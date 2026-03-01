import SwiftUI
import CoreLocation

struct ComposeMemoView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    
    var editingMemo: Memo?
    
    @State private var content: String = ""
    @State private var visibility: MemoVisibility = .private
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isContentFocused: Bool
    
    @State private var currentLocation: Location?
    @State private var uploadedAttachments: [Attachment] = []
    @State private var isUploading = false
    @State private var attachmentNames: [String] = []
    @State private var suggestedTags: [String] = []
    
    @State private var locationManager = LocationManager()

    @State private var showMemoPicker = false
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            contentView
            
            Divider()
            
            if !uploadedAttachments.isEmpty {
                uploadPreview
                Divider()
            }

            footerView
        }
        .frame(width: 560, height: 480)
        .onAppear {
            if let memo = editingMemo {
                content = memo.content
                visibility = memo.visibility
            }
            isContentFocused = true
        }
        .onChange(of: content, initial: false) { _, newValue in
            updateSuggestedTags(from: newValue)
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { data in
                uploadPhoto(data: data)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(String(localized: "Cancel", comment: "Cancel button text")) {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            
            Spacer()
            
            
            Text(editingMemo == nil ? String(localized: "New Memo", comment: "Header title for new memo") : String(localized: "Edit Memo", comment: "Header title for editing memo"))
                .font(LiquidGlassTheme.typography.headline)
                .foregroundColor(LiquidGlassTheme.colors.text)
            
            Spacer()
            
            Button {
                Task {
                    await saveMemo()
                }
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
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $content)
                .font(LiquidGlassTheme.typography.body)
                .focused($isContentFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .overlay(
                    Group {
                        if content.isEmpty {
                            VStack {
                                HStack {
                                    Text(String(localized: "What's on your mind...", comment: "Placeholder for memo content editor"))
                                        .font(LiquidGlassTheme.typography.body)
                                        .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.top, 10)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                        }
                    }
                )
            
            if !suggestedTags.isEmpty {
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
            
            if let error = errorMessage {
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
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    insertTag("")
                } label: {
                    Image(systemName: "number")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Insert Tag", comment: "Help tooltip for tag button"))
                
                Button {
                    content += "**bold**"
                } label: {
                    Image(systemName: "bold")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Bold", comment: "Help tooltip for bold button"))
                
                Button {
                    content += "`code`"
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Inline Code", comment: "Help tooltip for inline code button"))
                
                Button {
                    content += "\n```\n\n```\n"
                } label: {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Code Block", comment: "Help tooltip for code block button"))
                
                Button {
                    showMemoPicker = true
                } label: {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(
                    String(
                        localized: "Link to Memo", comment: "Help tooltip for memo linking button")
                )
                .popover(isPresented: $showMemoPicker) {
                    MemoPicker(onSelect: { memo in
                        content +=
                            " [\(String(localized: "Memo", comment: "Label for linked memo reference"))](\(memo.name))"
                        showMemoPicker = false
                    })
                    .frame(width: 300, height: 400)
                }

                Button {
                    locationManager.requestLocation()
                } label: {
                    if locationManager.isFetching {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(
                    currentLocation != nil
                        ? LiquidGlassTheme.colors.accent : LiquidGlassTheme.colors.secondaryText
                )
                .help(
                    String(localized: "Add Location", comment: "Help tooltip for location button"))

                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .help(String(localized: "Take Photo", comment: "Help tooltip for camera button"))

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
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .disabled(isUploading)
                .help(
                    String(
                        localized: "Upload Image", comment: "Help tooltip for image upload button"))
            }
        }
        .padding(16)
        .background(LiquidGlassTheme.colors.secondaryBackground)
    }
    
    private func updateSuggestedTags(from text: String) {
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
                    Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                        .font(LiquidGlassTheme.typography.caption)
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

            Divider()

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
        .onAppear {
            if editingMemo == nil {
                locationManager.requestLocation()
            } else {
                currentLocation = editingMemo?.location
            }
        }
        .onChange(of: locationManager.location, initial: false) { _, newLocation in
            if newLocation != nil {
                currentLocation = newLocation
            }
        }
    }
    
    // Removed broken fetchLocation() inline implementation

    private func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            isUploading = true
            Task {
                for url in panel.urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let filename = url.lastPathComponent
                        let attachment = try await MemosAPIClient.shared.uploadAttachment(
                            data: data,
                            filename: filename,
                            mimeType: "image/png"
                        )
                        uploadedAttachments.append(attachment)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                isUploading = false
            }
        }
    }

    private func uploadPhoto(data: Data) {
        isUploading = true
        Task {
            do {
                let attachment = try await MemosAPIClient.shared.uploadAttachment(
                    data: data,
                    filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg",
                    mimeType: "image/jpeg"
                )
                uploadedAttachments.append(attachment)
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func saveMemo() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        let attachmentNames = uploadedAttachments.map { $0.name }

        do {
            if let memo = editingMemo {
                let updated = try await MemosAPIClient.shared.updateMemo(
                    id: memo.numericID,
                    memoName: memo.name,
                    content: content,
                    visibility: visibility,
                    attachmentNames: attachmentNames,
                    location: currentLocation
                )
                
                if let index = appState.memos.firstIndex(where: { $0.name == memo.name }) {
                    appState.memos[index] = updated
                }
            } else {
                let newMemo = try await MemosAPIClient.shared.createMemo(
                    content: content,
                    visibility: visibility,
                    attachmentNames: attachmentNames,
                    location: currentLocation
                )
                appState.memos.insert(newMemo, at: 0)
            }
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MemoPicker: View {
    @Environment(AppState.self) var appState
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
