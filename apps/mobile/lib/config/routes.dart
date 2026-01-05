import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/collections/collections_screen.dart';
import '../screens/collections/collection_detail_screen.dart';
import '../screens/wallpapers/wallpaper_detail_screen.dart';
import '../models/wallpaper.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CollectionsScreen(),
      routes: [
        GoRoute(
          path: 'collection/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CollectionDetailScreen(collectionId: id);
          },
          routes: [
            GoRoute(
              path: 'wallpaper',
              builder: (context, state) {
                 final wallpaper = state.extra as Wallpaper;
                 return WallpaperDetailScreen(wallpaper: wallpaper);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
