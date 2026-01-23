import SwiftUI
import AVKit

struct QuickStartView: View {
    @State private var currentTab = 0
    @Environment(\.dismiss) var dismiss
    
    // Orange color from the mockup
    let brandOrange = Color(red: 236/255, green: 104/255, blue: 59/255)
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Content
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Slide 1: Welcome to Basalt
                    QuickStartSlide(
                        isActive: currentTab == 0,
                        imageColor: brandOrange,
                        title: "Welcome to Basalt",
                        description: "Your desktop is a gallery waiting to happen. Basalt delivers hand-picked art to your screen — fresh every morning. No more staring at the same stock mountain.",
                        videoFilename: "quickstart-01",
                        fallbackImage: "quickstart-01-fallback"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 2: No Algorithm
                    QuickStartSlide(
                        isActive: currentTab == 1,
                        imageColor: brandOrange,
                        title: "No Algorithm. Just Taste.",
                        description: "Every image is chosen, not scraped. No algorithm dumps. No random noise. Just bold, display-worthy art — selected to actually look good on your Mac.",
                        videoFilename: "quickstart-02",
                        fallbackImage: "quickstart-02-fallback"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 3: Human & AI
                    QuickStartSlide(
                        isActive: currentTab == 2,
                        imageColor: brandOrange,
                        title: "Human & AI",
                        description: "Two channels. Your call. Classic masterworks or AI-generated visions — mix them, switch between them, or pick a side. You're in control.",
                        videoFilename: "quickstart-03",
                        fallbackImage: "quickstart-03-fallback"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 4: New Day, New Art
                    QuickStartSlide(
                        isActive: currentTab == 3,
                        imageColor: brandOrange,
                        title: "New Day, New Art",
                        description: "Fresh art at sunrise. Or right now. A new wallpaper lands every morning. Can't wait? Hit \"Surprise Me\" and pull something unexpected from the vault.",
                        videoFilename: "quickstart-04",
                        fallbackImage: "quickstart-04-fallback"
                    )
                    .frame(width: geo.size.width)
                }
                .offset(x: -CGFloat(currentTab) * geo.size.width)
                .animation(.easeInOut(duration: 0.3), value: currentTab)
            }
            .padding(.bottom, 20)
            

            // Footer Controls
            ZStack {
                // Page Indicator (Centered)
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentTab == index ? Color.secondary : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Navigation Buttons (Edges)
                HStack {
                    // Previous Button
                    if currentTab > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentTab -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Spacer()
                    
                    // Next / Done Button
                    if currentTab < 3 {
                        Button("Next") {
                            withAnimation {
                                currentTab += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Done") {
                            dismiss()
                            // Fallback for NSHostingController usage
                            DispatchQueue.main.async {
                                if let window = NSApp.windows.first(where: { $0.contentView?.frame.height == 580 && $0.contentView?.frame.width == 522 }) {
                                    window.close()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 522, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .onDisappear {
            SharedVideoManager.shared.hardReset()
        }
    }
}

struct QuickStartSlide: View {
    let isActive: Bool
    let imageColor: Color
    let title: String
    let description: String
    var videoFilename: String? = nil
    var fallbackImage: String? = nil
    
    // Custom background for video #E6E3DF
    let videoBackgroundColor = Color(red: 230/255, green: 227/255, blue: 223/255)
    
    var body: some View {
        VStack(spacing: 40) {
            // Media Box
            Group {
                // FORCE SINGLE PLAYER INSTANCE:
                // Only instantiate the heavyweight LoopPlayerView if this slide is actually active.
                // This prevents creating 4 invisible AVPlayerLayers that hog GPU resources.
                if let videoName = videoFilename, isActive {
                    LoopPlayerView(
                        filename: videoName,
                        isPlaying: true,
                        fallbackImage: fallbackImage
                    )
                    .background(videoBackgroundColor)
                    .transition(.identity) 
                } else if let fallback = fallbackImage, let image = Bundle.main.image(forResource: fallback) {
                    // Show fallback image for inactive slides that have one
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback for inactive slides (or if no video/image)
                    // This is just a lightweight vector shape.
                    Rectangle()
                        .fill(videoFilename != nil ? videoBackgroundColor : imageColor)
                }
            }
            .frame(width: 474, height: 268)
            .clipped()
            .cornerRadius(12)
            
            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
    }
}

class PlayerNSView: NSView {
    
    // Background color to show while video loads (matches videoBackgroundColor: #E6E3DF)
    private let loadingBackgroundColor = NSColor(red: 230/255, green: 227/255, blue: 223/255, alpha: 1.0)
    
    // Fallback image layer (shown if video fails to load)
    private var fallbackImageLayer: CALayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Use AVPlayerLayer as the backing layer
    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        // Set background color so it's visible while video loads
        playerLayer.backgroundColor = loadingBackgroundColor.cgColor
        return playerLayer
    }
    
    var playerLayer: AVPlayerLayer? {
        return self.layer as? AVPlayerLayer
    }
    
    // Show fallback image if video fails
    func showFallbackImage(named imageName: String) {
        // Use Bundle.main.image(forResource:) to load .jpg from Resources folder
        guard let image = Bundle.main.image(forResource: imageName) else { return }
        
        // Remove existing fallback layer if any
        fallbackImageLayer?.removeFromSuperlayer()
        
        // Create image layer
        let imageLayer = CALayer()
        imageLayer.contents = image
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.frame = self.bounds
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // Add on top of player layer
        self.layer?.addSublayer(imageLayer)
        fallbackImageLayer = imageLayer
    }
    
    // Hide fallback image (video is playing successfully)
    func hideFallbackImage() {
        fallbackImageLayer?.removeFromSuperlayer()
        fallbackImageLayer = nil
    }
}

// Update LoopPlayerView to use this simplified view
struct LoopPlayerView: NSViewRepresentable {
    let filename: String
    let isPlaying: Bool
    var fallbackImage: String? = nil
    
    func makeNSView(context: Context) -> some NSView {
        let view = PlayerNSView()
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let view = nsView as? PlayerNSView, let layer = view.playerLayer else { return }
        
        if isPlaying {
            // Attach player immediately using Strict Shared Manager
            // No async delay - we're already on main thread and the layer has a background color
            if layer.player == nil {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                
                let success = SharedVideoManager.shared.attach(playerTo: layer, for: filename)
                
                // If video failed to load, show fallback image
                if !success, let fallbackName = fallbackImage {
                    view.showFallbackImage(named: fallbackName)
                } else {
                    view.hideFallbackImage()
                }
                
                CATransaction.commit()
            }
        } else {
            // Detach
            if layer.player != nil {
                layer.player = nil
            }
        }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let playerView = nsView as? PlayerNSView {
            playerView.playerLayer?.player = nil
            playerView.hideFallbackImage()
        }
    }
}


class SharedVideoManager {
    static let shared = SharedVideoManager()
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentFilename: String?
    private weak var attachedLayer: AVPlayerLayer?
    private var videoLoadedSuccessfully: Bool = false
    
    /// Returns the player for the given filename. Also sets `videoLoadedSuccessfully`.
    private func getPlayer(for filename: String) -> AVQueuePlayer {
        if let player = player, currentFilename == filename {
            return player
        }
        
        // Clean up any existing player
        hardReset()
        
        // Optimization: Copy to Temp to avoid Sandbox/Bundle access issues
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).mp4")
        try? FileManager.default.removeItem(at: tempUrl)
        
        if let bundleUrl = Bundle.main.url(forResource: filename, withExtension: "mp4") {
            do {
                try FileManager.default.copyItem(at: bundleUrl, to: tempUrl)
                #if DEBUG
                print("✅ SharedVideoManager: Copied to temp for looping: \(tempUrl.path)")
                #endif
                
                let item = AVPlayerItem(url: tempUrl)
                
                // Use AVQueuePlayer + AVPlayerLooper for robust system-managed looping
                let newPlayer = AVQueuePlayer(playerItem: item)
                newPlayer.isMuted = true
                newPlayer.actionAtItemEnd = .none // Important for Looper
                
                // Create Looper
                playerLooper = AVPlayerLooper(player: newPlayer, templateItem: item)
                
                self.player = newPlayer
                self.currentFilename = filename
                self.videoLoadedSuccessfully = true
                return newPlayer
            } catch {
                #if DEBUG
                print("❌ SharedVideoManager: Failed to copy video: \(error)")
                #endif
                self.videoLoadedSuccessfully = false
            }
        } else {
            #if DEBUG
            print("❌ SharedVideoManager: Video not found in bundle: \(filename).mp4")
            #endif
            self.videoLoadedSuccessfully = false
        }
        
        return AVQueuePlayer()
    }
    
    /// Attaches player to layer. Returns `true` if video loaded successfully, `false` if fallback should be shown.
    @discardableResult
    func attach(playerTo layer: AVPlayerLayer, for filename: String) -> Bool {
        let player = getPlayer(for: filename)
        
        // Strict Check: If this layer already has this player, do nothing
        if layer.player == player { return videoLoadedSuccessfully }
        
        // Detach from previous layer
        if let previous = attachedLayer, previous != layer {
            previous.player = nil
        }
        
        layer.player = player
        attachedLayer = layer
        
        if player.rate == 0 { player.play() }
        
        return videoLoadedSuccessfully
    }
    
    func play() { player?.play() }
    
    // Completely stop and reset the player
    func hardReset() {
        #if DEBUG
        print("🛑 SharedVideoManager: Hard Reset")
        #endif
        player?.pause()
        player?.removeAllItems()
        player = nil
        playerLooper?.disableLooping() 
        playerLooper = nil
        currentFilename = nil
        attachedLayer?.player = nil
        attachedLayer = nil
        videoLoadedSuccessfully = false
    }
}

struct QuickStartView_Previews: PreviewProvider {
    static var previews: some View {
        QuickStartView()
    }
}
