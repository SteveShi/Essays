import SwiftUI
import QuickLook

struct AttachmentsGridView: View {
    @Environment(AppState.self) var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var quickLookURL: URL?
    
    var images: [(memo: Memo, attachment: Attachment)] {
        var all: [(Memo, Attachment)] = []
        for memo in appState.memos {
            for attachment in memo.attachments {
                if attachment.isImage {
                    all.append((memo, attachment))
                }
            }
        }
        return all.sorted { (a: (memo: Memo, attachment: Attachment), b: (memo: Memo, attachment: Attachment)) -> Bool in
            let timeA = a.attachment.createTime ?? a.memo.createdAt
            let timeB = b.attachment.createTime ?? b.memo.createdAt
            return timeA > timeB
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(images, id: \.attachment.id) { item in
                    GalleryItemView(memo: item.memo, attachment: item.attachment, quickLookURL: $quickLookURL)
                }
            }
            .padding(20)
        }
        .background(LiquidGlassTheme.colors.background)
        .quickLookPreview($quickLookURL)
        .navigationTitle(String(localized: "Attachments", comment: "Gallery view title"))
    }
}

struct GalleryItemView: View {
    let memo: Memo
    let attachment: Attachment
    @Binding var quickLookURL: URL?
    @Environment(AppState.self) var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                let attachmentURLs = attachment.resolvedURLs(serverURL: appState.serverURL)
                AuthAsyncImage(urls: attachmentURLs) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LiquidGlassTheme.colors.tertiaryBackground)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Jump to memo button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        appState.selectedMemoForDetail = memo
                        appState.isGalleryMode = false
                    }
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(8)
                .opacity(isHovered ? 1 : 0)
            }
            .onTapGesture {
                Task {
                    let attachmentURLs = attachment.resolvedURLs(serverURL: appState.serverURL)
                    if let local = await ImageStorageHelper.shared.ensureLocalImage(for: attachmentURLs) {
                        quickLookURL = local
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LiquidGlassTheme.colors.secondaryBackground.opacity(0.1))
                .glassEffect()
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
    }
}
