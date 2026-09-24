import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The shared frame every share card is drawn in (ADR 0003, D1).
///
/// A card is laid out on a fixed 360 × 640 canvas and captured at 3×, which
/// is Instagram's 1080 × 1920. Sizes are written in canvas units, where 1 is
/// 1% of the width. That's the mockups' `cqw`, so numbers carry straight over
/// from `docs/design/share-cards-mockup.html`.
const double kStoryWidth = 360;
const double kStoryHeight = 640;
const double kStoryPixelRatio = 3;

extension StoryUnits on num {
  /// Canvas units to logical pixels.
  double get u => this * kStoryWidth / 100;
}

/// Helvetica Neue is on every iPhone; the cards that want a plainer voice
/// than San Francisco use it (E2, P1, P2, L1).
const String kHelvetica = 'Helvetica Neue';

/// A 9:16 story canvas. Text ignores the reader's text-size setting: the
/// card is an image, and a larger Dynamic Type would only push it off its
/// own edges.
class StoryCanvas extends StatelessWidget {
  const StoryCanvas({
    super.key,
    required this.children,
    this.background = Colors.black,
  });

  final List<Widget> children;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: AppText.body.copyWith(color: Colors.white, height: 1.2),
        child: SizedBox(
          width: kStoryWidth,
          height: kStoryHeight,
          child: ClipRect(
            child: ColoredBox(
              color: background,
              child: Stack(fit: StackFit.expand, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

/// A network image that fills its box. Uses the app's image cache, which the
/// share sheet warms before it lets anyone export (ADR 0003, D1).
class StoryImage extends StatelessWidget {
  const StoryImage(this.url, {super.key, this.alignment = Alignment.center});

  final String url;
  final Alignment alignment;

  /// Lets a test draw cards from local files instead of the network.
  @visibleForTesting
  static ImageProvider Function(String url)? debugProvider;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: AppColors.surface);
    final debug = debugProvider;
    if (debug != null) {
      return Image(image: debug(url), fit: BoxFit.cover, alignment: alignment);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: alignment,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(color: AppColors.surface),
      errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surface),
    );
  }
}

/// The artwork blurred into a wash, the way the hot take card sits on its
/// film's colour.
class StoryBlur extends StatelessWidget {
  const StoryBlur(this.url, {super.key, this.sigma = 26, this.dim = 0.5});

  final String url;
  final double sigma;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
              sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
          child: Transform.scale(scale: 1.3, child: StoryImage(url)),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: dim)),
      ],
    );
  }
}

/// Film grain over the whole card.
class StoryGrain extends StatelessWidget {
  const StoryGrain({super.key, this.opacity = 0.07});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          'assets/share/grain.png',
          repeat: ImageRepeat.repeat,
          scale: 1.4,
          fit: BoxFit.none,
          alignment: Alignment.topLeft,
        ),
      ),
    );
  }
}

/// The 35MM mark and the word "35mm". No URL: the link travels in
/// Instagram's link sticker (ADR 0003, D3).
class StoryBrand extends StatelessWidget {
  const StoryBrand({super.key, this.dark = false, this.label = '35mm'});

  final bool dark;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/share/mark.png', width: 8.u, height: 8.u),
        SizedBox(width: 1.2.u),
        Text(
          label,
          style: TextStyle(
            fontFamily: kHelvetica,
            fontWeight: FontWeight.w700,
            fontSize: 3.8.u,
            letterSpacing: -0.04.u,
            height: 1,
            color: dark
                ? Colors.black.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Who posted it: their photo and handle, with an optional line under it.
class StoryAuthor extends StatelessWidget {
  const StoryAuthor({
    super.key,
    required this.username,
    this.photoUrl,
    this.caption,
  });

  final String username;
  final String? photoUrl;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final size = 7.4.u;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.25), width: 0.5.u),
          ),
          child: ClipOval(
            child: (photoUrl ?? '').isEmpty
                ? Center(
                    child: Text(
                      username.isEmpty ? '?' : username[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 3.4.u, fontWeight: FontWeight.w700),
                    ),
                  )
                : StoryImage(photoUrl!),
          ),
        ),
        SizedBox(width: 2.2.u),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@$username',
                style: TextStyle(
                    fontSize: 3.6.u, fontWeight: FontWeight.w600, height: 1.1)),
            if (caption != null)
              Padding(
                padding: EdgeInsets.only(top: 0.4.u),
                child: Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 3.u,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Five stars with partial fill, in the app's star gold.
class StoryStars extends StatelessWidget {
  const StoryStars({
    super.key,
    required this.rating,
    required this.size,
    this.on = AppColors.gold,
    this.off,
  });

  final double rating;
  final double size;
  final Color on;
  final Color? off;

  @override
  Widget build(BuildContext context) {
    final dim = off ?? Colors.white.withValues(alpha: 0.22);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: size * 0.1),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Icon(CupertinoIcons.star_fill, size: size, color: dim),
                  ClipRect(
                    clipper:
                        _FractionClip((rating - i).clamp(0.0, 1.0).toDouble()),
                    child:
                        Icon(CupertinoIcons.star_fill, size: size, color: on),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FractionClip extends CustomClipper<Rect> {
  const _FractionClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClip old) => old.fraction != fraction;
}

/// A poster tile with the hairline and drop shadow every card uses.
class StoryPoster extends StatelessWidget {
  const StoryPoster({
    super.key,
    required this.url,
    required this.width,
    this.radius,
    this.shadow = true,
  });

  final String url;
  final double width;
  final double? radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? width * 0.04);
    return Container(
      width: width,
      height: width * 1.5,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 8.u,
                  offset: Offset(0, 3.u),
                ),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.14), width: 0.2.u),
      ),
      child: ClipRRect(borderRadius: r, child: StoryImage(url)),
    );
  }
}
