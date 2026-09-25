import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/poster_palette.dart';
import '../../models/explore_post_model.dart';

/// A critique's colours: the page it's printed on and the inks it's set in.
///
/// Taken from the film's poster, so a piece on Chungking Express reads on
/// deep teal with neon-pink rules and one on Suspiria on oxblood. A critique
/// with no film, or on black-and-white artwork, gets one of the house
/// palettes instead, picked by the post so it's always the same one.
@immutable
class CritiqueColors {
  const CritiqueColors({
    required this.ground,
    required this.glow,
    required this.accent,
    required this.accent2,
  });

  /// The page. Very dark, but the film's hue, not black.
  final Color ground;

  /// A deeper wash of the hue, lit behind the masthead and the pull quote.
  final Color glow;

  /// The main ink: the title in the headline, the drop cap, the end mark.
  final Color accent;

  /// The second ink, from the poster's other colour: rules, the quote mark,
  /// the far end of the progress line.
  final Color accent2;

  /// Body text: white with a breath of the accent in it.
  Color get ink =>
      Color.lerp(Colors.white, accent, 0.08)!.withValues(alpha: 0.9);

  /// Gold on ink, the share card's own. For black-and-white posters and
  /// while a poster's colours are still being read.
  static const classic = CritiqueColors(
    ground: Color(0xFF0B0D0C),
    glow: Color(0xFF2A2419),
    accent: Color(0xFFE6C08A),
    accent2: Color(0xFF9FB4C7),
  );

  /// The house palettes, for critiques about no film in particular.
  static const basics = [
    classic,
    // Oxblood
    CritiqueColors(
      ground: Color(0xFF120909),
      glow: Color(0xFF3D1414),
      accent: Color(0xFFEFA59C),
      accent2: Color(0xFFE6C08A),
    ),
    // Lagoon
    CritiqueColors(
      ground: Color(0xFF061010),
      glow: Color(0xFF113432),
      accent: Color(0xFF8FD8CB),
      accent2: Color(0xFFF0B98C),
    ),
    // Violet hour
    CritiqueColors(
      ground: Color(0xFF0C0A14),
      glow: Color(0xFF2A2145),
      accent: Color(0xFFC6B4F5),
      accent2: Color(0xFFF2B3C9),
    ),
    // Moss
    CritiqueColors(
      ground: Color(0xFF0A0D07),
      glow: Color(0xFF242E15),
      accent: Color(0xFFCFDC9C),
      accent2: Color(0xFFE6C08A),
    ),
    // Cobalt
    CritiqueColors(
      ground: Color(0xFF070A14),
      glow: Color(0xFF17244D),
      accent: Color(0xFF9FBCF7),
      accent2: Color(0xFFF3C58D),
    ),
  ];

  /// One of [basics], the same every time for the same [seed].
  static CritiqueColors basicFor(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return basics[h % basics.length];
  }

  /// The inks from a poster's two hues. Lightness is set here rather than
  /// taken from the poster, so every film's page is as readable as the next.
  factory CritiqueColors.fromPalette(PosterPalette p) {
    if (identical(p, PosterPalette.neutral)) return classic;
    final a = HSLColor.fromColor(p.primary);
    final b = HSLColor.fromColor(p.secondary);
    final s = a.saturation.clamp(0.45, 0.8);
    return CritiqueColors(
      ground: HSLColor.fromAHSL(1, a.hue, (s * 0.5).clamp(0.2, 0.4), 0.055)
          .toColor(),
      glow: HSLColor.fromAHSL(1, a.hue, (s * 0.8).clamp(0.3, 0.6), 0.17)
          .toColor(),
      accent: HSLColor.fromAHSL(1, a.hue, s, 0.74).toColor(),
      accent2: HSLColor.fromAHSL(1, b.hue, b.saturation.clamp(0.4, 0.75), 0.68)
          .toColor(),
    );
  }

  static CritiqueColors lerp(CritiqueColors a, CritiqueColors b, double t) =>
      CritiqueColors(
        ground: Color.lerp(a.ground, b.ground, t)!,
        glow: Color.lerp(a.glow, b.glow, t)!,
        accent: Color.lerp(a.accent, b.accent, t)!,
        accent2: Color.lerp(a.accent2, b.accent2, t)!,
      );

  static CritiqueColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()?.colors ?? classic;

  @override
  bool operator ==(Object other) =>
      other is CritiqueColors &&
      other.ground == ground &&
      other.glow == glow &&
      other.accent == accent &&
      other.accent2 == accent2;

  @override
  int get hashCode => Object.hash(ground, glow, accent, accent2);
}

class _Tween extends Tween<CritiqueColors> {
  _Tween({super.end});

  @override
  CritiqueColors lerp(double t) => CritiqueColors.lerp(begin!, end!, t);
}

class _Scope extends InheritedWidget {
  const _Scope({required this.colors, required super.child});

  final CritiqueColors colors;

  @override
  bool updateShouldNotify(_Scope old) => old.colors != colors;
}

/// Gives [builder] and everything under it the critique's colours, easing
/// from gold on ink to the film's once its poster has been read.
class CritiqueColorScope extends ConsumerWidget {
  const CritiqueColorScope({
    super.key,
    required this.subject,
    required this.seed,
    required this.builder,
  });

  final ExploreSubject? subject;

  /// Picks the house palette when there's no film: the post's id.
  final String seed;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = subject?.posterUrl ?? '';
    final CritiqueColors target;
    if (poster.isEmpty) {
      target = CritiqueColors.basicFor(seed);
    } else {
      final palette = ref.watch(posterPaletteProvider(poster)).valueOrNull;
      target = palette == null
          ? CritiqueColors.classic
          : CritiqueColors.fromPalette(palette);
    }
    return TweenAnimationBuilder<CritiqueColors>(
      tween: _Tween(end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, colors, _) => _Scope(
        colors: colors,
        child: Builder(builder: builder),
      ),
    );
  }
}
