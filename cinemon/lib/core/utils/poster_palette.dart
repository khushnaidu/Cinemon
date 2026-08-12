import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Two colours pulled out of a poster, for lighting the space around it.
///
/// Deliberately not a full [ColorScheme]. Nothing here is text or a surface —
/// these only ever get painted as low-opacity glow on black, so what matters
/// is that the hue is recognisably the poster's and that it survives being
/// dimmed. Both are normalised to a usable saturation and full value for that
/// reason: a muted poster should still throw a visible, correctly-hued light.
@immutable
class PosterPalette {
  const PosterPalette({required this.primary, required this.secondary});

  /// The dominant hue, weighted toward vivid pixels.
  final Color primary;

  /// The strongest hue at least [_kHueSeparation] away from [primary], so the
  /// accents read as a second colour rather than more of the first.
  final Color secondary;

  /// What a poster with no usable colour gets: warm projector white. Black and
  /// white artwork still deserves a beam, it just shouldn't be tinted.
  static const neutral = PosterPalette(
    primary: Color(0xFFE8DCC8),
    secondary: Color(0xFFBFC6D4),
  );
}

/// Palette for a poster URL, computed once and kept for the session.
///
/// Not autoDispose: the feed is a PageView, so scrolling back to a card
/// rebuilds it, and re-decoding the poster to recompute two colours would
/// re-run the fade every time.
final posterPaletteProvider =
    FutureProvider.family<PosterPalette, String>((ref, url) async {
  if (url.isEmpty) return PosterPalette.neutral;
  try {
    return await _extract(url);
  } catch (_) {
    // A palette is decoration. If the image can't be read, the card still
    // works — it just sits on plain black.
    return PosterPalette.neutral;
  }
});

/// Side of the grid the poster is reduced to before counting hues.
///
/// Small on purpose. The bilinear downsample is doing the averaging that a
/// proper quantiser would otherwise do pixel by pixel, and 32x48 is already
/// finer than a glow can express.
const int _kSampleWidth = 32;
const int _kSampleHeight = 48;

/// Hue buckets, 15 degrees each.
const int _kBuckets = 24;

/// How far the secondary hue must sit from the primary, in degrees.
const double _kHueSeparation = 40;

/// Pixels darker or greyer than these carry no hue worth reading — they'd just
/// drag the average toward whatever the shadows are.
const double _kMinValue = 0.18;
const double _kMinSaturation = 0.20;

Future<PosterPalette> _extract(String url) async {
  final image = await _resolve(CachedNetworkImageProvider(url));
  try {
    final pixels = await _downsample(image, _kSampleWidth, _kSampleHeight);
    if (pixels == null) return PosterPalette.neutral;
    return _quantise(pixels);
  } finally {
    image.dispose();
  }
}

/// Waits for an [ImageProvider] to produce a decoded frame.
Future<ui.Image> _resolve(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      // The ImageInfo owns a handle we don't; clone before releasing it, or
      // the underlying image can be collected out from under us.
      if (!completer.isCompleted) completer.complete(info.image.clone());
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Redraws [image] into a tiny buffer and hands back its raw RGBA.
///
/// Reading the full-size poster instead would mean pulling ~1.5MB per card
/// through toByteData and then walking 375k pixels. Letting the GPU box-filter
/// it down first costs one draw and leaves 1.5k pixels to count.
Future<Uint8List?> _downsample(ui.Image image, int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    final small = await picture.toImage(width, height);
    try {
      final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data?.buffer.asUint8List();
    } finally {
      small.dispose();
    }
  } finally {
    picture.dispose();
  }
}

PosterPalette _quantise(Uint8List rgba) {
  final weights = List<double>.filled(_kBuckets, 0);
  final hues = List<double>.filled(_kBuckets, 0);
  final saturations = List<double>.filled(_kBuckets, 0);

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 200) continue;
    final hsv = HSVColor.fromColor(
      Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]),
    );
    if (hsv.value < _kMinValue || hsv.saturation < _kMinSaturation) continue;

    // Vivid pixels count for more than washed-out ones, so a small saturated
    // area beats a large murky one — which is what the eye does too.
    final weight = hsv.saturation * hsv.value;
    final bucket = (hsv.hue / 360 * _kBuckets).floor().clamp(0, _kBuckets - 1);
    weights[bucket] += weight;
    hues[bucket] += hsv.hue * weight;
    saturations[bucket] += hsv.saturation * weight;
  }

  final total = weights.fold<double>(0, (sum, w) => sum + w);
  // Under a twentieth of the sampled area carrying any colour at all means
  // greyscale artwork, near enough.
  if (total < _kSampleWidth * _kSampleHeight * 0.05) {
    return PosterPalette.neutral;
  }

  final primary = _strongest(weights);
  final primaryHue = hues[primary] / weights[primary];

  var secondary = -1;
  for (var i = 0; i < _kBuckets; i++) {
    if (weights[i] <= 0) continue;
    final hue = hues[i] / weights[i];
    if (_hueDistance(hue, primaryHue) < _kHueSeparation) continue;
    if (secondary == -1 || weights[i] > weights[secondary]) secondary = i;
  }

  final primaryColor =
      _glow(primaryHue, saturations[primary] / weights[primary]);
  return PosterPalette(
    primary: primaryColor,
    secondary: secondary == -1
        // Single-hue poster. Rather than invent a colour that isn't in the
        // artwork, offset slightly — enough for the accents to separate from
        // the beam without reading as a different film.
        ? _glow(primaryHue + 24, saturations[primary] / weights[primary] * 0.8)
        : _glow(
            hues[secondary] / weights[secondary],
            saturations[secondary] / weights[secondary],
          ),
  );
}

int _strongest(List<double> weights) {
  var best = 0;
  for (var i = 1; i < weights.length; i++) {
    if (weights[i] > weights[best]) best = i;
  }
  return best;
}

double _hueDistance(double a, double b) {
  final delta = (a - b).abs() % 360;
  return delta > 180 ? 360 - delta : delta;
}

/// Full value, clamped saturation. Brightness is the painter's job — it comes
/// from opacity, so the colour itself should always be at its most legible.
Color _glow(double hue, double saturation) => HSVColor.fromAHSV(
      1,
      hue % 360,
      saturation.clamp(0.42, 0.80),
      1,
    ).toColor();
