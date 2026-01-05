import 'wallpaper.dart';

class MobileCollection {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String coverImage;
  final int wallpaperCount;
  final List<Wallpaper>? wallpapers;

  MobileCollection({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.coverImage,
    this.wallpaperCount = 0,
    this.wallpapers,
  });

  factory MobileCollection.fromJson(Map<String, dynamic> json) {
    return MobileCollection(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'],
      coverImage: json['coverImage'],
      // Handle _count if present from Prisma
      wallpaperCount: json['_count']?['wallpapers'] ?? 0,
      wallpapers: json['wallpapers'] != null
          ? (json['wallpapers'] as List).map((i) => Wallpaper.fromJson(i)).toList()
          : null,
    );
  }
}
