import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let bestAttemptContent = bestAttemptContent else {
            return
        }
        
        // 1. Extract image URL from payload
        // Payload keys: { "image_url": "...", "wallpaper_id": "..." }
        guard let imageUrlString = request.content.userInfo["image_url"] as? String,
              let imageUrl = URL(string: imageUrlString) else {
            contentHandler(bestAttemptContent)
            return
        }
        
        // 2. Download the image
        let task = URLSession.shared.downloadTask(with: imageUrl) { (location, response, error) in
            guard let location = location, error == nil else {
                contentHandler(bestAttemptContent)
                return
            }
            
            // 3. Move to temporary location with correct extension
            let tmpDirectory = NSTemporaryDirectory()
            let tmpFile = "file://".appending(tmpDirectory).appending(imageUrl.lastPathComponent)
            let tmpUrl = URL(string: tmpFile)!
            
            do {
                // Remove existing file if any
                try? FileManager.default.removeItem(at: tmpUrl)
                try FileManager.default.moveItem(at: location, to: tmpUrl)
                
                // 4. Create attachment
                let attachment = try UNNotificationAttachment(identifier: "hero_image", url: tmpUrl, options: nil)
                bestAttemptContent.attachments = [attachment]
            } catch {
                print("Failed to attach image: \(error)")
            }
            
            // 5. Serve content
            contentHandler(bestAttemptContent)
        }
        
        task.resume()
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content,
        // otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
