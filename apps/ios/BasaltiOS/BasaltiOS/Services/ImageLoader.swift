import SwiftUI
import Combine

class ImageLoader: ObservableObject {
    @Published var phase: AsyncImagePhase = .empty
    
    private let url: URL
    private let targetSize: CGSize?
    private var cancellable: AnyCancellable?
    private var isLoading = false
    
    private static let processingQueue = DispatchQueue(label: "com.basalt.imageProcessing", qos: .userInitiated)
    private static let cache = NSCache<NSString, UIImage>()
    
    init(url: URL, targetSize: CGSize? = nil) {
        self.url = url
        self.targetSize = targetSize
    }
    
    deinit {
        cancel()
    }
    
    func load() {
        guard !isLoading else { return }
        
        // 1. Memory Cache
        let cacheKey = getCacheKey() as NSString
        if let cachedImage = Self.cache.object(forKey: cacheKey) {
            self.phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        isLoading = true
        
        // 2. Disk Cache or Network
        Self.processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check Disk
            if let data = self.getFromDisk() {
                self.processAndCache(data: data)
                return
            }
            
            // Download
            self.cancellable = URLSession.shared.dataTaskPublisher(for: self.url)
                .map { $0.data }
                .mapError { $0 as Error }
                .receive(on: Self.processingQueue)
                .sink { [weak self] completion in
                    guard let self = self else { return }
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self.phase = .failure(error)
                            self.isLoading = false
                        }
                    }
                } receiveValue: { [weak self] data in
                    guard let self = self, !data.isEmpty else { return }
                    self.saveToDisk(data: data)
                    self.processAndCache(data: data)
                }
        }
    }
    
    func cancel() {
        cancellable?.cancel()
        isLoading = false
    }
    
    private func processAndCache(data: Data) {
        let finalImage: UIImage?
        
        if let targetSize = targetSize {
            finalImage = downsample(data: data, to: targetSize)
        } else {
            finalImage = UIImage(data: data)
        }
        
        if let image = finalImage {
            Self.cache.setObject(image, forKey: getCacheKey() as NSString)
            DispatchQueue.main.async {
                self.phase = .success(Image(uiImage: image))
                self.isLoading = false
            }
        } else {
            DispatchQueue.main.async {
                self.phase = .failure(URLError(.cannotDecodeContentData))
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Caching Helpers
    
    private func getCacheKey() -> String {
        if let size = targetSize {
            return "\(url.absoluteString)-\(Int(size.width))x\(Int(size.height))"
        }
        return url.absoluteString
    }
    
    private func getFromDisk() -> Data? {
        let fileURL = getDiskCacheURL()
        return try? Data(contentsOf: fileURL)
    }
    
    private func saveToDisk(data: Data) {
        let fileURL = getDiskCacheURL()
        try? data.write(to: fileURL)
    }
    
    private func getDiskCacheURL() -> URL {
        let filename = String(format: "%016llx", url.absoluteString.hashValue)
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - Downsampling
    
    private func downsample(data: Data, to pointSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else { return nil }
        
        // Use a fixed scale of 3.0 (Super Retina) to ensure high quality on all devices
        // and avoid the deprecated UIScreen.main usage in background threads.
        let scale: CGFloat = 3.0
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }
        
        return UIImage(cgImage: downsampledImage)
    }
}
