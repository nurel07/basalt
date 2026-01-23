import Foundation

/// Utility for optimizing Cloudflare Images URLs with flexible variants
enum CloudflareImageService {
    
    /// Transform options for display (optimized for app UI)
    /// Uses AVIF format with quality 85, width 1200 for Retina displays
    static func displayURL(from originalURL: String) -> String {
        return transformURL(originalURL, options: "w=1200,f=avif,q=85")
    }
    
    /// Transform options for download (original quality)
    /// Uses JPEG format with quality 100, original resolution 1440px
    static func downloadURL(from originalURL: String) -> String {
        return transformURL(originalURL, options: "w=1440,fit=scale-down,f=jpeg,q=100")
    }
    
    /// Applies Cloudflare flexible variant transforms to a URL
    /// Input:  https://imagedelivery.net/HASH/IMAGE_ID/variant
    /// Output: https://imagedelivery.net/HASH/IMAGE_ID/options
    private static func transformURL(_ urlString: String, options: String) -> String {
        guard urlString.contains("imagedelivery.net") else {
            // Not a Cloudflare URL, return as-is
            return urlString
        }
        
        // URL format: https://imagedelivery.net/<HASH>/<IMAGE_ID>/<VARIANT>
        // We need to replace the variant with our transform options
        guard var components = URLComponents(string: urlString),
              var pathComponents = Optional(components.path.split(separator: "/").map(String.init)),
              pathComponents.count >= 3 else {
            return urlString
        }
        
        // Replace the last path component (variant) with our options
        pathComponents[pathComponents.count - 1] = options
        components.path = "/" + pathComponents.joined(separator: "/")
        
        return components.url?.absoluteString ?? urlString
    }
}
