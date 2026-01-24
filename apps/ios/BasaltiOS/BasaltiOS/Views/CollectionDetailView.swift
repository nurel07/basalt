import SwiftUI

struct CollectionDetailView: View {
    let initialCollection: Collection
    @State private var collection: Collection?
    @State private var infiniteWallpapers: [InfiniteWallpaper] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scrolledWallpaperID: UUID?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.basaltTextPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.basaltBackgroundPrimary)
                } else if let errorMessage = errorMessage {
                    ZStack {
                        Color.basaltBackgroundPrimary.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.basaltTextPrimary)
                            Button("Retry") {
                                loadData()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else if !infiniteWallpapers.isEmpty {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(infiniteWallpapers) { item in
                                        VStack {
                                            WallpaperCard(
                                                wallpaper: item.wallpaper,
                                                showMetadata: (collection?.channel ?? initialCollection.channel) != "AI"
                                            )
                                                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.9)
                                                .scrollTransition { content, phase in
                                                    content
                                                        .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                                        .opacity(phase.isIdentity ? 1.0 : 0.8)
                                                }
                                                .padding(.vertical, (geo.size.height * 0.01) / 2.5)
                                        }
                                        .id(item.id)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                            .scrollPosition(id: $scrolledWallpaperID)
                            .onChange(of: scrolledWallpaperID) { _, _ in
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                            .contentMargins(.vertical, (geo.size.height * (1.0 - 0.8)) / 2, for: .scrollContent)
                            .scrollIndicators(.hidden)
                            .onAppear {
                                if !infiniteWallpapers.isEmpty {
                                    let middleIndex = infiniteWallpapers.count / 2
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(infiniteWallpapers[middleIndex].id, anchor: .center)
                                    }
                                }
                            }
                        }
                        .background(Color.basaltBackgroundPrimary)
                } else {
                    ZStack {
                        Color.basaltBackgroundPrimary.ignoresSafeArea()
                        Text("No wallpapers found")
                            .foregroundColor(.basaltTextPrimary)
                    }
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                // Custom navigation bar with glassEffect
                ZStack {
                    // Centered title pill - hugs text
                    Text(collection?.name ?? initialCollection.name)
                        .font(.basaltMediumEmphasized) // "Title" -> Medium Emphasized (16, 600)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .basaltGlass()
                    
                    // Back button on the left
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .basaltGlass()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 0) // Below status bar
            }
        }
        .navigationBarHidden(true)
        .task {
            loadData()
        }
    }
    
    private func loadData() {
        // Instant load if data passed
        if let wallpapers = initialCollection.wallpapers, !wallpapers.isEmpty {
            prepareData(with: initialCollection)
            isLoading = false
            return
        }
        
        // Otherwise load
        if infiniteWallpapers.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        Task {
            do {
                let fetchedCollection = try await APIService.shared.fetchCollection(id: initialCollection.id)
                prepareData(with: fetchedCollection)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Failed to load: \(error.localizedDescription)"
            }
        }
    }
    
    private func prepareData(with col: Collection) {
        self.collection = col
        if let wallpapers = col.wallpapers, !wallpapers.isEmpty {
            let displayWallpapers = wallpapers
                .filter { $0.collectionOrder > 0 && !($0.name?.lowercased().contains("cover") ?? false) }
                .sorted { $0.collectionOrder < $1.collectionOrder }
            
            // Avoid regenerating infinite list if it's already the same (simple check)
            if infiniteWallpapers.isEmpty {
                infiniteWallpapers = createInfiniteList(from: displayWallpapers)
            }
            
            prefetchImages(wallpapers: displayWallpapers, count: 3)
        }
    }
    
    private func prefetchImages(wallpapers: [Wallpaper], count: Int) {
        let toPrefetch = wallpapers.prefix(count)
        for wallpaper in toPrefetch {
            guard let url = URL(string: CloudflareImageService.displayURL(from: wallpaper.url)) else { continue }
            // Start loading in background - data gets cached by URLSession
            Task.detached(priority: .userInitiated) {
                do {
                    let (_, _) = try await URLSession.shared.data(from: url)
                } catch {
                    // Silently ignore prefetch errors
                }
            }
        }
    }
    
    private func createInfiniteList(from wallpapers: [Wallpaper]) -> [InfiniteWallpaper] {
        guard !wallpapers.isEmpty else { return [] }
        var result: [InfiniteWallpaper] = []
        for _ in 0..<1000 {
            for wallpaper in wallpapers {
                result.append(InfiniteWallpaper(wallpaper: wallpaper))
            }
        }
        return result
    }
}

// Wrapper for infinite scroll
struct InfiniteWallpaper: Identifiable {
    let id = UUID()
    let wallpaper: Wallpaper
}

struct WallpaperCard: View {
    let wallpaper: Wallpaper
    var showMetadata: Bool = true
    @State private var showDownloadPrompt = false
    @State private var downloadState: DownloadState = .idle

    @State private var dismissTask: DispatchWorkItem?
    enum DownloadState {
        case idle
        case downloading
        case saved
        case openImage
    }
    
    var body: some View {
        GeometryReader { cardGeo in
            ZStack {
                // Image Layer
                CachedAsyncImage(
                    url: URL(string: CloudflareImageService.displayURL(from: wallpaper.url)) ?? URL(fileURLWithPath: ""),
                    targetSize: CGSize(width: cardGeo.size.width, height: cardGeo.size.height * 1.2)
                ) { phase in
                    switch phase {
                    case .empty:
                        Color(uiColor: .systemGray6)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardGeo.size.width, height: cardGeo.size.height * 1.2)
                            .visualEffect { content, geometryProxy in
                                content.offset(y: -geometryProxy.frame(in: .global).minY * 0.25)
                            }
                    case .failure:
                        Color.gray
                            .overlay(Image(systemName: "photo.fill"))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: cardGeo.size.width, height: cardGeo.size.height)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        showDownloadPrompt.toggle()
                    }
                }
                
                
                
                // Footer
                VStack {
                    Spacer()
                    HStack(alignment: .center) {
                        if showMetadata {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(wallpaper.name ?? "Untitled")
                                    .font(.basaltSmallEmphasized) // "Name" -> Small Emphasized (14, 600) (or maybe medium?)
                                    // Matches Collections footer style
                                    .foregroundColor(.white)
                                
                                // Subtitle: "Artist, Year" or just "Artist" or just "Year"
                                let subtitleParts = [wallpaper.artist, wallpaper.creationDate]
                                    .compactMap { $0 }
                                    .filter { !$0.isEmpty }
                                
                                if !subtitleParts.isEmpty {
                                    Text(subtitleParts.joined(separator: ", "))
                                        .font(.basaltCaption) // "Caption" -> Caption (11, 400)? Or Footnote (13)?
                                        // Original was .font(.caption).
                                        // Let's use basaltSmall (14) or create a smaller one?
                                        // Spec says "small" is 14.
                                        // Spec didn't define "caption".
                                        // I'll stick to .font(.caption) (11ish) OR define `basaltCaption`?
                                        // I defined `basaltSmall` (14).
                                        // I'll use `Font.caption` (System) or define one.
                                        // My `Font+Design.swift` defines `basaltSmall` as 14.
                                        // I DO NOT have "Caption" (11) in my extension yet. Let's add it or use system.
                                        // Wait, I didn't add basaltCaption in the file write step!
                                        // I only added Large, Medium, Small.
                                        // So I should use .font(.caption) OR add it.
                                        // I'll use .font(.system(size: 12)) or similar if I want to match visually.
                                        // Let's check `Font+Design.swift` again.
                                        // I wrote: Large(18), Medium(16), Small(14).
                                        // I missed Caption in that file.
                                        // I'll use .basaltSmall for now or stick to system .caption.
                                        // Let's us .basaltSmall (14) for readability or .caption.
                                        // I'll use .font(.system(size: 12)) for now to be safe or just keep .caption.
                                        // Let's use simple .font(.caption) for now as it's not strictly in "App" 6 rows.
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        } else {
                             Spacer()
                        }
                        
                        Spacer()
                        
                        // Download Button
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                showDownloadPrompt = true
                            }
                            downloadOriginalImage()
                        } label: {
                            Image("circle-arrow-down-c")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                                .padding(0)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.4), Color.black.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )

                    .scrollTransition { content, phase in
                        content.opacity(phase.isIdentity ? 1.0 : 0.0)
                    }
                }
                
                // Download Prompt Overlay
                if showDownloadPrompt {
                    Button {
                        if downloadState == .idle {
                            dismissTask?.cancel()
                            // Haptic: Light impact for initiating action
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            downloadOriginalImage()
                            // Do not close immediately, wait for completion
                        } else if downloadState == .saved || downloadState == .openImage {
                            // Haptic: Medium impact for opening external app
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            // Open Photos App
                            if let url = URL(string: "photos-redirect://") {
                                if UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            // Close prompt immediately if user clicks "Open Image" or "Saved"
                             withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                showDownloadPrompt = false
                                downloadState = .idle
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            if downloadState == .downloading {
                                ProgressView()
                                    .tint(.white)
                                Text("Downloading...")
                                    .font(.basaltSmallEmphasized)
                                    .foregroundColor(.white)
                            } else if downloadState == .saved {
                                Image("check-circle-c")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                    .foregroundColor(.white)
                                Text("Saved to Photos")
                                    .font(.basaltSmallEmphasized)
                                    .foregroundColor(.white)
                            } else if downloadState == .openImage {
                                Image("image-c") // Assuming 'image-c' is the asset name
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                Text("Open Image")
                                    .font(.basaltSmallEmphasized)
                                    .foregroundColor(.white)
                            } else {
                                Image("circle-arrow-down-c")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.white)
                                
                                Text("Download")
                                    .font(.basaltSmallEmphasized)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 40)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .basaltGlass(tint: .black.opacity(0.1))
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(100)
                    .onAppear {
                        // Auto-dismiss after 2 seconds if still idle
                        if downloadState == .idle {
                            dismissTask?.cancel()
                            let task = DispatchWorkItem {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    showDownloadPrompt = false
                                }
                            }
                            dismissTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
                        }
                    }
                }
            }
            .frame(width: cardGeo.size.width, height: cardGeo.size.height)
        }
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 8)
    }
    
    // Function to download the full resolution image
    private func downloadOriginalImage() {
        // Use Cloudflare flexible variant for original quality download
        let downloadURLString = CloudflareImageService.downloadURL(from: wallpaper.url)
        guard let url = URL(string: downloadURLString) else { return }
        
        withAnimation {
            downloadState = .downloading
        }
        
        // Use a background task to download
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    let imageSaver = ImageSaver()
                    
                    imageSaver.successHandler = {
                        DispatchQueue.main.async {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            withAnimation {
                                self.downloadState = .saved
                            }
                            
                            // 1. Saved State (already set)
                            
                            // 2. Change to Open Image after 2 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) {
                                    self.downloadState = .openImage
                                }
                                
                                // 3. Auto-close after another 4 seconds 
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        self.showDownloadPrompt = false
                                        // self.downloadState = .idle // Optional: reset only when showing prompt again?
                                    }
                                }
                            }
                        }
                    }
                    
                    imageSaver.errorHandler = { error in
                        print("Save error: \(error.localizedDescription)")
                         DispatchQueue.main.async {
                             withAnimation {
                                 // Revert to idle on error
                                 self.downloadState = .idle
                             }
                         }
                    }

                    imageSaver.writeToPhotoAlbum(image: image)
                }
            } catch {
                print("Download failed: \(error.localizedDescription)")
                withAnimation {
                    downloadState = .idle
                }
            }
        }
    }
}

class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save error: \(error.localizedDescription)")
            errorHandler?(error)
        } else {
            print("Save finished!")
            successHandler?()
        }
    }
}

#Preview {
    // Preview with a known valid collection ID (Impressionists)
    CollectionDetailView(initialCollection: Collection(
        id: "cmk4760ia0015pm3zjok7cwrr",
        name: "Impressionists",
        slug: "impressionists",
        description: "Focus on light and color",
        coverImage: "https://example.com/image.jpg",
        wallpaperCount: 10,
        order: 0,
        channel: "HUMAN",
        wallpapers: []
    ))
}
