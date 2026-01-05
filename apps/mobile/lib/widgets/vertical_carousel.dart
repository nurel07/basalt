import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../utils/image_utils.dart';

class VerticalCarousel<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) imageUrlProvider;
  final Widget Function(T) overlayBuilder;
  final Widget Function(T)? foregroundBuilder;
  final void Function(T) onTap;

  const VerticalCarousel({
    super.key,
    required this.items,
    required this.imageUrlProvider,
    required this.overlayBuilder,
    this.foregroundBuilder,
    required this.onTap,
  });

  @override
  State<VerticalCarousel<T>> createState() => _VerticalCarouselState<T>();
}

class _VerticalCarouselState<T> extends State<VerticalCarousel<T>> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Start in the middle of the "infinite" list so users can scroll left (up) immediately
    final int initialLoopCount = 1000;
    final int initialPage = widget.items.length * initialLoopCount;
    
    _pageController = PageController(
      viewportFraction: 0.8, // Set height to 80%
      initialPage: initialPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 95% width means 2.5% padding on each side
    final double horizontalPadding = MediaQuery.of(context).size.width * 0.025;
    
    if (widget.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: SizedBox(
        // Full height for vertical swiper so items can take 80% of SCREEN height (via viewportFraction)
        height: MediaQuery.of(context).size.height,
        child: PageView.builder(
          clipBehavior: Clip.none, // Allow cards to overlap outside their bounds (if needed)
          scrollDirection: Axis.vertical,
          controller: _pageController,
          physics: const FastPageScrollPhysics(),
          allowImplicitScrolling: true, // Keep next/prev page in memory
          onPageChanged: (int index) {
            HapticFeedback.selectionClick();
            
            // Aggressive Preloading: Cache the next 5 images
            final int prefetchRange = 5;
            for (int i = 1; i <= prefetchRange; i++) {
              final int nextIndex = (index + i) % widget.items.length;
              final String url = ImageUtils.getOptimizedUrl(
                widget.imageUrlProvider(widget.items[nextIndex]),
                width: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt(), // Match the requested size
              );
              precacheImage(CachedNetworkImageProvider(url), context);
            }
          },
          itemBuilder: (context, index) {
            final itemIndex = index % widget.items.length;
            final item = widget.items[itemIndex];

            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double value = 1.0;
                double dist = 0.0;
                if (_pageController.position.haveDimensions) {
                  dist = _pageController.page! - index;
                  // Scale effect: user requested 0.8 scale for neighbor cards
                  value = (1 - (dist.abs() * 0.2)).clamp(0.9, 1.0);
                } else {
                   value = (index == _pageController.initialPage) ? 1.0 : 0.9;
                }

                return Center(
                  child: Transform.scale(
                    scale: value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 0.0, 
                  horizontal: horizontalPadding
                ),
                child: GestureDetector(
                  onTap: () => widget.onTap(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      color: Colors.grey[900],
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double dist = 0.0;
                              if (_pageController.position.haveDimensions) {
                                dist = _pageController.page! - index;
                              } else {
                                dist = (_pageController.initialPage - index).toDouble();
                              }

                              // Vertical Parallax: move image UP/DOWN based on scroll
                              final double parallaxFactor = 70.0;

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned(
                                      // Normal width (fit cover)
                                      left: 0,
                                      right: 0,
                                      // Overflow vertically for parallax
                                      top: - (constraints.maxHeight * 0.1) + (dist * parallaxFactor),
                                      bottom: - (constraints.maxHeight * 0.1) - (dist * parallaxFactor),
                                      
                                      child: CachedNetworkImage(
                                        imageUrl: ImageUtils.getOptimizedUrl(
                                          widget.imageUrlProvider(item),
                                          width: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt(), // Request exact screen width worth of pixels
                                        ),
                                        // Cache in memory only at the display height to save RAM
                                        memCacheHeight: (MediaQuery.of(context).size.height * MediaQuery.of(context).devicePixelRatio).toInt(),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[900],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white24,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => const Center(
                                          child: Icon(Icons.broken_image,
                                              color: Colors.white24, size: 50),
                                        ),
                                      ),
                                    ),

                                    // Foreground Builder (for custom overlays like download button)
                                    if (widget.foregroundBuilder != null)
                                      Positioned.fill(
                                        child: Center(
                                          child: widget.foregroundBuilder!(item),
                                        ),
                                      ),
                                    
                                    // Custom Overlay Builder
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Opacity(
                                        // Fade out as it moves away from center.
                                        opacity: (1 - (dist.abs() * 2)).clamp(0.0, 1.0),
                                        child: widget.overlayBuilder(item),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FastPageScrollPhysics extends PageScrollPhysics {
  const FastPageScrollPhysics({super.parent});

  @override
  FastPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.9,      // Lighter than default (1.0) means faster acceleration
    stiffness: 600, // Stiffer spring for faster snap
    damping: 36,    // Critical damping (2 * sqrt(mass * stiffness)) to prevent bouncing/oscillation
  );
}
