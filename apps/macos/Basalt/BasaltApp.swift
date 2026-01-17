import SwiftUI
import AppKit
import Combine
import Network
import ServiceManagement

// MARK: - 1. Constants & Configuration

enum Constants {
    static let baseUrl = "https://basalt-prod.up.railway.app/api/wallpapers"
    static let randomUrl = "https://basalt-prod.up.railway.app/api/wallpapers/random"
    static let websiteUrl = "https://basalt.yevgenglukhov.com/today"
    
    // Cloudinary
    static let uploadKeyword = "/upload/"
    static let maxResolution = 2560
    
    // Persistence Keys
    static let useSameWallpaperKey = "UseSameWallpaper"
    static let selectedChannelsKey = "SelectedChannels"
    static let fitVerticalKey = "FitVerticalDisplays"
    static let syncScreensaverKey = "SyncScreensaver"
    
    // Day Persistence Keys (Surprise Me)
    static let overrideWallpaperIdKey = "OverrideWallpaperId"
    static let overrideContextIdKey = "OverrideContextId"
    static let overrideWallpaperKey = "OverrideWallpaper" // Stores main surprise wallpaper
    
    // Daily State Persistence
    static let dailyStateKey = "DailyState"
    
    // Channels
    static let channelHuman = "HUMAN"
    static let channelAI = "AI"
    static let defaultChannels = [channelHuman, channelAI]
}

// MARK: - 2. Models

struct Wallpaper: Codable, Sendable {
    let id: String
    let url: String
    let name: String?
    let description: String?
    let externalUrl: String?
    let channel: String?
    let releaseDate: String?
    let artist: String?
    let creationDate: String?
}

struct ScreenWallpaperInfo: Identifiable {
    var id: String { displayName } // Stable ID
    let displayName: String
    let wallpaperName: String
    let url: URL?        // Generated Cloudinary URL
    let originalUrl: String // Raw DB URL
    let externalUrl: String?
}

struct DailyState: Codable, Sendable {
    let date: String // YYYY-MM-DD
    let mainWallpaper: Wallpaper
    var secondaryWallpapers: [Int: Wallpaper] // ScreenIndex -> Wallpaper
}

// MARK: - 3. Services

/// Monitors network connectivity
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

/// Handles all network API interactions
struct NetworkService {
    
    func fetchManifest(channels: Set<String>) async throws -> [Wallpaper] {
        var components = URLComponents(string: Constants.baseUrl)!
        var queryItems: [URLQueryItem] = []
        
        // Channel Logic
        let isAllSelected = channels.contains(Constants.channelHuman) && channels.contains(Constants.channelAI)
        
        if !channels.isEmpty && !isAllSelected {
            let joined = channels.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "channel", value: joined))
        }
        
        // Published Filter
        queryItems.append(URLQueryItem(name: "published", value: "true"))
        components.queryItems = queryItems
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Wallpaper].self, from: data)
    }
    
    func fetchRandom(channels: Set<String>) async throws -> Wallpaper {
        var components = URLComponents(string: Constants.randomUrl)!
        var queryItems: [URLQueryItem] = []
        
        // Channel Logic
        let isAllSelected = channels.contains(Constants.channelHuman) && channels.contains(Constants.channelAI)
        if !channels.isEmpty && !isAllSelected {
            let joined = channels.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "channel", value: joined))
        }
        
        // Filters & Cache Busting
        queryItems.append(URLQueryItem(name: "published", value: "true"))
        queryItems.append(URLQueryItem(name: "t", value: String(Date().timeIntervalSince1970)))
        
        components.queryItems = queryItems
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(Wallpaper.self, from: data)
    }
}

/// Handles URL modification and File System operations
struct ImageService {
    private let fileManager = FileManager.default
    
    /// Generates the Cloudinary URL with overlays and resizing
    func generateUrl(for wallpaper: Wallpaper, screen: NSScreen, fitToVertical: Bool) -> URL? {
        // 1. Calculate Resolution
        let rawWidth = Int(screen.frame.width * screen.backingScaleFactor)
        let rawHeight = Int(screen.frame.height * screen.backingScaleFactor)
        
        // Cap resolution (Fit within 2560x2560 bounding box)
        let maxRes = Double(Constants.maxResolution)
        var newWidth = Double(rawWidth)
        var newHeight = Double(rawHeight)
        
        let aspectRatio = newWidth / newHeight
        
        if newWidth > maxRes || newHeight > maxRes {
            if newWidth > newHeight {
                // Landscape-ish (or just wider)
                newWidth = maxRes
                newHeight = newWidth / aspectRatio
            } else {
                // Portrait-ish (or just taller)
                newHeight = maxRes
                newWidth = newHeight * aspectRatio
            }
        }
        
        // Ensure even dimensions (safe for most renderers)
        let width = Int(newWidth) / 2 * 2
        let height = Int(newHeight) / 2 * 2
        
        // 2. Text Content
        var textParts: [String] = []
        
        // Smart Overlay Logic based on Channel
        let isAI = (wallpaper.channel == Constants.channelAI)
        
        if isAI {
             // AI: No text, just logo (handled by showText=false)
        } else {
            // Human: Title, Artist, Year
            if let name = wallpaper.name, !name.isEmpty { textParts.append(name) }
            if let artist = wallpaper.artist, !artist.isEmpty { textParts.append(artist) }
            if let date = wallpaper.creationDate, !date.isEmpty { textParts.append(date) }
        }
        
        let overlayText = textParts.joined(separator: ", ")
        
        // 3. Conditional Text Display (Hide for AI)
        let showText = !isAI
        
        return injectCloudinaryParams(url: wallpaper.url, width: width, height: height, text: overlayText, showText: showText, fitToVertical: fitToVertical)
    }
    
    /// Helper to get the text string for local processing
    func getOverlayText(for wallpaper: Wallpaper) -> String? {
        // AI = No text
        if wallpaper.channel == Constants.channelAI { return nil }
        
        var textParts: [String] = []
        if let name = wallpaper.name, !name.isEmpty { textParts.append(name) }
        if let artist = wallpaper.artist, !artist.isEmpty { textParts.append(artist) }
        if let date = wallpaper.creationDate, !date.isEmpty { textParts.append(date) }
        
        return textParts.isEmpty ? nil : textParts.joined(separator: ", ")
    }
    
    private func injectCloudinaryParams(url: String, width: Int, height: Int, text: String, showText: Bool, fitToVertical: Bool) -> URL? {
        // 0. Cloudflare / Non-Cloudinary Passthrough
        // If it's NOT a cloudinary URL, we just return it as is.
        // Meaning: Cloudflare images will NOT have text overlays for now (as requested).
        if !url.contains("cloudinary.com") {
            return URL(string: url)
        }

        let keyword = Constants.uploadKeyword
        guard let range = url.range(of: keyword) else {
            return URL(string: url)
        }
        
        var encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Wallpaper"
        // Double encode commas for Cloudinary
        encodedText = encodedText.replacingOccurrences(of: ",", with: "%252C")
        
        // Smart Fit Logic:
        // Vertical screens (Portrait) should NOT crop artwork. They should fit (pad) and use a blurred background.
        // Horizontal screens (Landscape) should continue to Fill (crop).
        let isVertical = height > width
        
        var resize = ""
        // Only apply "Pad" logic if screen is Vertical AND user has enabled the setting.
        if isVertical && fitToVertical {
            // c_pad: Fit image within dims
            // b_rgb:1c1c1e: Apple Dark Mode Gray (Dark Graphite).
            // Stable, premium, and neutral dark background. Auto-colors caused 400 errors.
            // f_jpg: Force JPEG for predictable macOS wallpaper support.
            resize = "w_\(width),h_\(height),c_pad,b_rgb:1c1c1e,f_jpg"
            
            // Note: If using Cloudflare in future, we would use /cdn-cgi/image/width=...
            // But we can't do text overlay there easily.
        } else {
            // c_fill: Crop to fill dims
            resize = "w_\(width),h_\(height),c_fill,f_jpg"
        }
        
        // Local Overlay Transition:
        // We now handle text/overlays locally for consistency.
        // So we ONLY ask Cloudinary to Resize/Crop.
        
        let params = "\(resize)/"
        // Removed: icon & textMain injection
        
        var newUrlString = url
        newUrlString.insert(contentsOf: params, at: range.upperBound)
        
        return URL(string: newUrlString)
    }
    
    /// Downloads image to Disk and returns local URL
    func downloadImage(url: URL, wallpaperId: String) async throws -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderURL = appSupportURL.appendingPathComponent("Basalt")
        
        // Ensure folder exists
        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        // FIX: Use hash of the absolute URL to ensure unique filenames for different Cloudinary transformations (overlays, sizes)
        let urlHash = abs(url.absoluteString.hashValue)
        let filename = "wallpaper_\(wallpaperId)_\(urlHash).jpg"
        let destinationURL = folderURL.appendingPathComponent(filename)
        
        // Check existing
        if fileManager.fileExists(atPath: destinationURL.path) {
            let attr = try? fileManager.attributesOfItem(atPath: destinationURL.path)
            let size = attr?[.size] as? Int64 ?? 0
            if size > 1000 {
                return destinationURL // Valid cache hit
            } else {
                try? fileManager.removeItem(at: destinationURL) // Corrupt, delete
            }
        }
        
        // Download
        let (tempUrl, response) = try await URLSession.shared.download(from: url)
        
        // Validate HTTP Status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorData = try? Data(contentsOf: tempUrl)
            let errorString = String(data: errorData ?? Data(), encoding: .utf8) ?? "Unknown error"
            // print("❌ Download Failed [\(httpResponse.statusCode)] for: \(url.absoluteString)")
            // print("Server Response: \(errorString)")
            throw NSError(domain: "ImageService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorString)"])
        }
        
        // Validate Size (Catch corrupt or empty 200 OK responses)
        let attr = try fileManager.attributesOfItem(atPath: tempUrl.path)
        let size = attr[.size] as? Int64 ?? 0
        guard size > 1000 else {
            throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded file too small (\(size) bytes)"])
        }
        
        // Move
        // Ensure destination doesn't exist (race condition safety)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempUrl, to: destinationURL)
        
        return destinationURL
    }
    
    @MainActor
    func applyToScreen(localUrl: URL, screen: NSScreen) throws {
        let workspace = NSWorkspace.shared
        try workspace.setDesktopImageURL(localUrl, for: screen, options: [:])
    }
    
    /// Checks if the image needs local padding (vertical fit) OR text overlay and generates it if so.
    /// Returns the new URL or the original if no processing needed.
    @MainActor
    func processImageForScreen(sourceUrl: URL, screen: NSScreen, fitVertical: Bool, originalUrlString: String, overlayText: String?) throws -> URL {
        // 1. Determine Needs
        
        // A. Padding Criteria
        let screenWidth = screen.frame.width
        let screenHeight = screen.frame.height
        let isVerticalScreen = screenHeight > screenWidth
        // Only pad if it's a vertical screen AND user wants it AND Cloudinary didn't already do it
        let needsPadding = fitVertical && isVerticalScreen && !originalUrlString.contains("c_pad")
        
        // B. Text Criteria
        // Always apply if text exists (since we removed server-side injection)
        let needsText = (overlayText != nil)
        
        // If nothing to do, return original
        if !needsPadding && !needsText { return sourceUrl }
        
        // 2. Load Source
        guard let sourceImage = NSImage(contentsOf: sourceUrl) else {
            return sourceUrl // Fail safe
        }
        
        let srcSize = sourceImage.size
        
        // 3. Setup Target Canvas (Smart Resolution)
        // Use min(screen pixels, source pixels) to:
        // - Never upscale beyond source resolution (wastes space)
        // - Still fit the screen when source is larger
        let scale = screen.backingScaleFactor
        let screenPixelWidth = Int(screenWidth * scale)
        let screenPixelHeight = Int(screenHeight * scale)
        
        // Calculate target maintaining aspect ratio, capped to source size
        let sourceWidth = Int(srcSize.width)
        let sourceHeight = Int(srcSize.height)
        
        // For "fill" mode, we need screen dimensions (we'll crop excess)
        // For "pad" mode, we also use screen dimensions (source fits inside)
        // But we cap to source size to avoid pointless upscaling
        let pixelWidth = min(screenPixelWidth, sourceWidth)
        let pixelHeight = min(screenPixelHeight, sourceHeight)
        let targetSize = NSSize(width: pixelWidth, height: pixelHeight)
        
        // Output Filename (Hash based on params to cache it)
        // Include "v8" for Resolution Optimization
        let fileSuffix = "_\(needsPadding ? "pad" : "fill")\(needsText ? "txt" : "")_v8"
        let newFilename = "processed_\(sourceUrl.deletingPathExtension().lastPathComponent)\(fileSuffix).jpg"
        let folderURL = sourceUrl.deletingLastPathComponent()
        let destUrl = folderURL.appendingPathComponent(newFilename)
        
        // Cache Check
        if fileManager.fileExists(atPath: destUrl.path) {
            return destUrl
        }
        
        // 4. Draw
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        let widthRatio = targetSize.width / srcSize.width
        let heightRatio = targetSize.height / srcSize.height
        
        // A. Background & Image Placement
        if needsPadding {
            // Dark Background
            let color = NSColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0).cgColor
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.setFillColor(color)
            ctx?.fill(CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
            
            // Aspect FIT (min scale)
            let fitScale = min(widthRatio, heightRatio)
            
            let drawnWidth = srcSize.width * fitScale
            let drawnHeight = srcSize.height * fitScale
            let x = (targetSize.width - drawnWidth) / 2
            let y = (targetSize.height - drawnHeight) / 2
            
            let destRect = NSRect(x: x, y: y, width: drawnWidth, height: drawnHeight)
            NSGraphicsContext.current?.imageInterpolation = .high
            sourceImage.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            
        } else {
            // Aspect FILL (max scale)
            let fillScale = max(widthRatio, heightRatio)
            
            let drawnWidth = srcSize.width * fillScale
            let drawnHeight = srcSize.height * fillScale
            
            // Center Crop
            let x = (targetSize.width - drawnWidth) / 2
            let y = (targetSize.height - drawnHeight) / 2
            
            let destRect = NSRect(x: x, y: y, width: drawnWidth, height: drawnHeight)
            NSGraphicsContext.current?.imageInterpolation = .high
            sourceImage.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        
        // B. Overlay (Icon + Text)
        if needsText, let text = overlayText {
            // 1. Setup Scaling
            // Use actual output scale relative to screen logical size (not backing scale)
            // This ensures text looks correct regardless of resolution capping
            let actualScale = targetSize.width / screenWidth
            
            let baseFontSize: CGFloat = 12.0
            let baseMargin: CGFloat = 22.0
            let baseIconHeight: CGFloat = 18.0 // Approx 1.5x font
            let baseSpacing: CGFloat = 8.0
            
            let fontSize = baseFontSize * actualScale
            let margin = baseMargin * actualScale
            let iconSize = baseIconHeight * actualScale
            let spacing = baseSpacing * actualScale
            
            // 2. Prepare Icon
            // Try Asset Catalog first ("basalt-icon-white" as requested), then SF Symbol Fallback
            var iconImage = NSImage(named: "basalt-icon-white")
            if iconImage == nil {
                let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .medium)
                iconImage = NSImage(systemSymbolName: "square.stack.3d.down.right.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
            }
            
            // 3. Draw Icon (if valid) with Shadow & Tint
            if let rawIcon = iconImage {
                // Determine layout y-position to center vertically with text
                // Text baseline is usually at 'margin'.
                // Let's align bottoms roughly or center.
                // Simple bottom alignment:
                let iconOrigin = NSPoint(x: margin, y: margin - (2 * actualScale)) // Slight nudge down for optical baseline alignment
                
                // Draw Loop for Tint + Shadow
                let ctx = NSGraphicsContext.current?.cgContext
                ctx?.saveGState()
                
                // Shadow
                ctx?.setShadow(offset: CGSize(width: 1, height: -1), blur: 2, color: NSColor.black.withAlphaComponent(0.5).cgColor)
                
                // Tint to White needs a mask. Safest robust way in Cocoa drawing:
                // Create a tinted copy or use template rendering logic.
                // Simpler: Draw image as template using SourceAtop with white fill?
                // Or just use the native `drawing` methods which respect template mode if set.
                rawIcon.isTemplate = true
                NSColor.white.set() // Tint color (Solid White)
                
                let iconRect = NSRect(x: iconOrigin.x, y: iconOrigin.y, width: iconSize, height: iconSize)
                // Draw image into the rect, using the set color. 
                // Use fraction 0.6 to match text opacity explicitly
                rawIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 0.6, respectFlipped: true, hints: nil)
                
                // Explicitly fill the rect for template images to take color?
                // Actually, `draw` with `isTemplate` usually uses the current color.
                // Let's ensure by using a standard locking approach if the above is flaky:
                // But keeping it simple for now. If this fails to be white, we'll brute force it.
                
                ctx?.restoreGState()
            }
            
            // 4. Draw Text
            let textX = margin + iconSize + spacing
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.6),
                .shadow: {
                    let s = NSShadow()
                    s.shadowOffset = NSSize(width: 1, height: -1)
                    s.shadowBlurRadius = 2
                    s.shadowColor = NSColor.black.withAlphaComponent(0.5)
                    return s
                }()
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attrs)
            attributedString.draw(at: NSPoint(x: textX, y: margin))
        }
        
        newImage.unlockFocus()
        
        // 5. Save to Disk
        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpgData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
            return sourceUrl
        }
        
        try jpgData.write(to: destUrl)
        
        return destUrl
    }
    
    /// Deletes processed and downloaded wallpapers older than the specified days
    func cleanupOldFiles(olderThanDays: Int = 3) {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folderURL = appSupportURL.appendingPathComponent("Basalt")
        
        guard fileManager.fileExists(atPath: folderURL.path) else { return }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for fileURL in contents {
                let filename = fileURL.lastPathComponent
                
                // Only clean up our generated files (processed_* and wallpaper_*)
                guard filename.hasPrefix("processed_") || filename.hasPrefix("wallpaper_") else { continue }
                
                // Check modification date
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                    #if DEBUG
                    print("🧹 Cleaned up old file: \(filename)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Cleanup error: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - 4. Manager (ViewModel)

@MainActor
class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    // Services
    private let networkService = NetworkService()
    private let imageService = ImageService()
    private let defaults = UserDefaults.standard
    private let networkMonitor = NetworkMonitor.shared
    
    // State
    @Published var currentStatus: String = "Ready"
    @Published var screenWallpapers: [ScreenWallpaperInfo] = []
    
    @Published var useSameWallpaper: Bool {
        didSet {
            defaults.set(useSameWallpaper, forKey: Constants.useSameWallpaperKey)
            Task { @MainActor in refreshDisplay() }
        }
    }
    
    @Published var selectedChannels: Set<String> {
        didSet {
            defaults.set(Array(selectedChannels), forKey: Constants.selectedChannelsKey)
            Task { @MainActor in checkForUpdates() }
        }
    }
    
    @Published var fitVerticalDisplays: Bool {
        didSet {
            defaults.set(fitVerticalDisplays, forKey: Constants.fitVerticalKey)
            Task { @MainActor in refreshDisplay() }
        }
    }
    
    @Published var screensaverEnabled: Bool {
        didSet {
            defaults.set(screensaverEnabled, forKey: Constants.syncScreensaverKey)
            if screensaverEnabled {
                Task { @MainActor in refreshDisplay() }
            }
        }
    }
    
    // Internal Cache
    private var cachedWallpapers: [Wallpaper] = []
    private var screenChangeTimer: Timer?
    
    // Concurrency Control
    private var updateTask: Task<Void, Never>?
    
    /// Re-processes the current wallpapers with new settings
    func refreshDisplay() {
        // Since we now rely on persistent DailyState or Overrides, 
        // calling checkForUpdates() will load the correct state and apply it.
        checkForUpdates()
    }
    
    private init() {
        // Clear Surprise/Overrides on Launch (per user request)
        UserDefaults.standard.removeObject(forKey: Constants.overrideContextIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.overrideWallpaperIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.overrideWallpaperKey)
        
        // Cleanup old wallpaper files (older than 3 days) to prevent disk bloat
        ImageService().cleanupOldFiles()
        
        // Init State
        self.useSameWallpaper = UserDefaults.standard.object(forKey: Constants.useSameWallpaperKey) as? Bool ?? true
        
        if let saved = UserDefaults.standard.array(forKey: Constants.selectedChannelsKey) as? [String] {
            self.selectedChannels = Set(saved)
        } else {
            self.selectedChannels = Set(Constants.defaultChannels)
        }
        
        self.fitVerticalDisplays = UserDefaults.standard.object(forKey: Constants.fitVerticalKey) as? Bool ?? true
        self.screensaverEnabled = UserDefaults.standard.object(forKey: Constants.syncScreensaverKey) as? Bool ?? false
        
        setupObservers()
        checkForUpdates()
    }
    
    private func setupObservers() {
        // Wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        // Screen Change
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleScreenChange), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        // Day Change (Midnight) - System sends this at midnight or when waking on a new day
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDayChange), name: .NSCalendarDayChanged, object: nil
        )
        // Network Change
        networkMonitor.$isConnected
            .dropFirst() // Ignore initial
            .removeDuplicates() // Prevent redundant updates if status hasn't changed
            .sink { [weak self] connected in
                if connected {
                    // print("Network is back. Checking for updates...")
                    self?.checkForUpdates()
                } else {
                    self?.currentStatus = "Offline"
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Actions
    
    func toggleChannel(_ channel: String) {
        if selectedChannels.contains(channel) {
            // Guardrail: Prevent disabling the last channel
            if selectedChannels.count > 1 {
                selectedChannels.remove(channel)
            } else {
                // Ideally we would show a tooltip here, but for now we just prevent the change.
                // The toggle binding in UI will just reflect the state back to true.
                #if DEBUG
                 print("⚠️ Cannot disable the last channel.")
                #endif
            }
        } else {
            selectedChannels.insert(channel)
        }
    }
    
    /// Clears any Surprise/Overrides and forces a return to the Daily logic
    func resetToDaily() {
        defaults.removeObject(forKey: Constants.overrideContextIdKey)
        defaults.removeObject(forKey: Constants.overrideWallpaperIdKey)
        defaults.removeObject(forKey: Constants.overrideWallpaperKey)
        // FORCE CLEAN REFRESH: Clear the daily cache too so we re-fetch the manifest
        defaults.removeObject(forKey: Constants.dailyStateKey)
        checkForUpdates()
    }
    
    func checkForUpdates() {
        // Cancel previous update to prevent race conditions
        updateTask?.cancel()
        
        updateTask = Task { @MainActor in
            // Debounce (coalesce rapid events)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if Task.isCancelled { return }
            
            // 1. Setup Context
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: Date())
            self.currentStatus = "Checking..."
            
            do {
                // 2. CHECKPERSISTENCE: Do we have a valid state for today?
                // Validity = Correct Date + Correct Channel + Content is "Today's" (not a fallback)
                // Note: We prioritize explicit "Surprise" overrides if they exist and match today
                
                // A. Check Surprise Override
                if let overrideDate = defaults.string(forKey: Constants.overrideContextIdKey), 
                   overrideDate == todayString,
                   let data = defaults.data(forKey: Constants.overrideWallpaperKey),
                   let surpriseParams = try? JSONDecoder().decode(Wallpaper.self, from: data) {
                    
                    // Surprise is valid for today. Use it.
                    // Note: Surprise ignores Channel filters because it was explicit user action.
                    let state = DailyState(date: todayString, mainWallpaper: surpriseParams, secondaryWallpapers: [:])
                    await processDailyState(state)
                    return
                }
                
                // B. Check Daily State
                if let data = defaults.data(forKey: Constants.dailyStateKey),
                   let savedState = try? JSONDecoder().decode(DailyState.self, from: data),
                   savedState.date == todayString {
                    
                    let wallpaper = savedState.mainWallpaper
                    
                    // Validation 1: Channel
                    // If the saved wallpaper's channel is NOT in the currently selected set, we must discard it.
                    let wallpaperChannel = wallpaper.channel ?? Constants.channelHuman // Default to Human if missing
                    let channelMatch = selectedChannels.contains(wallpaperChannel)
                    
                    // Validation 2: Freshness
                    // Ensure we aren't using a "fallback" from yesterday if today's real post is out.
                    let releaseDate = wallpaper.releaseDate?.prefix(10) ?? "unknown"
                    let isFresh = (releaseDate == todayString)
                    
                    if channelMatch && isFresh {
                        // print("✅ Using PERSISTED Valid State. Name: \(wallpaper.name ?? ""), Channel: \(wallpaperChannel)")
                        await processDailyState(savedState)
                        return
                    } else {
                        // print("♻️ Persisted state invalid. Match: \(channelMatch), Fresh: \(isFresh). Refetching...")
                    }
                }
                
                // 3. FETCH: Get new data from server
                if !networkMonitor.isConnected {
                    self.currentStatus = "Offline"
                    return
                }
                
                // Fetch Manifest (Server filters by channel for us, but we can double check)
                let wallpapers = try await networkService.fetchManifest(channels: selectedChannels)
                
                if wallpapers.isEmpty {
                    self.currentStatus = "No wallpapers found."
                    return
                }
                self.cachedWallpapers = wallpapers
                
                // 4. SELECT: Pick the winning wallpaper
                // Logic: "Today's" Release > "Most Recent" Release > Random Fallback
                
                let candidates = wallpapers.filter { 
                    ($0.releaseDate?.prefix(10) ?? "unknown") == todayString 
                }
                
                let mainChoice: Wallpaper
                if let strictlyToday = candidates.randomElement() {
                    mainChoice = strictlyToday
                    // print("🎉 Found Today's Wallpaper: \(mainChoice.name ?? "Unknown")")
                } else {
                    // Fallback to latest available
                    let sorted = wallpapers.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
                    if let latest = sorted.first {
                        mainChoice = latest
                        // print("⚠️ using Latest Fallback: \(mainChoice.name ?? "Unknown")")
                    } else {
                        mainChoice = wallpapers[0]
                    }
                }
                
                // 5. SECONDARIES
                var secondaries: [Int: Wallpaper] = [:]
                if !useSameWallpaper && NSScreen.screens.count > 1 {
                    for i in 1..<NSScreen.screens.count {
                        // Avoid using the exact same Main wallpaper if possible, or just pick randoms
                        let pool = wallpapers.filter { $0.id != mainChoice.id }
                        secondaries[i] = pool.randomElement() ?? mainChoice
                    }
                }
                
                // 6. PERSIST & APPLY
                let newState = DailyState(date: todayString, mainWallpaper: mainChoice, secondaryWallpapers: secondaries)
                if let data = try? JSONEncoder().encode(newState) {
                    defaults.set(data, forKey: Constants.dailyStateKey)
                }
                
                // Clear any old, stale overrides
                defaults.removeObject(forKey: Constants.overrideContextIdKey)
                
                await processDailyState(newState)
                
            } catch {
                if Task.isCancelled { return }
                // print("Update Error: \(error)")
                self.currentStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func surpriseMe() {
         // Network check removed to allow cached surprise if applicable, though fetchRandom needs network.
         // fetchRandom will throw if offline, which is fine.
        
        self.currentStatus = "Fetching surprise..."
        
        Task {
            do {
                // Fetch Random
                let random = try await networkService.fetchRandom(channels: selectedChannels)
                
                // Set Override (Surprise logic)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayString = formatter.string(from: Date())
                
                defaults.set(random.id, forKey: Constants.overrideWallpaperIdKey)
                defaults.set(todayString, forKey: Constants.overrideContextIdKey)
                
                if let data = try? JSONEncoder().encode(random) {
                    defaults.set(data, forKey: Constants.overrideWallpaperKey)
                }
                
                // Apply immediately.
                // Surprise replaces MAIN. 
                // Secondaries? "Surprise mode active". Usually surprise is just one manual action.
                // We will treat it as applying to Main. Logic in checkForUpdates handles the persistent display.
                // We re-run checkForUpdates to let it pick up the new Override.
                checkForUpdates()
                
            } catch {
                // print("Surprise Error: \(error)")
                self.currentStatus = "Surprise failed."
            }
        }
    }

    // MARK: - Logic
    
    /// Main Logic Engine: Map Data -> Screens
    private func processDailyState(_ state: DailyState) async {
        let screens = NSScreen.screens
        guard !screens.isEmpty, let mainScreen = NSScreen.main else {
            self.currentStatus = "No displays."
            return
        }
        
        // Sort: Main first, then left-to-right
        let sortedScreens = screens.sorted { s1, s2 in
            if s1 == mainScreen { return true }
            if s2 == mainScreen { return false }
            return s1.frame.origin.x < s2.frame.origin.x
        }
        
        self.currentStatus = "Updating \(screens.count) screens..."
        var newInfos: [ScreenWallpaperInfo] = []
        
        // Calculate Assignments (Wallpaper -> Screen)
        // We use a TaskGroup to download concurrently but safely within this actor/Task
        // We track failures within the group loop
        var failures = 0
        var lastError: String?
        
        await withTaskGroup(of: (Int, ScreenWallpaperInfo?, Error?).self) { group in
            for (index, screen) in sortedScreens.enumerated() {
                // Determine which wallpaper to use for this screen from DailyState
                let wallpaper: Wallpaper
                
                if useSameWallpaper {
                    wallpaper = state.mainWallpaper
                } else {
                    if index == 0 {
                        wallpaper = state.mainWallpaper
                    } else {
                        wallpaper = state.secondaryWallpapers[index] ?? state.mainWallpaper
                    }
                }
                
                // Generate Info
                let urlOrNil = imageService.generateUrl(for: wallpaper, screen: screen, fitToVertical: self.fitVerticalDisplays)
                
                let displayName = "Disp \(index + 1)"
                var contentName = wallpaper.name ?? wallpaper.description ?? "Untitled"
                if let n = wallpaper.name, let d = wallpaper.description, !d.isEmpty { contentName = "\(n) - \(d)" }
                
                let info = ScreenWallpaperInfo(
                    displayName: displayName,
                    wallpaperName: contentName,
                    url: urlOrNil,
                    originalUrl: wallpaper.url,
                    externalUrl: wallpaper.externalUrl
                )
                
                // Trigger Download & Set
                if let downloadUrl = urlOrNil {
                    group.addTask {
                        do {
                            let localPath = try await self.imageService.downloadImage(url: downloadUrl, wallpaperId: wallpaper.id)
                            
                            // NEW: Local Processing Step (Fit to Vertical + Text Overlay)
                            // We do this Post-Download to support any provider (Cloudflare, etc)
                            let processedPath = try await self.imageService.processImageForScreen(
                                sourceUrl: localPath,
                                screen: screen,
                                fitVertical: self.fitVerticalDisplays,
                                originalUrlString: wallpaper.url,
                                overlayText: self.imageService.getOverlayText(for: wallpaper)
                            )
                            
                            try await MainActor.run {
                                try self.imageService.applyToScreen(localUrl: processedPath, screen: screen)
                                
                                // Sync Screensaver if this is the first/main screen and enabled
                                if index == 0 && self.screensaverEnabled {
                                    self.syncToScreensaver(sourceUrl: processedPath)
                                }
                            }
                            return (index, info, nil)
                        } catch {
                            return (index, info, error)
                        }
                    }
                } else {
                    // No URL generated, immediately return success-ish info (just metadata)
                    group.addTask {
                        return (index, info, nil)
                    }
                }
            }
            
            // Collect results
            for await (_, info, error) in group {
                if let err = error {
                    // Ignore cancellation errors
                    let nsError = err as NSError
                    if nsError.code == NSURLErrorCancelled {
                       // Silent ignore
                    } else {
                        // print("Failed screen \(index): \(err)")
                        failures += 1
                        lastError = err.localizedDescription
                    }
                } else if let validInfo = info {
                    newInfos.append(validInfo)
                }
            }
        }
        
        if failures == 0 {
            self.currentStatus = "Updated!"
        } else {
            self.currentStatus = "Error: \(lastError ?? "Unknown")"
        }
        
        // Update UI State
        self.screenWallpapers = newInfos.sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Event Handlers
    
    @objc func handleWake() {
        // Check if we woke up on a new day - if so, clear stale state immediately
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        if let data = defaults.data(forKey: Constants.dailyStateKey),
           let savedState = try? JSONDecoder().decode(DailyState.self, from: data),
           savedState.date != todayString {
            // It's a new day! Clear the stale state so checkForUpdates fetches fresh data
            #if DEBUG
            print("🌅 Wake on new day (was: \(savedState.date), now: \(todayString)). Clearing stale state...")
            #endif
            defaults.removeObject(forKey: Constants.dailyStateKey)
        }
        
        // Strategy: Network might take a while to reconnect (DHCP, etc).
        // Multiple checks at specific times to catch "fast" vs "slow" reconnections.
        
        // 1. Quick check (5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
        
        // 2. Backup check (15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
        
        // 3. Final safety check (30s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
    }
    
    @objc func handleDayChange() {
        // System notification sent at midnight OR when waking up on a new day
        #if DEBUG
        print("📅 Day changed. Triggering wallpaper refresh...")
        #endif
        
        // Clear stale daily state to force a fresh fetch
        defaults.removeObject(forKey: Constants.dailyStateKey)
        
        // Immediate check + delayed check (in case network needs time)
        checkForUpdates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
    }
    
    func syncToScreensaver(sourceUrl: URL) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screensaverDir = appSupport.appendingPathComponent("Basalt/Screensaver")
        
        do {
            // 1. Ensure Directory Exists
            if !fileManager.fileExists(atPath: screensaverDir.path) {
                try fileManager.createDirectory(at: screensaverDir, withIntermediateDirectories: true)
            }
            
            // 2. Clear Old Files (We only want the CURRENT wallpaper there for a static screensaver)
            // If user wants a history, we would skip this. But "Today's Image" implies singular.
            let contents = try fileManager.contentsOfDirectory(at: screensaverDir, includingPropertiesForKeys: nil)
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
            
            // 3. Copy New File
            let destUrl = screensaverDir.appendingPathComponent(sourceUrl.lastPathComponent)
            try fileManager.copyItem(at: sourceUrl, to: destUrl)
            
            // print("✅ Synced to Screensaver: \(destUrl.path)")
            
        } catch {
            // print("❌ Screensaver Sync Failed: \(error)")
        }
    }
    
    func revealScreensaverFolder() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let screensaverDir = appSupport.appendingPathComponent("Basalt/Screensaver")
        
        if !fileManager.fileExists(atPath: screensaverDir.path) {
            try? fileManager.createDirectory(at: screensaverDir, withIntermediateDirectories: true)
        }
        
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: screensaverDir.path)
    }

    @objc func handleScreenChange() {
        // print("Screen Change.")
        screenChangeTimer?.invalidate()
        screenChangeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
    }
}

// MARK: - 5. App UI & Settings

struct SettingsView: View {
    @ObservedObject var manager = WallpaperManager.shared
    @ObservedObject var updater = Updater.shared
    
    // Launch at Login State
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title

            
            // Group 1: Channels
            SettingsGroup(title: "Select channels") {
                SettingsToggleRow(
                    title: "Human",
                    description: "Made by real people",
                    isOn: Binding(
                        get: { manager.selectedChannels.contains(Constants.channelHuman) },
                        set: { _ in manager.toggleChannel(Constants.channelHuman) }
                    )
                )
                
                Divider()
                    .padding(.horizontal, 12) // approx 90% width
                    .opacity(0.5)
                
                SettingsToggleRow(
                    title: "AI",
                    description: "Made by machines",
                    isOn: Binding(
                        get: { manager.selectedChannels.contains(Constants.channelAI) },
                        set: { _ in manager.toggleChannel(Constants.channelAI) }
                    )
                )
            }
            
            // Group 2: Display
            SettingsGroup(title: "Display") {
                SettingsToggleRow(
                    title: "Same on all screens",
                    isOn: $manager.useSameWallpaper
                )
                
                Divider()
                    .padding(.horizontal, 12) // approx 90% width
                    .opacity(0.5)
                
                SettingsToggleRow(
                    title: "Prevent cropping on vertical screens",
                    isOn: $manager.fitVerticalDisplays
                )
            }
            
            // Group 3: Screensaver
            SettingsGroup(title: "Screensaver") {
                SettingsToggleRow(
                    title: "Sync wallpaper to screensaver",
                    description: "Automatically updates a folder for the 'Classic' screensaver",
                    isOn: $manager.screensaverEnabled
                )
                
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.5)
                
                HStack {
                    Text("Folder Location")
                        .font(.body)
                    Spacer()
                    Button("Reveal in Finder") {
                        manager.revealScreensaverFolder()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.5)
                
                HStack {
                    Text("How to Set Up the Basalt Screensaver?")
                        .font(.body)
                    Spacer()
                    Button("Open in Browser") {
                        NSWorkspace.shared.open(URL(string: "https://basalt.yevgenglukhov.com/setup-screensaver")!)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // Group 3: General
            SettingsGroup(title: "") {
                SettingsToggleRow(title: "Start at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                        }
                    }

                
                Divider()
                    .padding(.horizontal, 12)
                    .opacity(0.5)
                
                HStack {
                    Text("Quick Start Guide")
                        .font(.body)
                    Spacer()
                    Button("Open") {
                        WindowManager.shared.showQuickStart()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            // Footer
            HStack(spacing: 4) {
                // Version (Clickable to check for updates)
                Button(action: {
                    updater.checkForUpdates()
                }) {
                    Text("Basalt v\(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Status
                if updater.updateAvailable {
                    Text("Update now")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text(manager.currentStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Refresh Action
                Button("Refresh") {
                    manager.resetToDaily()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity) // Center the footer
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows {
                    if window.title.contains("Settings") {
                        window.level = .normal
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }
}

// MARK: - 6. Window Manager & Delegate

@MainActor
class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = WindowManager()
    private var quickStartWindow: NSWindow?
    
    private override init() {}
    
    func showQuickStart() {
        // print("✨ WindowManager: showQuickStart called")
        
        if let window = quickStartWindow {
            // print("🔄 WindowManager: Bringing existing window to front (and resetting state)")
            // Reset to new instance (start at slide 0)
            window.contentViewController = NSHostingController(rootView: QuickStartView())
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // print("🆕 WindowManager: Creating new Quick Start Window")
        
        let view = QuickStartView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to Basalt"
        
        // Style: Titled, Closable, FullSizeContentView
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Standard Window System: White, Opaque, Standard Shadow
        window.backgroundColor = .white
        window.isOpaque = true
        window.hasShadow = true
        
        window.center()
        
        // Ensure size
        window.setContentSize(NSSize(width: 522, height: 580))
        
        // Handle close to release reference
        window.isReleasedWhenClosed = false 
        window.delegate = self // Assign delegate
        
        self.quickStartWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Mark as seen
        UserDefaults.standard.set(true, forKey: "hasSeenQuickStart")
    }
    
    func windowWillClose(_ notification: Notification) {
        // print("🚪 WindowManager: Window closing, triggering robust cleanup.")
        // Force kill the video player
        SharedVideoManager.shared.hardReset()
        
        // Release reference
        if let closingWindow = notification.object as? NSWindow, closingWindow == self.quickStartWindow {
            self.quickStartWindow = nil
        }
    }
}

// MARK: - Helper Views for Settings

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Reduced spacing for headers
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.gray.opacity(0.05)) // More visible background
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 40)
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.7) // Make toggle smaller (approx 1.5x smaller)
            
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8) // Slightly tighter padding since toggles are smaller
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 300)
    }
}

@main
struct BasaltApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var manager = WallpaperManager.shared
    
    // Timer is likely unnecessary if we rely on Wake/Notifications, 
    // but good as a fallback if the app stays open for days without sleep.
    let timer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    var body: some Scene {
        MenuBarExtra("Basalt", image: "MenuBarIcon") {
            // Simplified Menu
            Button("About Today's Art") {
                if let url = URL(string: Constants.websiteUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("🎲 Surprise me") { manager.surpriseMe() }
            Divider()
            
            if #available(macOS 14.0, *) {
                SettingsButtonWrapper()
            } else {
                Button("Settings...") {
                    // Manual fallback for older macOS versions
                    // Manual fallback for older macOS versions (actually safe for target)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            SettingsView()
                .onAppear {
                    // Force app to front when settings window appears
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
    
    func copyToClipboard(_ str: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(str, forType: .string)
    }
}

// Logic View to handle first-launch checks
// MARK: - 6. AppDelegate & Window Management
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // print("🚀 AppDelegate: applicationDidFinishLaunching")
        // Check first launch
        let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenQuickStart")
        // print("👀 hasSeenQuickStart: \(hasSeen)")
        
        if !hasSeen {
            // Delay slightly to ensure app is fully alive and context is main
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // print("⏲️ Triggering First Launch Quick Start via WindowManager")
                Task { @MainActor in
                    WindowManager.shared.showQuickStart()
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct SettingsButtonWrapper: View {
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

