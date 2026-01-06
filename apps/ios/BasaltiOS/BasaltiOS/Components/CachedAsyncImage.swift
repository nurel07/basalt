import SwiftUI

struct CachedAsyncImage<Content: View>: View {
    @StateObject private var loader: ImageLoader
    private let content: (AsyncImagePhase) -> Content
    
    init(
        url: URL,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url, targetSize: targetSize))
        self.content = content
    }
    
    var body: some View {
        content(loader.phase)
            .onAppear { loader.load() }
            .onDisappear { loader.cancel() }
    }
}
