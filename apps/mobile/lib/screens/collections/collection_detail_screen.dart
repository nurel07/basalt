import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For custom SVG icons
import 'dart:ui'; // For ImageFilter
import 'dart:io'; // For File/Directory
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/wallpaper.dart';
import '../../widgets/vertical_carousel.dart';

enum DownloadStatus { idle, downloading, saved }

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  // Track which wallpaper has the download prompt active
  String? _showDownloadPromptId;
  bool _isFadingOut = false;
  DownloadStatus _downloadStatus = DownloadStatus.idle;

  Future<void> _downloadWallpaper(BuildContext context, String url, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloaded = prefs.getStringList('downloaded_wallpapers') ?? [];
      
      // Download always proceeds as requested (treat as new)
      setState(() {
        _downloadStatus = DownloadStatus.downloading;
        _isFadingOut = false;
      });

      // Check permissions (Gal handles this mostly, but good to know)
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      // Download
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Save to Gallery
      await Gal.putImageBytes(response.data);
      
      // Save ID to storage if not present
      if (!downloaded.contains(id)) {
        downloaded.add(id);
        await prefs.setStringList('downloaded_wallpapers', downloaded);
      }

      if (context.mounted) {
        setState(() {
          _downloadStatus = DownloadStatus.saved;
        });
        
        // Wait 2 seconds before starting fade
        await Future.delayed(const Duration(seconds: 2));
        
        // Verify we are still looking at the same prompt
        if (!context.mounted || _showDownloadPromptId != id) return;

        setState(() {
          _isFadingOut = true;
        });

        // Slow Fade Out (1.5 sec)
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (!context.mounted || _showDownloadPromptId != id) return;

        setState(() {
          _showDownloadPromptId = null;
          _downloadStatus = DownloadStatus.idle;
          _isFadingOut = false;
        });
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _downloadStatus = DownloadStatus.idle;
          _isFadingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving wallpaper: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionDetailsProvider(widget.collectionId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: collectionAsync.when(
        data: (collection) {
          final allWallpapers = collection.wallpapers ?? [];
          // Sort by collectionOrder (ascending)
          allWallpapers.sort((a, b) => a.collectionOrder.compareTo(b.collectionOrder));

          // Skip the first item as it is the cover image
          final wallpapers = allWallpapers.isNotEmpty ? allWallpapers.sublist(1) : <Wallpaper>[];

          if (wallpapers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No wallpapers found', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  )
                ],
              ),
            );
          }

          return Stack(
            children: [
              // 1. Wallpaper Carousel
              VerticalCarousel<Wallpaper>(
                items: wallpapers,
                imageUrlProvider: (wallpaper) => wallpaper.url,
                // Toggle download prompt on tap
                onTap: (wallpaper) {
                  setState(() {
                    _isFadingOut = false; // Reset fade state
                    if (_showDownloadPromptId == wallpaper.id) {
                      _showDownloadPromptId = null;
                    } else {
                      _showDownloadPromptId = wallpaper.id;
                    }
                  });
                },
                foregroundBuilder: (wallpaper) {
                  if (_showDownloadPromptId != wallpaper.id) {
                    return const SizedBox.shrink();
                  }
                  
                  return AnimatedOpacity(
                    opacity: _isFadingOut ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () => _downloadWallpaper(context, wallpaper.url, wallpaper.id),
                      child: _AnimatedDownloadButton(status: _downloadStatus),
                    ),
                  );
                },
                overlayBuilder: (wallpaper) => ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Padding inside overlay
                      color: Colors.black.withOpacity(0.5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wallpaper.name ?? 'Untitled',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.35,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${wallpaper.artist ?? 'Unknown Artist'}, ${wallpaper.creationDate ?? ''}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.35,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isFadingOut = false; // Reset fade
                                _showDownloadPromptId = wallpaper.id;
                              });
                              _downloadWallpaper(context, wallpaper.url, wallpaper.id);
                            },
                            child: SvgPicture.asset(
                              'assets/icons/download.svg',
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              width: 32,
                              height: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Top Navigation Pill
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16, // Align left with padding
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100), // Stadium/Pill shape
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Blur effect
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5), // Semi-transparent
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min, // Wrap content
                          children: [
                            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                            const SizedBox(width: 12),
                            Text(
                              collection.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}

class _AnimatedDownloadButton extends StatefulWidget {
  final DownloadStatus status;
  const _AnimatedDownloadButton({required this.status});

  @override
  State<_AnimatedDownloadButton> createState() => _AnimatedDownloadButtonState();
}

class _AnimatedDownloadButtonState extends State<_AnimatedDownloadButton> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  // Controller for the spinner rotation
  late AnimationController _spinnerController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _controller.forward();
  }
  
  @override
  void didUpdateWidget(_AnimatedDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == DownloadStatus.downloading) {
      _spinnerController.repeat();
    } else {
      _spinnerController.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String text;
    String iconAsset;
    bool isSpinning = false;

    switch (widget.status) {
      case DownloadStatus.idle:
        text = 'Download';
        iconAsset = 'assets/icons/download.svg';
        break;
      case DownloadStatus.downloading:
        text = 'Downloading';
        iconAsset = 'assets/icons/spinner.svg';
        isSpinning = true;
        break;
      case DownloadStatus.saved:
        text = 'Saved to Photos';
        iconAsset = 'assets/icons/image.svg';
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: child,
            );
          },
          child: Container(
            key: ValueKey<DownloadStatus>(widget.status),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.60),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSpinning)
                  RotationTransition(
                    turns: _spinnerController,
                    child: SvgPicture.asset(
                      iconAsset,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      width: 32,
                      height: 32,
                    ),
                  )
                else
                  SvgPicture.asset(
                    iconAsset,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    width: 32,
                    height: 32,
                  ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
