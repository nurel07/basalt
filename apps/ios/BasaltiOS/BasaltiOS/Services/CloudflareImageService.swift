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
        // Handle Cloudinary URLs with appropriate transformations
        if urlString.contains("cloudinary.com") {
            return transformCloudinaryURL(urlString, options: options)
        }
        
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
    
    /// Transforms Cloudinary URLs with appropriate parameters
    /// Input:  https://res.cloudinary.com/.../upload/.../image.jpg
    /// Output: https://res.cloudinary.com/.../upload/w_1200,c_limit,q_auto,f_auto/.../image.jpg
    private static func transformCloudinaryURL(_ urlString: String, options: String) -> String {
        // Parse Cloudinary options from our format
        let isDisplay = options.contains("w=1200")
        let isDownload = options.contains("w=1440")
        
        if isDisplay {
            // Display: optimize for UI with width limit and auto format
            return urlString.replacingOccurrences(of: "/upload/", with: "/upload/w_1200,c_limit,q_auto,f_auto/")
        } else if isDownload {
            // Download: high quality with original dimensions
            return urlString.replacingOccurrences(of: "/upload/", with: "/upload/q_auto:best,f_auto/")
        }
        
        return urlString
    }
}
