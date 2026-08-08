import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Liquid Glass primitives.
///
/// The first version of this looked like grey perspex, because it built the
/// material out of stacked white overlays. Real glass doesn't add white — it
/// *transmits*, and three things sell that:
///
///   * **Saturation.** Light through glass comes out more saturated, not
///     paler. The backdrop filter here composes a saturation matrix over the
///     blur rather than blurring alone, so colour from the artwork underneath
///     bleeds through instead of washing out.
///   * **A chromatic edge.** A bevel refracts wavelengths by different
///     amounts, which is the faint rainbow fringing along the rim of Apple's
///     material. That's a sweep of hue at low alpha over the specular
///     highlight, not a plain white stroke.
///   * **A dark tint, not a white one.** White overlays lighten toward grey
///     perspex and blow out the icons over bright posters. Darkening instead
///     keeps the pane dense and the contents legible.
///
/// This remains an approximation, and the gap is not tuneable: [BackdropFilter]
/// samples the backdrop and filters it, but cannot *displace* it — and
/// refraction is displacement. Real warping needs either a fragment shader
/// that offsets the sample coordinates, or Apple's material itself (see
/// `ios/Runner/LiquidGlassTabBar.swift`), which also handles the way
/// neighbouring shapes attract and merge.

/// Boosts saturation of whatever is sampled behind the glass.
ColorFilter _saturation(double s) {
  // Standard luminance-preserving saturation matrix.
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  return ColorFilter.matrix(<double>[
    sr + s, sg,     sb,     0, 0,
    sr,     sg + s, sb,     0, 0,
    sr,     sg,     sb + s, 0, 0,
    0,      0,      0,      1, 0,
  ]);
}

/// A floating pane of glass.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blur = 18,
    this.tint = 0.34,
    this.saturation = 1.9,
    this.shadow = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// Kept low deliberately — see the class docs.
  final double tint;

  final double saturation;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: _saturation(saturation),
            inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: tint * 0.85),
                  Colors.black.withValues(alpha: tint),
                ],
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _RefractiveRimPainter(borderRadius: borderRadius),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The lit, refracting edge: a bright specular hairline with chromatic
/// fringing sweeping around it.
class _RefractiveRimPainter extends CustomPainter {
  const _RefractiveRimPainter({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Chromatic fringe, drawn slightly wider and blurred so it reads as
    //    light splitting through the bevel rather than a coloured outline.
    final fringe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6)
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          Color(0x3300E5FF), // cyan
          Color(0x2AFF00E5), // magenta
          Color(0x33FFD400), // amber
          Color(0x2A00FF95), // green
          Color(0x3300E5FF),
        ],
        stops: [0.0, 0.28, 0.52, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(0.6), fringe);

    // 2. Specular highlight over the top, fading under.
    final specular = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(0.5), specular);
  }

  @override
  bool shouldRepaint(_RefractiveRimPainter old) =>
      old.borderRadius != borderRadius;
}

/// One destination in [LiquidGlassTabBar].
class LiquidGlassTabItem {
  const LiquidGlassTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;

  /// Not rendered — kept for semantics and accessibility.
  final String label;
}

/// A floating, icon-only glass tab bar with a travelling blob.
///
/// Lives above the navigator (see `GlassShell`) so it persists across tab
/// changes and content scrolls underneath it — which is the entire point of
/// the material. It contracts as the user scrolls down and returns on scroll
/// up, so it never fights the content for space.
class LiquidGlassTabBar extends StatefulWidget {
  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.compact = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidGlassTabItem> items;

  /// Contracted form, used while scrolling down.
  final bool compact;

  static const double barHeight = 54;
  static const double compactHeight = 42;

  static double reservedHeight(BuildContext context) =>
      barHeight + 16 + MediaQuery.of(context).padding.bottom;

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _position;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _position = AlwaysStoppedAnimation(_from);
  }

  @override
  void didUpdateWidget(LiquidGlassTabBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _from = _position.value;
      _to = widget.currentIndex.toDouble();
      _position = Tween<double>(begin: _from, end: _to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact
        ? LiquidGlassTabBar.compactHeight
        : LiquidGlassTabBar.barHeight;

    // Icon-only, so the bar only needs to be as wide as its targets — a
    // narrower pill leaves more of the artwork visible around it.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: height,
      child: LiquidGlass(
        // Fully rounded: radius is always half the height, so it stays a true
        // capsule at every size instead of a rounded rectangle.
        borderRadius: BorderRadius.circular(height / 2),
        blur: 18,
        tint: 0.06,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final n = widget.items.length;
            final slot = constraints.maxWidth / n;
            final inset = widget.compact ? 3.0 : 5.0;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pos = _position.value;
                final travel = (_to - _from).abs();
                final phase = math.sin(_controller.value * math.pi);
                final stretch = 1 + phase * 0.30 * travel.clamp(0.0, 3.0);
                final squash = 1 - phase * 0.12 * travel.clamp(0.0, 3.0);

                return Stack(
                  children: [
                    Positioned(
                      left: slot * pos + inset,
                      top: inset,
                      width: slot - inset * 2,
                      height: height - inset * 2,
                      child: Transform.scale(
                        scaleX: stretch,
                        scaleY: squash,
                        child: _Blob(height: height - inset * 2),
                      ),
                    ),
                    Row(
                      children: List.generate(n, (i) {
                        final item = widget.items[i];
                        final selected = i == widget.currentIndex;
                        return Expanded(
                          child: Semantics(
                            label: item.label,
                            selected: selected,
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (i != widget.currentIndex) {
                                  HapticFeedback.selectionClick();
                                }
                                widget.onTap(i);
                              },
                              child: Center(
                                child: AnimatedScale(
                                  scale: selected ? 1.08 : 1.0,
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: widget.compact ? 17 : 20,
                                    color: selected
                                        ? AppColors.ink
                                        : AppColors.inkSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The travelling highlight — a brighter, more saturated pane so it reads as
/// a denser lens sliding within the bar.
class _Blob extends StatelessWidget {
  const _Blob({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: _saturation(1.5),
          inner: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
