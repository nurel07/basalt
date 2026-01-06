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
    
    var body: some View {
        GeometryReader { geo in
            NavigationView {
                Group {
                    if isLoading {
                        ProgressView("Loading collections...")
                            .controlSize(.large)
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
                                        NavigationLink(destination: CollectionDetailView(collectionId: item.collection.id)) {
                                            CollectionCard(collection: item.collection)
                                                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.85)
                                                .scrollTransition { content, phase in
                                                    content
                                                        .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                                        .opacity(phase.isIdentity ? 1.0 : 0.8)
                                                }
                                                .padding(.vertical, (geo.size.height * 0.01) / 2)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .id(item.id) // Important for ScrollViewReader
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                            .contentMargins(.vertical, (geo.size.height * (1.0 - 0.75)) / 2, for: .scrollContent)
                            .scrollIndicators(.hidden) // Hide scrollbar for cleaner look
                            .onAppear {
                                // Scroll to the middle when data is ready
                                if !infiniteCollections.isEmpty {
                                    let middleIndex = infiniteCollections.count / 2
                                    // Use a slight delay to ensure layout is ready
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(infiniteCollections[middleIndex].id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationBarHidden(true) // Hide Navigation Bar
                .ignoresSafeArea() // Go full screen
                .background(Color.black)
                .preferredColorScheme(.dark)
            }
        }
        .task {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                collections = try await APIService.shared.fetchCollections()
                prepareInfiniteList()
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = "Failed to load collections: \(error.localizedDescription)"
            }
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
                    url: URL(string: collection.coverImage) ?? URL(fileURLWithPath: ""),
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(collection.wallpaperCount) Items")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
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
