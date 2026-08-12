import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Photos taken with a review, piled up like prints on a table.
///
/// Deliberately not a grid or a row. Four photos laid out evenly would read as
/// an attachment list; fanned and overlapping, they read as objects someone
/// put down — and a pile takes one thumbnail's worth of space no matter how
/// many are in it, which is what lets them sit in the corner of a card that
/// has no room to spare.
class ReviewPhotoStack extends StatelessWidget {
  const ReviewPhotoStack({
    super.key,
    required this.urls,
    required this.tint,
    this.size = 56,
  });

  final List<String> urls;
  final Color tint;

  /// Edge of the topmost print. The pile as a whole is slightly larger, since
  /// the ones underneath are offset out from it.
  final double size;

  /// How far each print below the top is nudged, in points.
  static const _offset = 5.0;

  /// Rotation of each print, in radians, from the top down. Fixed rather than
  /// random so a card doesn't reshuffle itself every time it's rebuilt.
  static const _angles = [0.045, -0.06, 0.085, -0.035];

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    // Back to front, so the first photo ends up on top of the pile.
    final visible = urls.take(_angles.length).toList();
    final extent = size + _offset * (visible.length - 1) + 6;

    return GestureDetector(
      onTap: () => _open(context, 0),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: extent,
        height: extent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (var i = visible.length - 1; i >= 0; i--)
              Positioned(
                right: i * _offset,
                bottom: i * _offset,
                child: Transform.rotate(
                  angle: _angles[i % _angles.length],
                  child: _Print(
                    url: visible[i],
                    size: size,
                    // Only the top print is worth tinting; the ones behind it
                    // are edges and a sliver of image.
                    tint: i == 0 ? tint : AppColors.separator,
                  ),
                ),
              ),

            // The count, when there's more than one, sitting on the corner of
            // the top print — without it a pile of four is indistinguishable
            // from a pile of two at this size.
            if (urls.length > 1)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.canvas.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.separator, width: 0.5),
                  ),
                  child: Text(
                    '${urls.length}',
                    style: AppText.footnote.copyWith(
                      color: AppColors.ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, int index) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) =>
            _PhotoViewer(urls: urls, initialIndex: index),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

class _Print extends StatelessWidget {
  const _Print({required this.url, required this.size, required this.tint});

  final String url;
  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 1),
        color: AppColors.surfaceElevated,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const Icon(
            CupertinoIcons.photo,
            size: 18,
            color: AppColors.inkTertiary,
          ),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, tap anywhere to leave.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + AppSpace.xl,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.urls.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? AppColors.ink
                              : AppColors.ink.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSpace.sm,
              right: AppSpace.lg,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
