import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/poster_palette.dart';

/// Light thrown by a poster onto the black behind it.
///
/// A soft shaft up the middle with the card sitting in it, a pool under the
/// card's bottom edge, and two small accents off to the sides in a second hue.
/// All of it is painted in colours sampled from the poster itself, so the
/// screen takes on the film rather than the app.
///
/// The whole thing is decoration and behaves like it: nothing is painted until
/// the palette resolves, and a failure to read the image leaves plain black.
class PosterAmbience extends ConsumerStatefulWidget {
  const PosterAmbience({
    super.key,
    required this.posterUrl,
    required this.cardCenter,
    required this.cardSize,
  });

  final String posterUrl;

  /// Where the card sits, in this widget's coordinates — the light is aimed at
  /// it, so it has to follow it rather than assume screen centre.
  final Offset cardCenter;
  final Size cardSize;

  @override
  ConsumerState<PosterAmbience> createState() => _PosterAmbienceState();
}

class _PosterAmbienceState extends ConsumerState<PosterAmbience>
    with TickerProviderStateMixin {
  /// The light coming on, once the palette arrives.
  ///
  /// Long, because this drives geometry as well as opacity — the beacon opens
  /// out of the card and the accents follow it. A pure opacity fade over the
  /// finished shape reads as static no matter how slow it is: nothing is
  /// moving, the whole thing just gets brighter.
  late final AnimationController _reveal = AnimationController(
    duration: const Duration(milliseconds: 1600),
    vsync: this,
  );

  /// A slow drift, so a screen that is otherwise completely static isn't dead.
  /// Long enough and shallow enough that you only notice it if you look for
  /// it — the point is that the light feels lit, not that it moves.
  late final AnimationController _breathe = AnimationController(
    duration: const Duration(seconds: 14),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _reveal.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(posterPaletteProvider(widget.posterUrl));
    final resolved = palette.valueOrNull;

    if (resolved != null && !_reveal.isAnimating && _reveal.value == 0) {
      _reveal.forward();
    }

    if (resolved == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _breathe]),
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _AmbiencePainter(
              palette: resolved,
              // Raw, not curved: each layer takes its own slice of this and
              // eases within it, so the stagger has to be read off a linear
              // clock.
              reveal: _reveal.value,
              breathe: Curves.easeInOut.transform(_breathe.value),
              cardCenter: widget.cardCenter,
              cardSize: widget.cardSize,
            ),
          );
        },
      ),
    );
  }
}

class _AmbiencePainter extends CustomPainter {
  const _AmbiencePainter({
    required this.palette,
    required this.reveal,
    required this.breathe,
    required this.cardCenter,
    required this.cardSize,
  });

  final PosterPalette palette;
  final double reveal;
  final double breathe;
  final Offset cardCenter;
  final Size cardSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;

    // -1..1, so the beacon swells while the accents ebb. Moving everything
    // together would just be a global dimmer.
    final drift = breathe * 2 - 1;
    final cardBottom = cardCenter.dy + cardSize.height / 2;

    _beacon(canvas, size, drift);

    // The pool where the beacon lands, just under the card's bottom edge.
    // Wide and flat, so the shaft reads as ending on something rather than
    // running off the screen. Comes up behind the beacon — the light has to
    // exist before it can land on anything.
    _glow(
      canvas,
      progress: _stagger(0.14, 0.80),
      from: 0.45,
      center: Offset(cardCenter.dx, cardBottom + cardSize.height * 0.05),
      radiusX: cardSize.width * 1.15,
      radiusY: cardSize.height * 0.26,
      color: palette.primary,
      peak: 0.19 + drift * 0.025,
    );

    // Two accents in the second hue, off-axis and unequal, and arriving apart
    // from each other. Matching them would read as a symmetric frame; offset
    // in both place and time, they read as spill.
    _glow(
      canvas,
      progress: _stagger(0.30, 1.0),
      from: 0.55,
      center: Offset(size.width * 0.12, cardCenter.dy - cardSize.height * 0.44),
      radiusX: size.width * 0.46,
      radiusY: size.width * 0.40,
      color: palette.secondary,
      peak: 0.11 - drift * 0.015,
    );
    _glow(
      canvas,
      progress: _stagger(0.45, 1.0),
      from: 0.55,
      center: Offset(size.width * 0.94, cardBottom - cardSize.height * 0.10),
      radiusX: size.width * 0.38,
      radiusY: size.width * 0.34,
      color: palette.secondary,
      peak: 0.09 - drift * 0.012,
    );
  }

  /// One layer's slice of [reveal], eased inside its own window.
  ///
  /// Layers that all start and finish together read as one object fading up.
  /// Overlapping windows are what make it look like light spreading — each
  /// part is still arriving while the next has already started.
  double _stagger(double start, double end) => Curves.easeOutCubic.transform(
        ((reveal - start) / (end - start)).clamp(0.0, 1.0),
      );

  /// The beacon: a shaft of light running the height of the screen with the
  /// card standing in it.
  ///
  /// Built as two crossed gradients rather than one radial falloff, because a
  /// radial glow is round — it can only ever read as a halo behind the poster.
  /// A horizontal ramp gives the shaft its edges and a vertical one fades it
  /// out along its length, and the two have to multiply to get a column of
  /// light. That's the [saveLayer]: draw the colour, then paint the vertical
  /// ramp over it in [BlendMode.dstIn] so it multiplies the alpha already
  /// there. The whole layer then composites additively onto the scene.
  ///
  /// Two shafts, not one. A wide dim column plus a narrow bright core is what
  /// separates a beam from a rectangle — a single ramp is uniform all the way
  /// out, where real light has a hot centre and a long soft skirt.
  void _beacon(Canvas canvas, Size size, double drift) {
    // Geometry runs off the core's clock so the shaft opens as one thing, even
    // though the skirt brightens on its own schedule behind it.
    final opening = _stagger(0, 0.62);
    if (opening <= 0) return;

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.plus);

    // Both shafts start near the width of the card and widen out of it, so the
    // beam looks like it's coming off the poster rather than being switched on
    // around it.
    _shaft(
      canvas,
      size,
      progress: _stagger(0.10, 0.85),
      halfWidth:
          cardSize.width * (1.55 + drift * 0.05) * _lerp(0.42, 1, opening),
      peak: 0.12 + drift * 0.012,
    );
    _shaft(
      canvas,
      size,
      progress: _stagger(0, 0.62),
      halfWidth:
          cardSize.width * (0.66 + drift * 0.03) * _lerp(0.55, 1, opening),
      peak: 0.18 + drift * 0.02,
    );

    // Along-the-shaft falloff. Zero at both page edges on purpose: the feed is
    // a PageView, so anything still lit at the boundary shows as a seam
    // against the next poster's light mid-swipe.
    //
    // Brightest at the card rather than at the middle of the screen — the
    // shaft has to look aimed at the poster, not merely drawn behind it.
    // Stops have to stay inside 0..1 and strictly increasing, so the shoulders
    // are clamped rather than offset blindly from the focus.
    //
    // The shoulders start close to the card and travel out to the page edges,
    // which is the part that actually reads as radiating: the lit length of
    // the shaft grows rather than the whole column brightening at once.
    final focus = (cardCenter.dy / size.height).clamp(0.30, 0.66);
    final rise = math.max(0.02, focus - _lerp(0.06, 0.26, opening));
    final fall = math.min(0.98, focus + _lerp(0.08, 0.34, opening));
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0xD9FFFFFF),
            Color(0xFFFFFFFF),
            Color(0x8CFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, rise, focus, fall, 1],
        ).createShader(bounds),
    );

    canvas.restore();
  }

  /// One vertical column of the beacon, bright down the middle and gone at its
  /// edges. Drawn as a full-height rect so the horizontal ramp lines up with
  /// the shaft exactly at every row.
  void _shaft(
    Canvas canvas,
    Size size, {
    required double progress,
    required double halfWidth,
    required double peak,
  }) {
    final alpha = math.max(0.0, peak) * progress;
    if (alpha <= 0.001) return;

    final rect = Rect.fromLTRB(
      cardCenter.dx - halfWidth,
      0,
      cardCenter.dx + halfWidth,
      size.height,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            palette.primary.withValues(alpha: 0),
            palette.primary.withValues(alpha: alpha * 0.30),
            palette.primary.withValues(alpha: alpha),
            palette.primary.withValues(alpha: alpha * 0.30),
            palette.primary.withValues(alpha: 0),
          ],
          stops: const [0, 0.32, 0.5, 0.68, 1],
        ).createShader(rect),
    );
  }

  /// One elliptical falloff.
  ///
  /// Drawn as a unit circle under a scale rather than as a stretched shader:
  /// [RadialGradient.createShader] resolves its radius against the rect's
  /// shortest side, so an oval rect gives a circle inside an oval, not an
  /// ellipse. Scaling the canvas takes the shader with it.
  ///
  /// The middle stop is what keeps this soft. Two stops give a linear ramp,
  /// which has a visible edge where it lands on black; dropping to a third of
  /// peak by 45% and trailing out from there is closer to how light actually
  /// falls off.
  void _glow(
    Canvas canvas, {
    required double progress,
    required double from,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double peak,
  }) {
    final alpha = math.max(0.0, peak) * progress;
    if (alpha <= 0.001) return;

    // Swells from [from] of its final size as it lights, so it spreads rather
    // than appearing at full extent and getting brighter in place.
    final scale = _lerp(from, 1, progress);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radiusX * scale, radiusY * scale);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        // Additive, so where the beam and an accent overlap the light adds up
        // instead of the top one flattening the one beneath.
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.32),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_AmbiencePainter old) =>
      old.reveal != reveal ||
      old.breathe != breathe ||
      old.palette.primary != palette.primary ||
      old.palette.secondary != palette.secondary ||
      old.cardCenter != cardCenter ||
      old.cardSize != cardSize;
}
