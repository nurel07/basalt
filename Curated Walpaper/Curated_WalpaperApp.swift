import SwiftUI
import AppKit
import Combine

// 1. DATA MODEL
struct Wallpaper: Codable, Sendable {
    let id: String
    let url: String
    let name: String?
    let description: String?
    let externalUrl: String?
    let channel: String?
}

struct ScreenWallpaperInfo: Identifiable {
    var id: String { displayName } // Stable ID to prevent menu glitches
    let displayName: String
    let wallpaperName: String
    let url: URL? // The generated Cloudinary URL
}

// 2. THE LOGIC MANAGER
@MainActor
class WallpaperManager: ObservableObject {
    @Published var currentStatus: String = "Ready"
    @Published var useSameWallpaper: Bool {
        didSet {
            defaults.set(useSameWallpaper, forKey: "useSameWallpaper")
            checkForUpdates() // Refresh immediately when toggled
        }
    }
    @Published var selectedChannels: Set<String> {
        didSet {
            let array = Array(selectedChannels)
            defaults.set(array, forKey: "selectedChannels")
            checkForUpdates()
        }
    }
    
    @Published var screenWallpapers: [ScreenWallpaperInfo] = []
    
    // Cache raw data for random picking
    var cachedWallpapers: [Wallpaper] = []
    
    // Base URL
    let baseUrl = "https://basalt-prod.up.railway.app/api/wallpapers"
    
    private let defaults = UserDefaults.standard
    
    func checkForUpdates() {
        self.currentStatus = "Checking for new wallpapers..."
        
        // Construct URL with channel param
        var components = URLComponents(string: baseUrl)!
        
        // Robustness: If strictly subset, send details. If ALL channels (or empty), send nothing to get all.
        // Currently we have HUMAN and AI.
        // If user selects BOTH, we don't need to filter, just return everything.
        // This avoids sending "HUMAN,AI" to a server that might not support comma-splitting yet.
        let isAllSelected = selectedChannels.contains("HUMAN") && selectedChannels.contains("AI")
        
        if !selectedChannels.isEmpty && !isAllSelected {
            let joined = selectedChannels.joined(separator: ",")
            components.queryItems = [URLQueryItem(name: "channel", value: joined)]
        }
        
        // Append published=true to existing query items or create new array
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "published", value: "true"))
        components.queryItems = queryItems
        
        let manifestUrl = components.url!
        
        Task.detached { [manifestUrl] in
            do {
                // 1. Download JSON List
                let (data, response) = try await URLSession.shared.data(from: manifestUrl)
                
                // Check for HTTP errors
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                     await MainActor.run {
                        WallpaperManager.shared.currentStatus = "Server Error: \(httpResponse.statusCode)"
                    }
                    return
                }

                // 2. Decode Array of Wallpapers
                let wallpapers = try JSONDecoder().decode([Wallpaper].self, from: data)
                
                if wallpapers.isEmpty {
                    await MainActor.run {
                        WallpaperManager.shared.currentStatus = "No wallpapers found."
                    }
                    return
                }
                
                // 3. Process
                await MainActor.run {
                    WallpaperManager.shared.processWallpapers(wallpapers)
                }
            } catch {
                print("Decoding error: \(error)")
                await MainActor.run {
                    WallpaperManager.shared.currentStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    static let shared = WallpaperManager()
    
    init() {
        // Load preferences
        self.useSameWallpaper = UserDefaults.standard.object(forKey: "useSameWallpaper") as? Bool ?? true
        
        // Load channels. Default to BOTH ["HUMAN", "AI"]
        if let saved = UserDefaults.standard.array(forKey: "selectedChannels") as? [String] {
            self.selectedChannels = Set(saved)
        } else {
            self.selectedChannels = ["HUMAN", "AI"]
        }
        
        // Automatically check on launch
        checkForUpdates()
        
        // Listen for System Wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc func handleWake() {
        print("System woke up! Scheduling update check...")
        // Wait 5 seconds for Wi-Fi/Ethernet to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            print("Firing wake-up update check.")
            self?.checkForUpdates()
        }
    }
    
    func toggleChannel(_ channel: String) {
        if selectedChannels.contains(channel) {
            selectedChannels.remove(channel)
        } else {
            selectedChannels.insert(channel)
        }
    }
    
    func processWallpapers(_ wallpapers: [Wallpaper]) {
        self.cachedWallpapers = wallpapers
        // ... (rest of function remains similar, but we need to ensure we filter locally if needed, 
        // though API should have handled it. But wait, if we switch channels, we want to re-fetch.
        // The checkForUpdates does re-fetch.
        
        let screens = NSScreen.screens
        
        if screens.isEmpty {
            self.currentStatus = "No displays found by macOS."
            return
        }
        
        guard let mainScreen = NSScreen.main else { return }
        
        // Sort screens so the main one is first, others follow
        let sortedScreens = screens.sorted { s1, s2 in
            if s1 == mainScreen { return true }
            if s2 == mainScreen { return false }
            return s1.frame.origin.x < s2.frame.origin.x
        }
        
        self.currentStatus = "Updating \(screens.count) screens..."
        var newInfos: [ScreenWallpaperInfo] = []
        
        for (index, screen) in sortedScreens.enumerated() {
            let wallpaper: Wallpaper
            
            // LOGIC FOR CHOOSING WALLPAPER
            var chosenWallpaper: Wallpaper?
            
            // 1. Check for valid Override
            // An override is valid if it exists AND the "Latest Daily" hasn't changed since the override was set.
            let latestDailyId = wallpapers.first?.id ?? ""
            let savedContextId = defaults.string(forKey: "overrideContextId")
            let savedOverrideId = defaults.string(forKey: "overrideWallpaperId")
            
            if let overrideId = savedOverrideId,
               let contextId = savedContextId,
               contextId == latestDailyId,
               let foundOverride = wallpapers.first(where: { $0.id == overrideId }) {
                
                // Override is VALID. Use it.
                // Note: overrides apply to ALL screens if "useSame" is true, or just replaces specific logic?
                // Request implies "don't like today's", so we replace the PRIMARY content.
                chosenWallpaper = foundOverride
            }
            
            if let override = chosenWallpaper {
                wallpaper = override
            } else {
                // 2. Standard Logic
                if useSameWallpaper {
                    // Use the latest (first) wallpaper for everyone
                    wallpaper = wallpapers[0]
                } else {
                    // Use history: Screen 0 -> Wall 0, Screen 1 -> Wall 1, etc.
                    let wallpaperIndex = min(index, wallpapers.count - 1)
                    wallpaper = wallpapers[wallpaperIndex]
                }
            }
            
            // Clear override if invalid (cleanup)
            if savedContextId != nil && savedContextId != latestDailyId {
                print("New daily wallpaper detected! Clearing override.")
                defaults.removeObject(forKey: "overrideContextId")
                defaults.removeObject(forKey: "overrideWallpaperId")
            }
            
            // "Disp 1", "Disp 2", etc.
            let dispName = "Disp \(index + 1)"
            
            // Use Name if available, else Description, else Untitled
            var contentName = wallpaper.name ?? wallpaper.description ?? "Untitled"
            if let name = wallpaper.name, let desc = wallpaper.description, !desc.isEmpty {
                 contentName = "\(name) - \(desc)"
            }
            
            // --- URL GENERATION LOGIC MOVED HERE ---
            
            // 1. Calculate Resolution
            let rawWidth = Int(screen.frame.width * screen.backingScaleFactor)
            let rawHeight = Int(screen.frame.height * screen.backingScaleFactor)
            
            // Cap resolution to avoid Cloudinary limits (max 4K width is safe)
            // Update: 4K was still too large with overlays. Reducing to 2560px (QHD).
            let maxWidth = 2560
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
            
            // 2. Construct Text
            var textParts: [String] = []
            if let name = wallpaper.name, !name.isEmpty { textParts.append(name) }
            if let desc = wallpaper.description, !desc.isEmpty { textParts.append(desc) }
            let overlayText = textParts.joined(separator: ", ")
            
            // Check channel to decide if we show text
            // Default to HUMAN if nil, so we show text
            let isAI = (wallpaper.channel == "AI")
            let showText = !isAI
            
            // 3. Inject Transformation into URL
            let originalUrl = wallpaper.url
            let modifiedUrl = injectCloudinaryParams(url: originalUrl, width: width, height: height, text: overlayText, showText: showText)
            
            // ---------------------------------------
            
            newInfos.append(ScreenWallpaperInfo(displayName: dispName, wallpaperName: contentName, url: modifiedUrl))
            
            if let url = modifiedUrl {
                downloadAndSet(url: url, wallpaperId: wallpaper.id, width: width, height: height, screen: screen)
            } else {
                print("Failed to generate URL for screen \(index)")
            }
        }
        
        self.screenWallpapers = newInfos
    }
    
    func downloadAndSet(url: URL, wallpaperId: String, width: Int, height: Int, screen: NSScreen) {
        // 4. Unique Filename
        let filename = "wallpaper_\(wallpaperId)_\(width)x\(height).jpg"
        
        Task.detached {
            do {
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent(filename)
                
                // CHECK EXISTING FILE
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Validate size. If < 1KB, it's likely corrupt/error page. Delete it.
                    let attr = try? fileManager.attributesOfItem(atPath: destinationURL.path)
                    let size = attr?[.size] as? Int64 ?? 0
                    if size < 1000 {
                        print("Found corrupt cached file (\(size) bytes). Deleting: \(filename)")
                        try? fileManager.removeItem(at: destinationURL)
                    }
                }
                
                // DOWNLOAD IF MISSING (or just deleted)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    let (tempUrl, _) = try await URLSession.shared.download(from: url)
                    
                    // Validate downloaded file size
                    let attr = try fileManager.attributesOfItem(atPath: tempUrl.path)
                    let size = attr[.size] as? Int64 ?? 0
                    if size < 1000 {
                        print("Downloaded file is too small (\(size) bytes). Likely an error. URL: \(url)")
                        return
                    }
                    
                    try fileManager.moveItem(at: tempUrl, to: destinationURL)
                }
                
                await MainActor.run {
                    WallpaperManager.shared.applyWallpaper(url: destinationURL, screen: screen)
                }
            } catch {
                print("Error handling wallpaper for screen \(screen.localizedName): \(error)")
            }
        }
    }
    
    func surpriseMe() {
        print("User clicked Surprise Me. Fetching random wallpaper from server...")
        
        var components = URLComponents(string: "https://basalt-prod.up.railway.app/api/wallpapers/random")!
        var queryItems = [URLQueryItem(name: "published", value: "true")]
        
        // Add channel filter
        let isAllSelected = selectedChannels.contains("HUMAN") && selectedChannels.contains("AI")
        if !selectedChannels.isEmpty && !isAllSelected {
             let joined = selectedChannels.joined(separator: ",")
             queryItems.append(URLQueryItem(name: "channel", value: joined))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else { return }
        
        Task.detached {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("Error fetching random wallpaper: server returned error")
                    return
                }
                
                let randomWall = try JSONDecoder().decode(Wallpaper.self, from: data)
                 
                await MainActor.run {
                    print("Fetched Random: \(randomWall.name ?? "Unknown")")
                    
                    // 1. Manually add to cache so it can be found by ID
                    // We check if it exists, if not, append it.
                    if !WallpaperManager.shared.cachedWallpapers.contains(where: { $0.id == randomWall.id }) {
                        WallpaperManager.shared.cachedWallpapers.insert(randomWall, at: 0) // Prepend? Or append?
                    }
                    
                    // 2. Set Override
                    let latestDailyId = WallpaperManager.shared.cachedWallpapers.first?.id ?? "" // Use existing head as context
                    
                    // Determine context:
                    // If cachedWallpapers was empty (unlikely), we use randomWall.id as context? No.
                    // If the list has items, the first one is the "Daily".
                    // Logic: Override persists until Daily changes.
                    let contextId = WallpaperManager.shared.cachedWallpapers.first(where: { $0.id != randomWall.id })?.id ?? latestDailyId
                    
                    UserDefaults.standard.set(randomWall.id, forKey: "overrideWallpaperId")
                    UserDefaults.standard.set(contextId, forKey: "overrideContextId")
                    
                    // 3. Refresh
                    WallpaperManager.shared.processWallpapers(WallpaperManager.shared.cachedWallpapers)
                }
            } catch {
                print("Failed to fetch random wallpaper: \(error)")
            }
        }
    }
    
    func injectCloudinaryParams(url: String, width: Int, height: Int, text: String, showText: Bool) -> URL? {
        let keyword = "/upload/"
        guard let range = url.range(of: keyword) else {
            return URL(string: url)
        }
        
        // Encode text for URL
        // Cloudinary requires specific escaping for commas and slashes in text layers
        // Standard URL encoding handles most, but we might need to be careful with commas if they are interpreted as separators
        // We use .urlQueryAllowed which encodes spaces as %20, but allows commas. We must manually escape commas.
        // FIX: Double encode commas (%252C) so Cloudinary treats them as literal text, not separators.
        var encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Wallpaper"
        encodedText = encodedText.replacingOccurrences(of: ",", with: "%252C")
        
        // Construct the transformation string
        // 1. Resize
        // 2. Icon Overlay
        // 3. Text Main (Conditional)
        
        let resize = "w_\(width),h_\(height),c_fill"
        
        // User template: l_topbar-icon-white_cwox5b,w_16,h_16,g_south_west,x_8,y_8
        let icon = "l_topbar-icon-white_cwox5b,w_16,h_16,g_south_west,x_8,y_8"
        
        // User template text: l_text:Arial_14:...,co_white,g_south_west,x_34,y_9
        let textMain = "l_text:Arial_14:\(encodedText),co_white,g_south_west,x_34,y_9"
        
        // Combine with slashes
        var params = "\(resize)/\(icon)/"
        
        if showText {
            params += "\(textMain)/"
        }
        
        var newUrlString = url
        newUrlString.insert(contentsOf: params, at: range.upperBound)
        
        return URL(string: newUrlString)
    }
    
    func applyWallpaper(url: URL, screen: NSScreen) {
        do {
            let workspace = NSWorkspace.shared
            try workspace.setDesktopImageURL(url, for: screen, options: [:])
            
            if screen == NSScreen.main {
                self.currentStatus = "Wallpaper updated!"
            }
        } catch {
            print("Failed to set wallpaper: \(error)")
        }
    }
}

// 3. THE APP ENTRY POINT
@main
struct CuratedWallpaperApp: App {
    @StateObject var manager = WallpaperManager.shared
    
    let timer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    var body: some Scene {
        MenuBarExtra("Basalt", image: "MenuBarIcon") {
            Text("Basalt Wallpaper")
                .font(.headline)
            Divider()
            
            ForEach(manager.screenWallpapers) { info in
                Button("\(info.displayName): \(info.wallpaperName)") {
                    if let url = info.url {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(url.absoluteString, forType: .string)
                        print("Copied to clipboard: \(url.absoluteString)")
                    }
                }
            }
            

            
            Divider()
            
            // Multi-select Channels
            
            // Custom Buttons with "Wi-Fi style" styling (Blue when active)
            
            // Using Toggles ensures a checkmark is always visible.
            // We also attempt to color the icon blue if active.
            
            Toggle(isOn: Binding(
                get: { manager.selectedChannels.contains("HUMAN") },
                set: { _ in manager.toggleChannel("HUMAN") }
            )) {
                Text("👁️ Human")
            }
            
            Toggle(isOn: Binding(
                get: { manager.selectedChannels.contains("AI") },
                set: { _ in manager.toggleChannel("AI") }
            )) {
                Text("🤖 AI")
            }
            
            if manager.screenWallpapers.count > 1 {
                Divider()
                
                Toggle("Same on all screens", isOn: $manager.useSameWallpaper)
            }
            
            Divider()
            Text("Status: \(manager.currentStatus)")
            Divider()
            Divider()
            
            Button("🎲 Surprise me") {
                manager.surpriseMe()
            }
            
            Button("Check Now") {
                manager.checkForUpdates()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
