import SwiftUI
import AppKit
import Combine

// 1. DATA MODEL
struct Wallpaper: Codable, Sendable {
    let id: String
    let url: String
    let description: String?
}

struct ScreenWallpaperInfo: Identifiable {
    let id = UUID()
    let displayName: String
    let wallpaperName: String
}

// 2. THE LOGIC MANAGER
@MainActor
class WallpaperManager: ObservableObject {
    @Published var currentStatus: String = "Ready"
    @Published var screenWallpapers: [ScreenWallpaperInfo] = []
    
    // URL for the list of wallpapers
    let manifestUrl = URL(string: "https://wall-ball-production.up.railway.app/api/wallpapers")!
    
    private let defaults = UserDefaults.standard
    
    func checkForUpdates() {
        self.currentStatus = "Checking for new wallpapers..."
        
        Task.detached { [manifestUrl] in
            do {
                // 1. Download JSON List
                let (data, _) = try await URLSession.shared.data(from: manifestUrl)
                
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
                await MainActor.run {
                    WallpaperManager.shared.currentStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    static let shared = WallpaperManager()
    
    init() {}
    
    func processWallpapers(_ wallpapers: [Wallpaper]) {
        let screens = NSScreen.screens
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
            let wallpaperIndex = min(index, wallpapers.count - 1)
            let wallpaper = wallpapers[wallpaperIndex]
            
            // "Disp 1", "Disp 2", etc.
            let name = "Disp \(index + 1)"
            let desc = wallpaper.description ?? "Untitled"
            
            newInfos.append(ScreenWallpaperInfo(displayName: name, wallpaperName: desc))
            
            downloadAndSet(wallpaper: wallpaper, for: screen)
        }
        
        self.screenWallpapers = newInfos
    }
    
    func downloadAndSet(wallpaper: Wallpaper, for screen: NSScreen) {
        // 1. Calculate Resolution
        let width = Int(screen.frame.width * screen.backingScaleFactor)
        let height = Int(screen.frame.height * screen.backingScaleFactor)
        
        // 2. Inject Transformation into URL
        let originalUrl = wallpaper.url
        guard let modifiedUrl = injectCloudinaryParams(url: originalUrl, width: width, height: height) else {
            print("Failed to create modified URL for \(originalUrl)")
            return
        }
        
        // 3. Unique Filename
        let filename = "wallpaper_\(wallpaper.id)_\(width)x\(height).jpg"
        
        Task.detached {
            do {
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent(filename)
                
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    let (tempUrl, _) = try await URLSession.shared.download(from: modifiedUrl)
                    
                    // Validate file size (avoid setting error html/json as wallpaper)
                    let attr = try fileManager.attributesOfItem(atPath: tempUrl.path)
                    let size = attr[.size] as? Int64 ?? 0
                    if size < 1000 {
                        print("Downloaded file is too small (\(size) bytes). Likely an error. URL: \(modifiedUrl)")
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
    
    func injectCloudinaryParams(url: String, width: Int, height: Int) -> URL? {
        let keyword = "/upload/"
        guard let range = url.range(of: keyword) else {
            return URL(string: url)
        }
        
        // Fix: Removed leading slash to avoid double slash
        let params = "w_\(width),h_\(height),c_fill/"
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
        MenuBarExtra("Curated", systemImage: "photo.on.rectangle") {
            VStack(alignment: .leading) {
                Text("Curated Wallpaper")
                    .font(.headline)
                Divider()
                
                ForEach(manager.screenWallpapers) { info in
                    Text("\(info.displayName): \(info.wallpaperName)")
                }
                
                if manager.screenWallpapers.isEmpty {
                    Text("No displays detected")
                        .foregroundColor(.gray)
                }
                
                Divider()
                Text("Status: \(manager.currentStatus)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Divider()
                Button("Check Now") {
                    manager.checkForUpdates()
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .onAppear {
                manager.checkForUpdates()
            }
            .onReceive(timer) { _ in
                manager.checkForUpdates()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
