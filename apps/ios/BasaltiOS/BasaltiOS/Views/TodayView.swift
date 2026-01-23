import SwiftUI
import Combine
import UIKit

// MARK: - ViewModel
@MainActor
class TodayViewModel: ObservableObject {
    @Published var wallpaper: Wallpaper?
    @Published var heroImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasLoaded = false
    
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        
        do {
            let wallpaper = try await APIService.shared.fetchTodayWallpaper()
            self.wallpaper = wallpaper
            
            // Preload image
            if let url = URL(string: CloudflareImageService.displayURL(from: wallpaper.url)) {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.heroImage = image
                }
            }
        } catch {
            errorMessage = "Failed to load today's selection."
        }
        isLoading = false
    }
    
    func refresh() async {
        isLoading = true
        // Keep existing data while refreshing if desired, or clear it
        // errorMessage = nil
        
        do {
            let wallpaper = try await APIService.shared.fetchTodayWallpaper()
            self.wallpaper = wallpaper
            
            if let url = URL(string: CloudflareImageService.displayURL(from: wallpaper.url)) {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.heroImage = image
                }
            }
        } catch {
            errorMessage = "Failed to load today's selection."
        }
        isLoading = false
    }
}

// MARK: - View
struct TodayView: View {
    @Binding var isZooming: Bool
    @ObservedObject var viewModel: TodayViewModel
    
    // Hero transition
    @Namespace private var namespace
    @State private var isShowingDetail = false
    
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

#Preview {
    TodayView(isZooming: .constant(false), viewModel: TodayViewModel())
}
