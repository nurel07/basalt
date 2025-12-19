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
    
    // Persistence Keys
    static let useSameWallpaperKey = "UseSameWallpaper"
    static let selectedChannelsKey = "SelectedChannels"
    static let fitVerticalKey = "FitVerticalDisplays"
    
    // Day Persistence Keys (Surprise Me)
    static let overrideWallpaperIdKey = "OverrideWallpaperId"
    static let overrideContextIdKey = "OverrideContextId"
    static let overrideWallpaperKey = "OverrideWallpaper"
    
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
    func generateUrl(for wallpaper: Wallpaper, screen: NSScreen, fitToVertical: Bool) -> URL? {
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
        
        return injectCloudinaryParams(url: wallpaper.url, width: width, height: height, text: overlayText, showText: showText, fitToVertical: fitToVertical)
    }
    
    private func injectCloudinaryParams(url: String, width: Int, height: Int, text: String, showText: Bool, fitToVertical: Bool) -> URL? {
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
            // b_rgb:1C1C1E: Apple Dark Mode Gray (Dark Graphite).
            // Stable, premium, and neutral dark background. Auto-colors caused 400 errors.
            resize = "w_\(width),h_\(height),c_pad,b_rgb:1C1C1E"
        } else {
            // c_fill: Crop to fill dims
            resize = "w_\(width),h_\(height),c_fill"
        }
        
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
        let (tempUrl, response) = try await URLSession.shared.download(from: url)
        
        // Validate HTTP Status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorData = try? Data(contentsOf: tempUrl)
            let errorString = String(data: errorData ?? Data(), encoding: .utf8) ?? "Unknown error"
            print("❌ Download Failed [\(httpResponse.statusCode)] for: \(url.absoluteString)")
            print("Server Response: \(errorString)")
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
    
    // Internal Cache
    var cachedWallpapers: [Wallpaper] = []
    private var screenChangeTimer: Timer?
    
    /// Re-processes the current wallpapers with new settings (without fetching new ones)
    func refreshDisplay() {
        if !cachedWallpapers.isEmpty {
            processWallpapers(cachedWallpapers, checkDateContext: false)
        } else {
            checkForUpdates()
        }
    }
    
    private init() {
        // Init State
        self.useSameWallpaper = UserDefaults.standard.object(forKey: Constants.useSameWallpaperKey) as? Bool ?? true
        
        if let saved = UserDefaults.standard.array(forKey: Constants.selectedChannelsKey) as? [String] {
            self.selectedChannels = Set(saved)
        } else {
            self.selectedChannels = Set(Constants.defaultChannels)
        }
        
        self.fitVerticalDisplays = UserDefaults.standard.object(forKey: Constants.fitVerticalKey) as? Bool ?? true
        
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
                
                self.processWallpapers(wallpapers, checkDateContext: true)
                
            } catch {
                print("Update Error: \(error)")
                self.currentStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func surpriseMe() {
        self.currentStatus = "Fetching randoms..."
        
        Task {
            do {
                // Determine how many wallpapers we need
                // If "Same on all", we need 1. If separate, we need one for each screen.
                let screenCount = NSScreen.screens.count
                let countNeeded = self.useSameWallpaper ? 1 : max(1, screenCount)
                
                var newRandoms: [Wallpaper] = []
                
                // Fetch concurrently for speed
                try await withThrowingTaskGroup(of: Wallpaper.self) { group in
                    for _ in 0..<countNeeded {
                        group.addTask {
                            return try await self.networkService.fetchRandom(channels: self.selectedChannels)
                        }
                    }
                    for try await random in group {
                        newRandoms.append(random)
                    }
                }
                
                // Sort to ensure deterministic order if needed, or just append. 
                // Random is random, order doesn't matter much, but let's just use the array.
                
                print("Fetched \(newRandoms.count) random wallpapers.")
                
                if let heroRandom = newRandoms.first {
                    // Update Cache
                    // Insert ALL new randoms at the top.
                    // This ensures Screen 0 gets newRandoms[0], Screen 1 gets newRandoms[1], etc.
                    self.cachedWallpapers.insert(contentsOf: newRandoms, at: 0)
                    
                    // Persist ONLY the Hero (Screen 0) for the "Daily Lock" logic.
                    // Note: Secondary screens' surprise is ephemeral (lasts until app restart/refresh), 
                    // but that is expected for "Surprise" vs "Schedule".
                    // FIX: "contains" syntax error. newRandoms is [Wallpaper], so we need to check IDs carefully.
                    let latestDailyDate = self.cachedWallpapers.first(where: { w in
                        !newRandoms.contains(where: { $0.id == w.id })
                    })?.releaseDate?.prefix(10) ?? "unknown"
                    // Fallback to current if history is empty, though unlikely
                    let safeDate = (latestDailyDate == "unknown") ? (heroRandom.releaseDate?.prefix(10) ?? "unknown") : latestDailyDate
                    
                    defaults.set(heroRandom.id, forKey: Constants.overrideWallpaperIdKey)
                    defaults.set(String(safeDate), forKey: Constants.overrideContextIdKey)
                    
                    if let data = try? JSONEncoder().encode(heroRandom) {
                        defaults.set(data, forKey: Constants.overrideWallpaperKey)
                    }
                    
                    // Refresh Display
                    self.processWallpapers(self.cachedWallpapers, checkDateContext: false)
                }
                
            } catch {
                print("Surprise Error: \(error)")
                self.currentStatus = "Surprise failed."
            }
        }
    }

    // MARK: - Logic
    
    /// Main Logic Engine: Map Data -> Screens
    private func processWallpapers(_ wallpapers: [Wallpaper], checkDateContext: Bool) {
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
            let urlOrNil = imageService.generateUrl(for: wallpaper, screen: screen, fitToVertical: self.fitVerticalDisplays)
            
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
                        try imageService.applyToScreen(localUrl: localPath, screen: screen)
                        if screen == mainScreen { self.currentStatus = "Updated!" }
                    } catch {
                        print("Failed screen \(index): \(error)")
                    }
                }
            }
        }
        
        self.screenWallpapers = newInfos
        if checkDateContext {
            cleanupOverrides(currentLatestId: wallpapers.first?.id)
        }
    }
    
    private func determineWallpaper(for screenIndex: Int, from wallpapers: [Wallpaper]) -> Wallpaper {
        // 1. Determine the "Hero" wallpaper (Effectively the "Current" one to display)
        // Default to the top of the list
        var heroWallpaper = wallpapers.first ?? Wallpaper(id: "empty", url: "", name: "Error", description: nil, externalUrl: nil, channel: nil, releaseDate: nil)
        if !wallpapers.isEmpty { heroWallpaper = wallpapers[0] }
        
        // Check Validity of Override (Date Persistence)
        let latestDate = wallpapers.first?.releaseDate?.prefix(10) ?? "unknown"
        let savedContextDate = defaults.string(forKey: Constants.overrideContextIdKey)
        let savedOverrideId = defaults.string(forKey: Constants.overrideWallpaperIdKey)
        
        // If Override exists and matches today's date, it becomes the Hero
        if let oId = savedOverrideId, let cDate = savedContextDate, cDate == latestDate {
            if let overrideItem = wallpapers.first(where: { $0.id == oId }) {
                heroWallpaper = overrideItem
            } else if let data = defaults.data(forKey: Constants.overrideWallpaperKey),
                      let savedWallpaper = try? JSONDecoder().decode(Wallpaper.self, from: data),
                      savedWallpaper.id == oId {
                 // Restoration from persistence (Surprise Me case)
                 heroWallpaper = savedWallpaper
            }
        }
        
        // 2. Logic Distribution
        if useSameWallpaper {
            // Apply Hero to all screens
            return heroWallpaper
        } else {
            // Separate Screens
            if screenIndex == 0 {
                return heroWallpaper
            }
            // Other screens show history flow
            // Note: If hero IS wallpapers[0], this is seamless.
            // If hero is an override, Screen 1 shows wallpapers[1] (Yesterday's), etc.
            let idx = min(screenIndex, wallpapers.count - 1)
            return wallpapers[idx]
        }
    }
    
    private func cleanupOverrides(currentLatestId: String?) {
        // We need the full wallpaper object or just fetch it from cache, usually `processWallpapers` updates cache first.
        let currentLatestDate = self.cachedWallpapers.first?.releaseDate?.prefix(10) ?? "unknown"
        let savedContextDate = defaults.string(forKey: Constants.overrideContextIdKey)
        
        if savedContextDate != nil && savedContextDate != String(currentLatestDate) {
            print("New daily DATE detected (\(currentLatestDate)). Clearing overrides.")
            defaults.removeObject(forKey: Constants.overrideContextIdKey)
            defaults.removeObject(forKey: Constants.overrideWallpaperIdKey)
            defaults.removeObject(forKey: Constants.overrideWallpaperKey)
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
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
        
        // 2. Backup check (15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            print("Wake Check 2 (15s)")
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
        
        // 3. Final safety check (30s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            print("Wake Check 3 (30s)")
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
    }
    
    @objc func handleScreenChange() {
        print("Screen Change.")
        screenChangeTimer?.invalidate()
        screenChangeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkForUpdates() }
        }
    }
}

import ServiceManagement

// ... (Existing Imports)

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
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal)
                .padding(.top, 10)
            
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
                    title: "Fit on vertical displays",
                    description: "Shows full image with background fill",
                    isOn: $manager.fitVerticalDisplays
                )
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
                            print("Failed to update Launch at Login: \(error)")
                        }
                    }
            }
            
            // Footer
            HStack(spacing: 5) {
                // Version (Clickable to check for updates)
                Button(action: {
                    updater.checkForUpdates()
                }) {
                    Text("v\(appVersion)")
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
                    Text("All OK")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Refresh Action
                Button("Refresh") {
                    manager.checkForUpdates()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .padding()
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            // Force app to front when settings window appears
            NSApp.activate(ignoringOtherApps: true)
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
            .frame(width: 320)
    }
}

@main
struct BasaltApp: App {
    @StateObject var manager = WallpaperManager.shared
    
    // Timer is likely unnecessary if we rely on Wake/Notifications, 
    // but good as a fallback if the app stays open for days without sleep.
    let timer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    var body: some Scene {
        MenuBarExtra("Basalt", image: "MenuBarIcon") {
            // Simplified Menu
            Button("🎲 Surprise me") { manager.surpriseMe() }
            Divider()
            
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
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

