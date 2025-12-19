//
//  Updater.swift
//  Curated Walpaper
//
//  Created for Hybrid Release (MAS + Direct).
//

import SwiftUI
import Combine

#if canImport(Sparkle)
import Sparkle
#endif

/// A wrapper specifically for the "Direct" distribution.
/// In MAS builds, this does effectively nothing or returns empty views.
final class Updater: NSObject, ObservableObject {
    static let shared = Updater()
    
    @Published var updateAvailable: Bool = false
    
    #if canImport(Sparkle)
    private var controller: SPUStandardUpdaterController? // Changed to var/optional to allow lazy init if needed, but keeping simple for now
    #endif
    
    override init() {
        super.init()
        #if canImport(Sparkle)
        // Initialize Sparkle with standard user driver
        // We pass 'self' as the updaterDelegate to intercept events
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        #endif
    }
    
    /// Trigger a check for updates (Action for Menu Item)
    func checkForUpdates() {
        #if canImport(Sparkle)
        controller?.updater.checkForUpdates()
        #else
        print("Update check ignored: Sparkle not available (likely MAS build).")
        #endif
    }
    
    /// Returns true if the updater allows checking for updates
    var canCheckForUpdates: Bool {
        #if canImport(Sparkle)
        return controller?.updater.canCheckForUpdates ?? false
        #else
        return false
        #endif
    }
}

// MARK: - Sparkle Delegate
#if canImport(Sparkle)
extension Updater: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        // A valid update was found
        DispatchQueue.main.async {
            self.updateAvailable = true
        }
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        // No update found
        DispatchQueue.main.async {
            self.updateAvailable = false
        }
    }
}
#endif
