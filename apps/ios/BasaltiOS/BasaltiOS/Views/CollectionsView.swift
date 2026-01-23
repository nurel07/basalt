import SwiftUI

// Wrapper to make collections unique in the infinite list
struct InfiniteCollection: Identifiable {
    let id = UUID()
    let collection: Collection
}

struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var infiniteCollections: [InfiniteCollection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scrolledID: UUID?
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if isLoading {
                    ProgressView("Loading collections...")
                        .controlSize(.large)
                        .tint(.basaltTextPrimary)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(infiniteCollections) { item in
                                    NavigationLink(value: item.collection) {
                                        CollectionCard(collection: item.collection)
                                            .frame(width: geo.size.width * 0.95, height: geo.size.height * 0.95)
                                            .scrollTransition { content, phase in
                                                content
                                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                                    .opacity(phase.isIdentity ? 1.0 : 0.8)
                                            }
                                            .padding(.vertical, (geo.size.height * 0.01) / 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .id(item.id)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: $scrolledID)
                        .onChange(of: scrolledID) { _, _ in
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                        .contentMargins(.vertical, (geo.size.height * (1.0 - 0.8)) / 2, for: .scrollContent)
                        .scrollIndicators(.hidden)
                        .onAppear {
                            if !infiniteCollections.isEmpty {
                                let middleIndex = infiniteCollections.count / 2
                                DispatchQueue.main.async {
                                    proxy.scrollTo(infiniteCollections[middleIndex].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .background(Color.basaltBackgroundPrimary)
        }
        .task {
            loadData()
        }
    }
    
    private func loadData() {
        if collections.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        Task {
            do {
                // 1. Fetch lightweight summaries (fast)
                let summaries = try await APIService.shared.fetchCollections()
                
                // 2. Render immediately
                if collections.isEmpty {
                    collections = summaries
                    prepareInfiniteList()
                }
                isLoading = false
                
                // 3. Background: Fetch full details for each collection (to get wallpapers list)
                await prefetchDetails(for: summaries)
                
            } catch {
                isLoading = false
                errorMessage = "Failed to load collections: \(error.localizedDescription)"
            }
        }
    }
    
    private func prefetchDetails(for summaries: [Collection]) async {
        // Fetch full details for each collection in parallel-ish
        await withTaskGroup(of: Collection?.self) { group in
            for summary in summaries {
                group.addTask {
                    try? await APIService.shared.fetchCollection(id: summary.id)
                }
            }
            
            var fullCollections: [Collection] = []
            for await result in group {
                if let col = result {
                    fullCollections.append(col)
                }
            }
            
            // Re-sort to match original order (assuming summaries order is preferred)
            // Or just replace ones found.
            // Let's rely on ID matching to update the source truth.
            
            // Update Main List on Main Actor
            if !fullCollections.isEmpty {
                await MainActor.run {
                    // Update main list with full objects, respecting original server order (summaries)
                    // The backend returns collections sorted by `order` ASC, then `name` ASC.
                    // We must preserve the order of `summaries`.
                    let ordered = summaries.compactMap { summary in
                        fullCollections.first(where: { $0.id == summary.id }) ?? summary
                    }
                    self.collections = ordered
                    prepareInfiniteList() // Re-generate infinite list with populated objects
                    
                    // 4. Prefetch Images (First 3 of each collection)
                    for col in ordered {
                         if let wallpapers = col.wallpapers?.prefix(3) {
                             prefetchImages(urls: wallpapers.map { $0.url })
                         }
                    }
                }
            }
        }
    }
    
    // Simple URLSession prefetch to warm disk/network cache
    private func prefetchImages(urls: [String]) {
        for urlString in urls {
             guard let url = URL(string: CloudflareImageService.displayURL(from: urlString)) else { continue }
             URLSession.shared.dataTask(with: url).resume()
        }
    }
    
    private func prepareInfiniteList() {
        guard !collections.isEmpty else { return }
        
        // Create a massive list (e.g., 1000 loops)
        var temp: [InfiniteCollection] = []
        for _ in 0..<1000 {
            for col in collections {
                temp.append(InfiniteCollection(collection: col))
            }
        }
        infiniteCollections = temp
    }
}

struct CollectionCard: View {
    let collection: Collection
    
    var body: some View {
        GeometryReader { cardGeo in
            ZStack(alignment: .bottom) {
                // Background Image with Parallax
                // Background Image with Parallax
                CachedAsyncImage(
                    url: URL(string: CloudflareImageService.displayURL(from: collection.coverImage)) ?? URL(fileURLWithPath: ""),
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
                
                // Footer Content
                HStack {
                    Text("Free Collection")
                        .font(.basaltSmallEmphasized) // "Free Collection" -> Small Emphasized (14, 600)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(collection.wallpaperCount) Items")
                        .font(.basaltSmall) // "Items" -> Small (14, 400)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(24)
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
            .frame(width: cardGeo.size.width, height: cardGeo.size.height)
        }
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(radius: 8)
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}

#Preview {
    CollectionsView()
}
