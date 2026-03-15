import SwiftUI
import MapKit
import CoreLocation
import QuickLook

struct MemoDetailView: View {
    let memo: Memo
    @Environment(AppState.self) var appState
    @State private var commentText = ""
    @State private var isSubmitting = false
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isCommentFocused: Bool

    @State private var comments: [Memo] = []
    @State private var isLoadingComments = false
    
    // API logic to fetch specific comments for this memo
    private func loadComments() {
        isLoadingComments = true
        Task {
            do {
                let fetched = try await MemosAPIClient.shared.fetchComments(parentId: memo.name)
                await MainActor.run {
                    self.comments = fetched.sorted { $0.createdAt < $1.createdAt }
                    self.isLoadingComments = false
                }
            } catch {
                print("Failed to fetch comments: \(error)")
                await MainActor.run {
                    self.isLoadingComments = false
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    originalMemoCard
                    commentsSection
                }
            }
            .background(LiquidGlassTheme.colors.background)
            .onAppear {
                loadComments()
            }
        }
        .overlay(alignment: .bottom) {
            commentInputView
        }
        .navigationTitle(String(localized: "Memo Details", comment: "Detail view title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @State private var quickLookURL: URL?
    @State private var showMapPopover = false

    private var originalMemoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(memo.createdAt, style: .date)
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                Text(memo.createdAt, style: .time)
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                
                Spacer()
                
                if memo.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundColor(LiquidGlassTheme.colors.accent)
                }
            }

            MemoMarkdownContent(content: memo.contentWithoutTags)
                .textSelection(.enabled)
            
            if !memo.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(memo.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(LiquidGlassTheme.typography.caption)
                            .foregroundColor(LiquidGlassTheme.colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(LiquidGlassTheme.colors.accent.opacity(0.1))
                            )
                    }
                }
            }

            if !memo.attachments.isEmpty {
                attachmentsView(for: memo)
            }

            if let location = memo.location {
                locationView(location)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LiquidGlassTheme.colors.secondaryBackground.opacity(0.4))
                .glassEffect()
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField(String(localized: "Write a comment...", comment: "Placeholder for comment input"), text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LiquidGlassTheme.colors.secondaryBackground.opacity(0.5))
                    )
                    .lineLimit(1...5)
                    .focused($isCommentFocused)
                
                Button {
                    submitComment()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(commentText.isEmpty ? LiquidGlassTheme.colors.tertiaryText : LiquidGlassTheme.colors.accent)
                    }
                }
                .buttonStyle(.plain)
                .disabled(commentText.isEmpty || isSubmitting)
                .padding(.bottom, 6)
            }
            .padding(16)
            .background(
                LiquidGlassTheme.colors.background
                    .opacity(0.9)
                    .glassEffect()
            )
        }
    }

    private func submitComment() {
        guard !commentText.isEmpty else { return }
        isSubmitting = true
        
        Task {
            do {
                _ = try await MemosAPIClient.shared.createComment(parentId: memo.name, content: commentText)
                
                // Refresh memos to see the new comment
                let fetchedMemos = try await MemosAPIClient.shared.fetchMemos()
                await MainActor.run {
                    appState.memos = fetchedMemos
                    commentText = ""
                    isSubmitting = false
                    isCommentFocused = false
                    loadComments() // Refresh specific comments
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

struct CommentCard: View {
    let memo: Memo
    @Environment(AppState.self) var appState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(memo.createdAt, style: .time)
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                
                Spacer()
            }
            
            MemoMarkdownContent(content: memo.contentWithoutTags)
                .textSelection(.enabled)

            if !memo.attachments.isEmpty {
                attachmentsView(for: memo)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LiquidGlassTheme.colors.secondaryBackground.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LiquidGlassTheme.colors.border.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func attachmentsView(for memo: Memo) -> some View {
        // Reuse attachment logic from detail view but simpler
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(memo.attachments) { attachment in
                    if attachment.isImage {
                        AuthAsyncImage(urls: attachment.resolvedURLs(serverURL: appState.serverURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "doc.fill")
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }
}

extension MemoDetailView {
    private func attachmentsView(for memo: Memo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11))
                Text(String(localized: "Attachments (\(memo.attachments.count))", comment: "Label for attachments section"))
                    .font(LiquidGlassTheme.typography.caption)
            }
            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(memo.attachments) { attachment in
                        if attachment.isImage {
                            let attachmentURLs = attachment.resolvedURLs(serverURL: appState.serverURL)
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
        .quickLookPreview($quickLookURL)
    }

    private func locationView(_ location: Location) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 11, weight: .medium))

            let coordStr = "[\(String(format: "%.2f°", location.latitude)), \(String(format: "%.2f°", location.longitude))]"
            if let placeholder = location.placeholder, !placeholder.isEmpty {
                Text("\(coordStr) \(placeholder)")
                    .font(LiquidGlassTheme.typography.caption)
                    .lineLimit(1)
            } else {
                Text(coordStr)
                    .font(LiquidGlassTheme.typography.caption)
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
    }
}

extension MemoDetailView {
    var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "Comments", comment: "Section title for comments"))
                    .font(LiquidGlassTheme.typography.headline)
                    .foregroundColor(LiquidGlassTheme.colors.text)
                Text("(\(comments.count))")
                    .font(LiquidGlassTheme.typography.headline)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                
                if isLoadingComments {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if comments.isEmpty && !isLoadingComments {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 32))
                        .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                    Text(String(localized: "No comments yet", comment: "Empty state text for comments"))
                        .font(LiquidGlassTheme.typography.body)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments) { comment in
                        CommentCard(memo: comment)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 100)
    }
}
