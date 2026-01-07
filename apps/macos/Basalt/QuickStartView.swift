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
                        videoFilename: "quickstart-01"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 2: No Algorithm
                    QuickStartSlide(
                        isActive: currentTab == 1,
                        imageColor: brandOrange,
                        title: "No Algorithm. Just Taste.",
                        description: "Every image is chosen, not scraped. No algorithm dumps. No random noise. Just bold, display-worthy art — selected to actually look good on your Mac.",
                        videoFilename: "quickstart-02"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 3: Human & AI
                    QuickStartSlide(
                        isActive: currentTab == 2,
                        imageColor: brandOrange,
                        title: "Human & AI",
                        description: "Two channels. Your call. Classic masterworks or AI-generated visions — mix them, switch between them, or pick a side. You're in control.",
                        videoFilename: "quickstart-03"
                    )
                    .frame(width: geo.size.width)
                    
                    // Slide 4: New Day, New Art
                    QuickStartSlide(
                        isActive: currentTab == 3,
                        imageColor: brandOrange,
                        title: "New Day, New Art",
                        description: "Fresh art at sunrise. Or right now. A new wallpaper lands every morning. Can't wait? Hit \"Surprise Me\" and pull something unexpected from the vault.",
                        videoFilename: "quickstart-04"
                    )
                    .frame(width: geo.size.width)
                }
                .offset(x: -CGFloat(currentTab) * geo.size.width)
                .animation(.easeInOut(duration: 0.3), value: currentTab)
            }
            .padding(.bottom, 20)
            

            // Footer Controls
            HStack {
                // Previous Button
                if currentTab > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentTab -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .regular))
                } else {
                    Text("Previous")
                    .foregroundColor(.clear) // Spacer
                    .hidden()
                    
                }
                
                Spacer()
                
                // Page Indicator
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentTab == index ? Color.secondary : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Next / Done Button
                if currentTab < 3 {
                    Button("Next") {
                        withAnimation {
                            currentTab += 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.system(size: 15, weight: .medium))
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
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .font(.system(size: 15, weight: .medium))
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
    
    // Custom background for video #E6E3DF
    let videoBackgroundColor = Color(red: 230/255, green: 227/255, blue: 223/255)
    
    var body: some View {
        VStack(spacing: 40) {
            // Media Box
            // Media Box
            Group {
                // FORCE SINGLE PLAYER INSTANCE:
                // Only instantiate the heavyweight LoopPlayerView if this slide is actually active.
                // This prevents creating 4 invisible AVPlayerLayers that hog GPU resources.
                if let videoName = videoFilename, isActive {
                    LoopPlayerView(filename: videoName, isPlaying: true)
                        .background(videoBackgroundColor) // Apply custom background here
                        .transition(.identity) 
                } else {
                    // Fallback for inactive slides (or if no video)
                    // This is just a lightweight vector shape.
                    Rectangle()
                        .fill(videoFilename != nil ? videoBackgroundColor : imageColor) // And here for consistency
                }
            }
            .frame(width: 474, height: 268)
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
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        // We do not set self.layer here immediately if we want to override makeBackingLayer,
        // but for AVPlayerLayer as backing, we can just set it.
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Use AVPlayerLayer as the backing layer
    override func makeBackingLayer() -> CALayer {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        return playerLayer
    }
    
    var playerLayer: AVPlayerLayer? {
        return self.layer as? AVPlayerLayer
    }
}

// Update LoopPlayerView to use this simplified view
struct LoopPlayerView: NSViewRepresentable {
    let filename: String
    let isPlaying: Bool
    
    func makeNSView(context: Context) -> some NSView {
        let view = PlayerNSView()
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        guard let view = nsView as? PlayerNSView, let layer = view.playerLayer else { return }
        
        if isPlaying {
            // Attach player using Strict Shared Manager
            if layer.player == nil {
                // Async to let layout settle
                DispatchQueue.main.async {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    
                    if isPlaying && layer.player == nil {
                       SharedVideoManager.shared.attach(playerTo: layer, for: filename)
                    }
                    
                    CATransaction.commit()
                }
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
        }
    }
}

class SharedVideoManager {
    static let shared = SharedVideoManager()
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var currentFilename: String?
    private weak var attachedLayer: AVPlayerLayer? 
    
    func getPlayer(for filename: String) -> AVQueuePlayer {
        if let player = player, currentFilename == filename {
            return player
        }
        
        // Clean up any existing player
        hardReset()
        
        // Optimization: Copy to Temp to avoid Sandbox/Bundle access issues
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).mp4")
        try? FileManager.default.removeItem(at: tempUrl)
        
        if let bundleUrl = Bundle.main.url(forResource: filename, withExtension: "mp4") {
            try? FileManager.default.copyItem(at: bundleUrl, to: tempUrl)
            print("✅ SharedVideoManager: Copied to temp for looping: \(tempUrl.path)")
            
            let item = AVPlayerItem(url: tempUrl)
            
            // Use AVQueuePlayer + AVPlayerLooper for robust system-managed looping
            let newPlayer = AVQueuePlayer(playerItem: item)
            newPlayer.isMuted = true
            newPlayer.actionAtItemEnd = .none // Important for Looper
            
            // Create Looper
            playerLooper = AVPlayerLooper(player: newPlayer, templateItem: item)
            
            self.player = newPlayer
            self.currentFilename = filename
            return newPlayer
        } 
        
        return AVQueuePlayer()
    }
    
    func attach(playerTo layer: AVPlayerLayer, for filename: String) {
        let player = getPlayer(for: filename)
        
        // Strict Check: If this layer already has this player, do nothing
        if layer.player == player { return }
        
        // Detach from previous layer
        if let previous = attachedLayer, previous != layer {
            previous.player = nil
        }
        
        layer.player = player
        attachedLayer = layer
        
        if player.rate == 0 { player.play() }
    }
    
    func play() { player?.play() }
    
    // Completely stop and reset the player
    func hardReset() {
        print("🛑 SharedVideoManager: Hard Reset")
        player?.pause()
        player?.removeAllItems()
        player = nil
        playerLooper?.disableLooping() 
        playerLooper = nil
        currentFilename = nil
        attachedLayer?.player = nil
        attachedLayer = nil
    }
}

struct QuickStartView_Previews: PreviewProvider {
    static var previews: some View {
        QuickStartView()
    }
}
