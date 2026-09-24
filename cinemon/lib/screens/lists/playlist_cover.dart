import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';

/// A playlist's cover, drawn from its first posters (ADR 0001, D4).
///
/// - Four or more: a 2×2 mosaic.
/// - One to three: the first poster, over a blurred copy of itself.
/// - None: a glass tile with a stack glyph.
///
/// Square, at any size, so the same widget serves rails, headers and the
/// live preview in the editor.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.posters,
    this.size = 120,
    this.radius,
  });

  /// TMDB poster paths, in list order. Nulls (no poster) are skipped.
  final List<String?> posters;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final paths = posters.whereType<String>().toList();
    final r = BorderRadius.circular(radius ?? size * 0.1);
    final imageSize = size > 160
        ? ApiConstants.posterSizeMedium
        : ApiConstants.posterSizeSmall;
    String url(String p) => ApiConstants.getPosterUrl(p, size: imageSize);

    final Widget content;
    if (paths.length >= 4) {
      content = GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        // Posters are 2:3; each quarter crops to square around the middle.
        children: [for (final p in paths.take(4)) _Img(url: url(p))],
      );
    } else if (paths.isNotEmpty) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: _Img(url: url(paths.first)),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: Container(
              width: size * 0.5,
              height: size * 0.75,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.04),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: size * 0.08,
                    offset: Offset(0, size * 0.03),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.04),
                child: _Img(url: url(paths.first)),
              ),
            ),
          ),
        ],
      );
    } else {
      content = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Center(
          child: Icon(CupertinoIcons.square_stack_fill,
              size: size * 0.32, color: AppColors.inkTertiary),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: ClipRRect(borderRadius: r, child: content),
    );
  }
}

class _Img extends StatelessWidget {
  const _Img({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: AppColors.surface),
      errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surface),
    );
  }
}
