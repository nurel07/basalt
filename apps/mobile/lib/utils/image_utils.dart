
class ImageUtils {
  /// Appends Cloudinary transformation parameters to the URL if it's a Cloudinary URL.
  /// 
  /// [width] - target width in pixels (e.g. 1080)
  /// [quality] - target quality (default 'auto')
  /// [format] - target format (default 'auto' -> webp/avif)
  static String getOptimizedUrl(String url, {int? width, String quality = 'auto', String format = 'auto'}) {
    if (!url.contains('cloudinary.com')) {
      return url;
    }

    // Basic implementation: inject transformation params after /upload/
    // Example: .../upload/v123/id -> .../upload/w_1080,q_auto,f_auto/v123/id
    
    // Check if params already exist or we need to insert them
    // Simpler approach for standard Cloudinary URLs:
    final uri = Uri.parse(url);
    final pathSegments = List<String>.from(uri.pathSegments);
    
    // Find 'upload' segment
    final uploadIndex = pathSegments.indexOf('upload');
    if (uploadIndex != -1 && uploadIndex < pathSegments.length - 1) {
      // Build transformation string
      final List<String> transformations = [];
      if (width != null) transformations.add('w_$width');
      transformations.add('q_$quality');
      transformations.add('f_$format');
      
      final transformationString = transformations.join(',');
      
      // Check if next segment is already a transformation (starts with w_, etc not purely v123)
      // Usually Cloudinary urls are /upload/v123/... or /upload/w_.../v123/...
      
      // We will blindly insert after upload. Cloudinary handles multiple transformation blocks usually, 
      // but best to be clean. For now, simple insertion.
      pathSegments.insert(uploadIndex + 1, transformationString);
      
      return uri.replace(pathSegments: pathSegments).toString();
    }

    return url;
  }
}
