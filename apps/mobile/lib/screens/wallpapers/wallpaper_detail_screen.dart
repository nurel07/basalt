import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/wallpaper.dart';

class WallpaperDetailScreen extends StatelessWidget {
  final Wallpaper wallpaper;

  const WallpaperDetailScreen({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
               showModalBottomSheet(context: context, builder: (context) => Container(
                 padding: const EdgeInsets.all(24),
                 color: Colors.black,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(wallpaper.name ?? "Untitled", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                     const SizedBox(height: 8),
                     if (wallpaper.description != null) Text(wallpaper.description!, style: const TextStyle(color: Colors.white70)),
                     const SizedBox(height: 16),
                     if (wallpaper.artist != null) Text("Artist: ${wallpaper.artist}", style: const TextStyle(color: Colors.white54)),
                     if (wallpaper.creationDate != null) Text("Year: ${wallpaper.creationDate}", style: const TextStyle(color: Colors.white54)),
                   ],
                 ),
               ));
            },
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: wallpaper.id,
            child: CachedNetworkImage(
              imageUrl: wallpaper.url, // Ideally use optimized URL logic here too
              fit: BoxFit.cover,
            ),
          ),
          
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                // Implement Download Logic
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download logic to be implemented")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Download Wallpaper", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
