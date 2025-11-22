import SwiftUI
import AppKit
import Combine // <--- This fixes the "Missing import" errors

// 1. DATA MODELS
// Added 'Sendable' to fix the warning about using this in background threads
struct WallpaperManifest: Codable, Sendable {
    let id: String
    let imageUrl: String
    let title: String
}

// 2. THE LOGIC MANAGER
class WallpaperManager: ObservableObject {
    @Published var currentStatus: String = "Ready"
    @Published var currentTitle: String = "Waiting for update..."
    
    // REPLACE THIS URL WITH YOUR RAW GITHUB JSON URL
    let manifestUrl = URL(string: "https://raw.githubusercontent.com/nurel07/wall-ball/refs/heads/master/daily.json")!
    
    private let defaults = UserDefaults.standard
    
    func checkForUpdates() {
        DispatchQueue.main.async {
            self.currentStatus = "Checking for new wallpaper..."
        }
        
        // Fetch the JSON manifest
        let task = URLSession.shared.dataTask(with: manifestUrl) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { self.currentStatus = "Error: \(error.localizedDescription)" }
                return
            }
            
            guard let data = data else { return }
            
            do {
                // Decoding happens here (background thread)
                let manifest = try JSONDecoder().decode(WallpaperManifest.self, from: data)
                self.processManifest(manifest)
            } catch {
                DispatchQueue.main.async { self.currentStatus = "Data Error: \(error.localizedDescription)" }
            }
        }
        task.resume()
    }
    
    private func processManifest(_ manifest: WallpaperManifest) {
        DispatchQueue.main.async {
            self.currentTitle = manifest.title
        }
        
        // Check if we already have this wallpaper ID saved
        let lastId = defaults.string(forKey: "lastWallpaperId")
        
        if lastId == manifest.id {
            DispatchQueue.main.async { self.currentStatus = "Up to date." }
            return // We already have this one!
        }
        
        // It's new! Download the image.
        downloadImage(from: manifest.imageUrl, id: manifest.id)
    }
    
    private func downloadImage(from urlString: String, id: String) {
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.main.async { self.currentStatus = "Downloading image..." }
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL, error == nil else { return }
            
            do {
                // Move file to a permanent location in the app's sandbox
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsURL.appendingPathComponent("current_wallpaper.jpg")
                
                // Remove old file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                // Set the wallpaper
                self.setWallpaper(imageURL: destinationURL, id: id)
                
            } catch {
                print("File error: \(error)")
            }
        }
        task.resume()
    }
    
    private func setWallpaper(imageURL: URL, id: String) {
        DispatchQueue.main.async {
            do {
                let workspace = NSWorkspace.shared
                
                // Logic to apply to all screens
                for screen in NSScreen.screens {
                    // This is the core macOS command to change wallpaper
                    try workspace.setDesktopImageURL(imageURL, for: screen, options: [:])
                }
                
                // Save the ID so we don't download it again until you change it
                self.defaults.set(id, forKey: "lastWallpaperId")
                self.currentStatus = "Wallpaper updated!"
                
            } catch {
                self.currentStatus = "Failed to set wallpaper."
            }
        }
    }
}

// 3. THE APP ENTRY POINT
@main
struct CuratedWallpaperApp: App {
    // Create an instance of our logic manager
    @StateObject var manager = WallpaperManager()
    
    // Create a timer to check every hour (3600 seconds)
    let timer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
    
    var body: some Scene {
        // MenuBarExtra makes it live in the top bar, not the dock
        MenuBarExtra("Curated", systemImage: "photo.on.rectangle") {
            
            // The tiny menu needed for status
            VStack(alignment: .leading) {
                Text("Curated Wallpaper")
                    .font(.headline)
                Divider()
                Text("Current: \(manager.currentTitle)")
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
            
        }
        // This style makes it a standard dropdown menu
        .menuBarExtraStyle(.menu)
        
        // Logic to run when app starts
        .onChange(of: true) { _ in // Simple trick to run on launch
            manager.checkForUpdates()
        }
        // Logic to run on timer
        .onReceive(timer) { _ in
            manager.checkForUpdates()
        }
    }
}
