import SwiftUI
import Combine

struct AuthAsyncImage<Content: View, Placeholder: View>: View {
    @StateObject private var loader: ImageLoader
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let uiImage = loader.image {
                content(Image(nsImage: uiImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    private let url: URL?
    private var cancellable: AnyCancellable?
    
    // We use the shared token from UserDefaults implicitly, or you can pass it in.
    // For simplicity, we can fetch it here similar to AppState.
    init(url: URL?) {
        self.url = url
    }

    func load() {
        guard let url = url, image == nil else { return }
        
        var request = URLRequest(url: url)
        
        let userDefaults = UserDefaults.standard
        if let token = userDefaults.string(forKey: "memos_access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map { NSImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fetchedImage in
                self?.image = fetchedImage
            }
    }
}
