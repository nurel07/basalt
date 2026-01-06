
class ImageUtils {
  /// Optimizes URL for Cloudinary or Cloudflare.
  static String getOptimizedUrl(String url, {int? width, String quality = 'auto', String format = 'auto'}) {
    // 1. Cloudinary
    if (url.contains('cloudinary.com')) {
        return _optimizeCloudinary(url, width: width, quality: quality, format: format);
    }
    
    // 2. Cloudflare Images (imagedelivery.net)
    if (url.contains('imagedelivery.net')) {
        // Cloudflare Images are variant based (e.g. /public, /thumbnail)
        // We can't easily inject W/H params unless we use a Custom Worker.
        // For now, we return the URL as is, or we could switch variants if we knew the ID.
        // Assuming the DB saves the "public" (full quality) variant.
        return url;
    }

    return url;
  }

  static String _optimizeCloudinary(String url, {int? width, String quality, String format}) {
    final uri = Uri.parse(url);
    final pathSegments = List<String>.from(uri.pathSegments);
    
    final uploadIndex = pathSegments.indexOf('upload');
    if (uploadIndex != -1 && uploadIndex < pathSegments.length - 1) {
      final List<String> transformations = [];
      if (width != null) transformations.add('w_$width');
      transformations.add('q_$quality');
      transformations.add('f_$format');
      
      final transformationString = transformations.join(',');
      pathSegments.insert(uploadIndex + 1, transformationString);
      
      return uri.replace(pathSegments: pathSegments).toString();
    }
    return url;
  }
}
