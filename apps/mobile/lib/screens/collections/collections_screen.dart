import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/collection.dart';

import '../../widgets/vertical_carousel.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return const Center(child: Text("No collections found"));
          }
          
          return VerticalCarousel<MobileCollection>(
            items: collections,
            imageUrlProvider: (collection) => collection.coverImage,
            onTap: (collection) => context.go('/collection/${collection.id}'),
            overlayBuilder: (collection) => Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.black.withOpacity(0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Free Collection', // TODO: Add type field to model if needed
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${collection.wallpaperCount} Wallpapers',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
