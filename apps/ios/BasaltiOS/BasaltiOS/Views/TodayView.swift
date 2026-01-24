import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel
@MainActor
class TodayViewModel: ObservableObject {
    @Published var wallpaper: Wallpaper?
    @Published var heroImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasLoaded = false
    private let imageRetryDelay: UInt64 = 200_000_000 // 0.2s
    
    private enum TodayViewError: LocalizedError {
        case invalidImageURL
        case imageDecodeFailed
        case imageDownloadFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidImageURL:
                return "Invalid image URL returned by server."
            case .imageDecodeFailed:
                return "Unable to decode today's image."
            case .imageDownloadFailed(let error):
                return "Image download failed: \(error.localizedDescription)"
            }
        }
    }
    
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        
        do {
            let wallpaper = try await APIService.shared.fetchTodayWallpaper()
            let image = try await fetchHeroImage(for: wallpaper)
            self.wallpaper = wallpaper
            self.heroImage = image
            self.errorMessage = nil
        } catch {
            if heroImage == nil {
                errorMessage = userMessage(from: error, fallback: "Failed to load today's selection. Please try again.")
            }
            print("TodayView load error: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    func refresh() async {
        isLoading = true
        let previousWallpaper = wallpaper
        let previousImage = heroImage
        
        do {
            let wallpaper = try await APIService.shared.fetchTodayWallpaper()
            let image = try await fetchHeroImage(for: wallpaper)
            self.wallpaper = wallpaper
            self.heroImage = image
            self.errorMessage = nil
        } catch {
            // Keep previous data when refresh fails
            self.wallpaper = previousWallpaper
            self.heroImage = previousImage
            self.errorMessage = userMessage(from: error, fallback: "Failed to refresh today's selection.")
            print("TodayView refresh error: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    private func fetchHeroImage(for wallpaper: Wallpaper) async throws -> UIImage {
        guard let url = URL(string: CloudflareImageService.displayURL(from: wallpaper.url)) else {
            throw TodayViewError.invalidImageURL
        }
        return try await downloadImageWithRetry(from: url)
    }
    
    private func downloadImageWithRetry(from url: URL, retries: Int = 2) async throws -> UIImage {
        var attempt = 0
        var lastError: Error?
        while attempt <= retries {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    return image
                } else {
                    throw TodayViewError.imageDecodeFailed
                }
            } catch {
                lastError = error
                attempt += 1
                if attempt > retries { break }
                try await Task.sleep(nanoseconds: imageRetryDelay)
            }
        }
        throw TodayViewError.imageDownloadFailed(lastError ?? URLError(.unknown))
    }
    
    private func userMessage(from error: Error, fallback: String) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "Invalid server URL for today's selection."
            case .serverError:
                return "Server error while fetching today's selection."
            case .decodingError:
                return "Received unexpected data for today's selection."
            }
        } else if let todayError = error as? TodayViewError {
            return todayError.localizedDescription
        } else if let urlError = error as? URLError {
            return "Network issue: \(urlError.localizedDescription)"
        }
        return fallback
    }
}

// MARK: - View
struct TodayView: View {
    @Binding var isZooming: Bool
    @ObservedObject var viewModel: TodayViewModel
    
    // Hero transition
    @Namespace private var namespace
    @State private var isShowingDetail = false
    @State private var shareURL: URL?
    @State private var isShowingShareSheet = false
    @State private var downloadState: DownloadState = .idle
    
    var body: some View {
        ZStack {
            Color.basaltBackgroundPrimary.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.heroImage == nil {
                ProgressView()
                    .tint(.basaltTextPrimary)
                    .scaleEffect(1.5)
            } else if let error = viewModel.errorMessage, viewModel.heroImage == nil {
                errorState(message: error)
            } else if let wallpaper = viewModel.wallpaper, let heroImage = viewModel.heroImage {
                thumbnailView(wallpaper: wallpaper, image: heroImage)
                
                if isShowingDetail {
                    ImageDetailView(
                        image: heroImage,
                        namespace: namespace,
                        onDismiss: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isShowingDetail = false
                            }
                        }
                    )
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .onChange(of: isShowingDetail) { _, newValue in
            isZooming = newValue
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }
    
    // MARK: - Thumbnail View
    @ViewBuilder
    private func thumbnailView(wallpaper: Wallpaper, image: UIImage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !isShowingDetail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .matchedGeometryEffect(id: "heroImage", in: namespace)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isShowingDetail = true
                            }
                        }
                } else {
                    Color.clear.aspectRatio(0.75, contentMode: .fit)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(wallpaper.name ?? "Untitled")
                        .font(.basaltH2Serif)
                        .foregroundColor(.basaltTextPrimary)
                    
                    if let meta = metadata(for: wallpaper), !meta.isEmpty {
                        Text(meta)
                            .font(.basaltH3)
                            .foregroundColor(.basaltTextSecondary)
                    }
                    
                    if let desc = wallpaper.description {
                        Text(desc)
                            .font(.basaltMedium)
                            .foregroundColor(.basaltTextPrimary.opacity(0.9))
                            .lineSpacing(6)
                            .padding(.top, 24)
                    }
                    actionButtons(for: wallpaper)
                    downloadStatusMessage()
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh() }
    }
    
    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.basaltTextPrimary)
            Button("Retry") { Task { await viewModel.refresh() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private func metadata(for wallpaper: Wallpaper) -> String? {
        [wallpaper.artist, wallpaper.creationDate].compactMap { $0 }.joined(separator: ", ")
    }
    
    @ViewBuilder
    private func actionButtons(for wallpaper: Wallpaper) -> some View {
        HStack(spacing: 18) {
            Button {
                presentShareSheet(for: wallpaper)
            } label: {
                actionIcon(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            
            Button {
                downloadWallpaper(wallpaper)
            } label: {
                ZStack {
                    actionIcon(systemName: "arrow.down.circle")
                        .opacity(downloadState == .downloading ? 0.3 : 1)
                    if downloadState == .downloading {
                        ProgressView()
                            .tint(.basaltTextPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(downloadState == .downloading)
        }
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private func downloadStatusMessage() -> some View {
        switch downloadState {
        case .success:
            Text("Saved to Photos")
                .font(.basaltCaption)
                .foregroundColor(.basaltTextSecondary)
                .padding(.top, 8)
        case .error(let message):
            Text(message)
                .font(.basaltCaption)
                .foregroundColor(.red)
                .padding(.top, 8)
        default:
            EmptyView()
        }
    }
    
    private func actionIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(.basaltTextPrimary)
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .stroke(Color.basaltTextPrimary.opacity(0.3), lineWidth: 1)
            )
    }
    
    private func presentShareSheet(for wallpaper: Wallpaper) {
        guard let url = URL(string: "https://basalt.yevgenglukhov.com/art/\(wallpaper.id)") else { return }
        shareURL = url
        isShowingShareSheet = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    
    private func downloadWallpaper(_ wallpaper: Wallpaper) {
        guard downloadState != .downloading else { return }
        downloadState = .downloading
        let downloadURLString = CloudflareImageService.downloadURL(from: wallpaper.url)
        guard let url = URL(string: downloadURLString) else {
            downloadState = .error("Invalid download link")
            return
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    await MainActor.run {
                        downloadState = .error("Image data corrupted")
                    }
                    return
                }
                let imageSaver = ImageSaver()
                imageSaver.successHandler = {
                    DispatchQueue.main.async {
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                        downloadState = .success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            downloadState = .idle
                        }
                    }
                }
                imageSaver.errorHandler = { error in
                    DispatchQueue.main.async {
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        #endif
                        downloadState = .error(error.localizedDescription)
                    }
                }
                imageSaver.writeToPhotoAlbum(image: image)
            } catch {
                await MainActor.run {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                    downloadState = .error("Download failed")
                }
            }
        }
    }
    
    private enum DownloadState: Equatable {
        case idle
        case downloading
        case success
        case error(String)
    }
}

// MARK: - Image Detail View
struct ImageDetailView: View {
    let image: UIImage
    let namespace: Namespace.ID
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .opacity(1 - min(abs(dragOffset.height) / 300.0, 0.5))
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .matchedGeometryEffect(id: "heroImage", in: namespace)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dragOffset.height)
                    .gesture(magnificationGesture)
                    .simultaneousGesture(dragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if scale > 1.5 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
                
                VStack {
                    HStack {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                }
                .opacity(1 - min(abs(dragOffset.height) / 200.0, 1))
            }
        }
        .onTapGesture { onDismiss() }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.25)) {
                    if scale < 1.1 {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = max(1, min(scale, 4))
                        lastScale = scale
                    }
                }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale <= 1.1 { state = value.translation }
            }
            .onChanged { value in
                if scale > 1.1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { value in
                if scale > 1.1 {
                    lastOffset = offset
                } else if abs(value.translation.height) > 100 {
                    onDismiss()
                }
            }
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

#Preview {
    TodayView(isZooming: .constant(false), viewModel: TodayViewModel())
}
