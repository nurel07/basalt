import SwiftUI
import AppKit
import Combine

// MARK: - 1. Constants & Configuration

enum Constants {
    static let baseUrl = "https://basalt-prod.up.railway.app/api/wallpapers"
    static let randomUrl = "https://basalt-prod.up.railway.app/api/wallpapers/random"
    
    // Cloudinary
    static let uploadKeyword = "/upload/"
    static let maxResolution = 2560
    
    // UserDefaults Keys
    static let useSameWallpaperKey = "useSameWallpaper"
    static let selectedChannelsKey = "selectedChannels"
    static let overrideWallpaperIdKey = "overrideWallpaperId"
    static let overrideContextIdKey = "overrideContextId"
    
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
}

struct ScreenWallpaperInfo: Identifiable {
    var id: String { displayName } // Stable ID
    let displayName: String
    let wallpaperName: String
    let url: URL?        // Generated Cloudinary URL
    let originalUrl: String // Raw DB URL
    let externalUrl: String?
}

// MARK: - 3. Services

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
    func generateUrl(for wallpaper: Wallpaper, screen: NSScreen) -> URL? {
        // 1. Calculate Resolution
        let rawWidth = Int(screen.frame.width * screen.backingScaleFactor)
        let rawHeight = Int(screen.frame.height * screen.backingScaleFactor)
        
        // Cap resolution
        let maxWidth = Constants.maxResolution
        let width: Int
        let height: Int
        
        if rawWidth > maxWidth {
            let ratio = Double(rawHeight) / Double(rawWidth)
            width = maxWidth
            height = Int(Double(maxWidth) * ratio)
        } else {
            width = rawWidth
            height = rawHeight
        }
        
        // 2. Text Content
        var textParts: [String] = []
        if let name = wallpaper.name, !name.isEmpty { textParts.append(name) }
        if let desc = wallpaper.description, !desc.isEmpty { textParts.append(desc) }
        let overlayText = textParts.joined(separator: ", ")
        
        // 3. Conditional Text Display (Hide for AI)
        let isAI = (wallpaper.channel == Constants.channelAI)
        let showText = !isAI
        
        return injectCloudinaryParams(url: wallpaper.url, width: width, height: height, text: overlayText, showText: showText)
    }
    
    private func injectCloudinaryParams(url: String, width: Int, height: Int, text: String, showText: Bool) -> URL? {
        let keyword = Constants.uploadKeyword
        guard let range = url.range(of: keyword) else {
            return URL(string: url)
        }
        
        var encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Wallpaper"
        // Double encode commas for Cloudinary
        encodedText = encodedText.replacingOccurrences(of: ",", with: "%252C")
        
        let resize = "w_\(width),h_\(height),c_fill"
        let icon = "l_topbar-icon-white_cwox5b,w_16,h_16,g_south_west,x_8,y_8"
        let textMain = "l_text:Arial_14:\(encodedText),co_white,g_south_west,x_34,y_9"
        
        var params = "\(resize)/\(icon)/"
        if showText {
            params += "\(textMain)/"
        }
        
        var newUrlString = url
        newUrlString.insert(contentsOf: params, at: range.upperBound)
        
        return URL(string: newUrlString)
    }
    
    /// Downloads image to Disk and returns local URL
    func downloadImage(url: URL, wallpaperId: String) async throws -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        // FIX: Use hash of the absolute URL to ensure unique filenames for different Cloudinary transformations (overlays, sizes)
        let urlHash = abs(url.absoluteString.hashValue)
        let filename = "wallpaper_\(wallpaperId)_\(urlHash).jpg"
        let destinationURL = documentsURL.appendingPathComponent(filename)
        
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
        let (tempUrl, _) = try await URLSession.shared.download(from: url)
        
        // Validate
        let attr = try fileManager.attributesOfItem(atPath: tempUrl.path)
        let size = attr[.size] as? Int64 ?? 0
        guard size > 1000 else {
            throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Downloaded file too small"])
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
}

// MARK: - 4. Manager (ViewModel)

@MainActor
class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    // Services
    private let networkService = NetworkService()
    private let imageService = ImageService()
    private let defaults = UserDefaults.standard
    
    // State
    @Published var currentStatus: String = "Ready"
    @Published var screenWallpapers: [ScreenWallpaperInfo] = []
    
    @Published var useSameWallpaper: Bool {
        didSet {
            defaults.set(useSameWallpaper, forKey: Constants.useSameWallpaperKey)
            checkForUpdates()
        }
    }
    
    @Published var selectedChannels: Set<String> {
        didSet {
            defaults.set(Array(selectedChannels), forKey: Constants.selectedChannelsKey)
            checkForUpdates()
        }
    }
    
    // Internal Cache
    var cachedWallpapers: [Wallpaper] = []
    private var screenChangeTimer: Timer?
    
    private init() {
        // Init State
        self.useSameWallpaper = UserDefaults.standard.object(forKey: Constants.useSameWallpaperKey) as? Bool ?? true
        
        if let saved = UserDefaults.standard.array(forKey: Constants.selectedChannelsKey) as? [String] {
            self.selectedChannels = Set(saved)
        } else {
            self.selectedChannels = Set(Constants.defaultChannels)
        }
        
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
    }
    
    // MARK: - Actions
    
    func toggleChannel(_ channel: String) {
        if selectedChannels.contains(channel) {
            selectedChannels.remove(channel)
        } else {
            selectedChannels.insert(channel)
        }
    }
    
    func checkForUpdates() {
        self.currentStatus = "Checking..."
        
        Task {
            do {
                let wallpapers = try await networkService.fetchManifest(channels: selectedChannels)
                
                if wallpapers.isEmpty {
                    self.currentStatus = "No wallpapers found."
                    return
                }
                
                self.processWallpapers(wallpapers)
                
            } catch {
                print("Update Error: \(error)")
                self.currentStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func surpriseMe() {
        self.currentStatus = "Fetching random..."
        
        Task {
            do {
                let randomMethod = try await networkService.fetchRandom(channels: selectedChannels)
                print("Fetched Random: \(randomMethod.name ?? "Unknown")")
                
                // Update Cache / Override
                // 1. Insert if missing
                if !self.cachedWallpapers.contains(where: { $0.id == randomMethod.id }) {
                    self.cachedWallpapers.insert(randomMethod, at: 0)
                }
                
                // 2. Set persistency keys
                let latestDailyId = self.cachedWallpapers.first?.id ?? ""
                let contextId = self.cachedWallpapers.first(where: { $0.id != randomMethod.id })?.id ?? latestDailyId
                
                defaults.set(randomMethod.id, forKey: Constants.overrideWallpaperIdKey)
                defaults.set(contextId, forKey: Constants.overrideContextIdKey)
                
                // 3. Refresh display specific to this new state
                // We re-process existing list + new random item, logic inside processWallpapers will pick up the Override
                self.processWallpapers(self.cachedWallpapers)
                
            } catch {
                print("Surprise Error: \(error)")
                self.currentStatus = "Surprise failed."
            }
        }
    }

    // MARK: - Logic
    
    /// Main Logic Engine: Map Data -> Screens
    private func processWallpapers(_ wallpapers: [Wallpaper]) {
        self.cachedWallpapers = wallpapers
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
        for (index, screen) in sortedScreens.enumerated() {
            let wallpaper = determineWallpaper(for: index, from: wallpapers)
            
            // Generate Info
            let urlOrNil = imageService.generateUrl(for: wallpaper, screen: screen)
            
            let displayName = "Disp \(index + 1)"
            var contentName = wallpaper.name ?? wallpaper.description ?? "Untitled"
            if let n = wallpaper.name, let d = wallpaper.description, !d.isEmpty { contentName = "\(n) - \(d)" }
            
            newInfos.append(ScreenWallpaperInfo(
                displayName: displayName,
                wallpaperName: contentName,
                url: urlOrNil,
                originalUrl: wallpaper.url,
                externalUrl: wallpaper.externalUrl
            ))
            
            // Trigger Download & Set
            if let downloadUrl = urlOrNil {
                Task {
                    do {
                        let localPath = try await imageService.downloadImage(url: downloadUrl, wallpaperId: wallpaper.id)
                        try await imageService.applyToScreen(localUrl: localPath, screen: screen)
                        if screen == mainScreen { self.currentStatus = "Updated!" }
                    } catch {
                        print("Failed screen \(index): \(error)")
                    }
                }
            }
        }
        
        self.screenWallpapers = newInfos
        cleanupOverrides(currentLatestId: wallpapers.first?.id)
    }
    
    private func determineWallpaper(for screenIndex: Int, from wallpapers: [Wallpaper]) -> Wallpaper {
        // Check Override
        let latestId = wallpapers.first?.id ?? ""
        let savedContext = defaults.string(forKey: Constants.overrideContextIdKey)
        let savedOverride = defaults.string(forKey: Constants.overrideWallpaperIdKey)
        
        // If Override exists and Context matches (meaning Daily hasn't changed), use Override
        if let oId = savedOverride, let cId = savedContext, cId == latestId,
           let overrideItem = wallpapers.first(where: { $0.id == oId }) {
            return overrideItem
        }
        
        // Standard Logic
        if useSameWallpaper {
            return wallpapers[0]
        } else {
            let idx = min(screenIndex, wallpapers.count - 1)
            return wallpapers[idx]
        }
    }
    
    private func cleanupOverrides(currentLatestId: String?) {
        guard let currentId = currentLatestId else { return }
        let savedContext = defaults.string(forKey: Constants.overrideContextIdKey)
        
        if savedContext != nil && savedContext != currentId {
            print("New daily detected. Clearing overrides.")
            defaults.removeObject(forKey: Constants.overrideContextIdKey)
            defaults.removeObject(forKey: Constants.overrideWallpaperIdKey)
        }
    }
    
    // MARK: - Event Handlers
    
    @objc func handleWake() {
        print("System Wake. Scheduling robust checks...")
        
        // Strategy: Network might take a while to reconnect (DHCP, etc).
        // specific times to catch "fast" vs "slow" reconnections.
        
        // 1. Quick check (5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            print("Wake Check 1 (5s)")
            self?.checkForUpdates()
        }
        
        // 2. Backup check (15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            print("Wake Check 2 (15s)")
            self?.checkForUpdates()
        }
        
        // 3. Final safety check (30s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            print("Wake Check 3 (30s)")
            self?.checkForUpdates()
        }
    }
    
    @objc func handleScreenChange() {
        print("Screen Change.")
        screenChangeTimer?.invalidate()
        screenChangeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.checkForUpdates()
        }
    }
}

// MARK: - 5. App UI

@main
struct CuratedWallpaperApp: App {
    @StateObject var manager = WallpaperManager.shared
    
    // Timer is likely unnecessary if we rely on Wake/Notifications, 
    // but good as a fallback if the app stays open for days without sleep.
    let timer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some Scene {
        MenuBarExtra("Basalt", image: "MenuBarIcon") {
            // Header
            Text("Status: \(manager.currentStatus) (v\(appVersion))")
            Divider()
            
            // Screen List
            ForEach(manager.screenWallpapers) { info in
                Button("\(info.displayName): \(info.wallpaperName)") {
                    copyToClipboard(info.externalUrl ?? info.originalUrl)
                }
            }
            
            Divider()
            
            // Channels
            Toggle("👁️ Human", isOn: Binding(
                get: { manager.selectedChannels.contains(Constants.channelHuman) },
                set: { _ in manager.toggleChannel(Constants.channelHuman) }
            ))
            
            Toggle("🤖 AI", isOn: Binding(
                get: { manager.selectedChannels.contains(Constants.channelAI) },
                set: { _ in manager.toggleChannel(Constants.channelAI) }
            ))
            
            // Options
            if manager.screenWallpapers.count > 1 {
                Divider()
                Toggle("Same on all screens", isOn: $manager.useSameWallpaper)
            }
            
            Divider()
            
            // Actions
            Button("🎲 Surprise me") { manager.surpriseMe() }
            Button("Check Now") { manager.checkForUpdates() }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
    
    func copyToClipboard(_ str: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(str, forType: .string)
    }
}
