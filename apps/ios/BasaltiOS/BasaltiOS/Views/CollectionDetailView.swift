import SwiftUI

struct CollectionDetailView: View {
    let collectionId: String
    @State private var collection: Collection?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else if let errorMessage = errorMessage {
                     VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                        Button("Retry") {
                            loadData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let wallpapers = collection?.wallpapers, !wallpapers.isEmpty {
                    // Filter out cover (order 0 or name contains 'cover') and sort
                    let displayWallpapers = wallpapers
                        .filter { $0.collectionOrder > 0 && !($0.name?.lowercased().contains("cover") ?? false) }
                        .sorted { $0.collectionOrder < $1.collectionOrder }
                    let infiniteWallpapers = createInfiniteList(from: displayWallpapers)
                    
                    if infiniteWallpapers.isEmpty {
                        Text("No wallpapers to display")
                            .foregroundColor(.white)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(infiniteWallpapers) { item in
                                        WallpaperCard(wallpaper: item.wallpaper)
                                            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.85)
                                            .scrollTransition { content, phase in
                                                content
                                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.9)
                                                    .opacity(phase.isIdentity ? 1.0 : 0.8)
                                            }
                                            .padding(.vertical, (geo.size.height * 0.01) / 2)
                                            .id(item.id)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                            .contentMargins(.vertical, (geo.size.height * (1.0 - 0.86)) / 2, for: .scrollContent)
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
                    }
                } else {
                    Text("No wallpapers found")
                        .foregroundColor(.white)
                }
                
                // Back Button Overlay
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(collection?.name ?? "Collection")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8) // adjust for safe area
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .task {
            loadData()
        }
        .navigationBarHidden(true)
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                collection = try await APIService.shared.fetchCollection(id: collectionId)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Failed to load: \(error.localizedDescription)"
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
    
    var body: some View {
        GeometryReader { cardGeo in
            ZStack(alignment: .bottom) {
                // Image Layer with Parallax
                // Image Layer with Parallax
                CachedAsyncImage(
                    url: URL(string: wallpaper.url) ?? URL(fileURLWithPath: ""),
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
                            .frame(width: cardGeo.size.width, height: cardGeo.size.height * 1.2) // Extra height for parallax
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
                
                // Footer
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wallpaper.name ?? "Untitled")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let artist = wallpaper.artist {
                            Text(artist)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Download Button
                    Button {
                        downloadOriginalImage()
                    } label: {
                        Image(systemName: "arrow.down.to.line") // Matches screenshot better
                            .font(.system(size: 24, weight: .regular)) // Slightly larger, thinner
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.4))
                .scrollTransition { content, phase in
                    content.opacity(phase.isIdentity ? 1.0 : 0.0)
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
        guard let url = URL(string: wallpaper.url) else { return }
        
        // Use a background task to download
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    let imageSaver = ImageSaver()
                    imageSaver.writeToPhotoAlbum(image: image)
                    
                    // Optional: Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                print("Download failed: \(error.localizedDescription)")
            }
        }
    }
}

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save error: \(error.localizedDescription)")
        } else {
            print("Save finished!")
        }
    }
}

#Preview {
    // Preview with a sample collection ID
    CollectionDetailView(collectionId: "sample-id")
}
