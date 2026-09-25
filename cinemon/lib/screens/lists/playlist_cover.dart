import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/list_model.dart';

/// A playlist's cover (ADR 0001 D4, reworked with migration 029).
///
/// - [ListCoverStyle.strip], the default: up to six posters side by side,
///   so every list looks like its own films. One poster sits over a blurred
///   copy of itself; none is a glass tile with a stack glyph.
/// - [ListCoverStyle.film]: the one image the curator picked ([coverPath]).
/// - [ListCoverStyle.artwork]: our own art for a 35mm Select ([coverUrl]).
///
/// Square by default, at any size, so the same widget serves rails and the
/// editor's preview; give [height] for a wider banner.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.posters,
    this.size = 120,
    this.height,
    this.radius,
    this.style = ListCoverStyle.strip,
    this.coverPath,
    this.coverUrl,
  });

  /// A list's cover as its owner set it.
  factory PlaylistCover.of(
    FilmList list, {
    Key? key,
    required List<String?> posters,
    double size = 120,
    double? height,
    double? radius,
  }) =>
      PlaylistCover(
        key: key,
        posters: posters,
        size: size,
        height: height,
        radius: radius,
        style: list.coverStyle,
        coverPath: list.coverPath,
        coverUrl: list.coverUrl,
      );

  /// TMDB poster paths, in list order. Nulls (no poster) are skipped.
  final List<String?> posters;
  final double size;
  final double? height;
  final double? radius;
  final ListCoverStyle style;
  final String? coverPath;
  final String? coverUrl;

  static const maxStrips = 6;

  @override
  Widget build(BuildContext context) {
    final h = height ?? size;
    final paths = posters.whereType<String>().toList();
    final r = BorderRadius.circular(radius ?? size * 0.1);
    final imageSize = size > 160
        ? ApiConstants.posterSizeMedium
        : ApiConstants.posterSizeSmall;
    String url(String p) => ApiConstants.getPosterUrl(p, size: imageSize);

    final Widget content;
    if (style == ListCoverStyle.artwork && coverUrl != null) {
      content = _Img(url: coverUrl!);
    } else if (style == ListCoverStyle.film && coverPath != null) {
      // A poster or a still; w780 exists for both.
      content = _Img(
          url: ApiConstants.getBackdropUrl(coverPath,
              size: ApiConstants.backdropSizeMedium));
    } else if (paths.length >= 2) {
      final shown = paths.take(maxStrips).toList();
      content = ColoredBox(
        color: Colors.black,
        child: Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) SizedBox(width: size > 160 ? 2 : 1),
              Expanded(child: _Img(url: url(shown[i]))),
            ],
          ],
        ),
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
              width: h * 0.5,
              height: h * 0.75,
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
              size: h * 0.32, color: AppColors.inkTertiary),
        ),
      );
    }

    return Container(
      width: size,
      height: h,
      decoration: BoxDecoration(
        borderRadius: r,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
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
