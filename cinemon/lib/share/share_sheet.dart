import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/poster_palette.dart';
import '../screens/widgets/glass_panel.dart';
import 'share_subject.dart';
import 'story_canvas.dart';
import 'story_share.dart';

/// S0: the share sheet (ADR 0003). Swipe through the subject's styles, pick
/// a colour from the poster, then send the card to a story, Photos, or the
/// system share sheet.
///
/// [initialCode] opens on that style, like "P2" from the month card.
Future<void> showShareSheet(
  BuildContext context,
  ShareSubject subject, {
  String? initialCode,
}) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (_) => ShareSheet(subject: subject, initialCode: initialCode),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.subject, this.initialCode});

  final ShareSubject subject;
  final String? initialCode;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late final List<ShareTemplate> _templates = widget.subject.templates;
  late final List<GlobalKey> _storyKeys =
      List.generate(_templates.length, (_) => GlobalKey());
  late final List<GlobalKey> _stickerKeys =
      List.generate(_templates.length, (_) => GlobalKey());
  late int _page =
      _templates.indexWhere((t) => t.code == widget.initialCode).clamp(0, 99);
  late final _pages =
      PageController(viewportFraction: 0.64, initialPage: _page);

  int _swatch = 0;
  bool _ready = false;
  bool _busy = false;
  bool _instagram = false;
  bool _facebook = false;
  bool _warming = false;

  @override
  void initState() {
    super.initState();
    StoryShare.canShare(StoryTarget.instagram)
        .then((v) => mounted ? setState(() => _instagram = v) : null);
    StoryShare.canShare(StoryTarget.facebook)
        .then((v) => mounted ? setState(() => _facebook = v) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warming) return;
    _warming = true;
    _warm();
  }

  /// Every image the cards draw is decoded before export is allowed, so no
  /// card goes out half loaded (ADR 0003, D1). A failed image doesn't block:
  /// the card draws its placeholder instead.
  Future<void> _warm() async {
    final urls = await widget.subject.loadImages(ref);
    if (!mounted) return;
    await Future.wait([
      for (final url in urls)
        precacheImage(CachedNetworkImageProvider(url), context,
                onError: (_, __) {})
            .timeout(const Duration(seconds: 8), onTimeout: () {}),
      for (final asset in _assets)
        precacheImage(AssetImage('assets/share/$asset'), context),
    ]);
    // One more frame so the decoded images are actually painted.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _ready = true);
  }

  static const _assets = [
    'mark.png',
    'grain.png',
    'sparkle.png',
    'top3_orb.png',
    'top3_rank1.png',
    'top3_rank2.png',
    'top3_rank3.png',
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<Color?> _swatches(PosterPalette p) =>
      [null, p.primary, p.secondary, const Color(0xFF0B0B0B)];

  ShareLook _look(PosterPalette p) =>
      ShareLook(palette: p, tint: _swatches(p)[_swatch]);

  // ── export ──────────────────────────────────────────────────

  Future<Uint8List?> _capture(GlobalKey key) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: kStoryPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy || !_ready) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Uri _link(String source) => widget.subject.link.replace(
      queryParameters: {...widget.subject.link.queryParameters, 's': source});

  Future<void> _toStory(StoryTarget target, ShareLook look) => _run(() async {
        final t = _templates[_page];
        final ok = t.sticker
            ? await StoryShare.share(
                target,
                sticker: await _capture(_stickerKeys[_page]),
                top: look.top,
                bottom: look.bottom,
                link: _link(target == StoryTarget.instagram ? 'ig' : 'fb'),
              )
            : await StoryShare.share(
                target,
                background: await _capture(_storyKeys[_page]),
                link: _link(target == StoryTarget.instagram ? 'ig' : 'fb'),
              );
        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pop();
        } else {
          showGlassToast(context, "Couldn't open the story. Try Save instead.",
              destructive: true);
        }
      });

  Future<void> _save() => _run(() async {
        final png = await _capture(_storyKeys[_page]);
        if (png == null || !mounted) return;
        final r = await StoryShare.saveImage(png);
        if (!mounted) return;
        switch (r) {
          case SaveResult.saved:
            showGlassToast(context, 'Saved to Photos');
          case SaveResult.denied:
            showGlassToast(
                context, 'Allow 35mm to add photos in Settings to save cards.',
                destructive: true);
          case SaveResult.failed:
            showGlassToast(context, "Couldn't save the card. Try again.",
                destructive: true);
        }
      });

  Future<void> _more(BuildContext buttonContext) => _run(() async {
        final png = await _capture(_storyKeys[_page]);
        if (png == null) return;
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/35mm-${_templates[_page].code}-${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(png);
        if (!buttonContext.mounted) return;
        final box = buttonContext.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _link('share').toString(),
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      });

  // ── layout ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = ref
            .watch(posterPaletteProvider(widget.subject.paletteUrl))
            .valueOrNull ??
        PosterPalette.neutral;
    final look = _look(palette);
    final swatches = _swatches(palette);

    return Column(
      children: [
        GlassPanelHeader(
          title: widget.subject.sheetTitle,
          subtitle: _templates[_page].name,
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _templates.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _page = i);
            },
            itemBuilder: (context, i) => AnimatedScale(
              scale: i == _page ? 1 : 0.88,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: i == _page ? 1 : 0.5,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm, vertical: AppSpace.md),
                  child: Center(child: _Preview(child: _story(i, look))),
                ),
              ),
            ),
          ),
        ),
        if (_templates.length > 1) ...[
          const SizedBox(height: AppSpace.sm),
          _Dots(count: _templates.length, index: _page),
        ],
        const SizedBox(height: AppSpace.lg),
        _Swatches(
          colors: swatches,
          palette: palette,
          index: _swatch,
          onPick: (i) {
            HapticFeedback.selectionClick();
            setState(() => _swatch = i);
          },
        ),
        if (_templates[_page].controls case final controls?) ...[
          const SizedBox(height: AppSpace.md),
          controls(context),
        ],
        const SizedBox(height: AppSpace.xl),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, 0, AppSpace.lg, AppSpace.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_instagram)
                _Action(
                  label: 'Instagram\nstory',
                  enabled: _ready && !_busy,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.4, 1.1),
                      radius: 1.3,
                      colors: [
                        Color(0xFFFDB34A),
                        Color(0xFFE8465C),
                        Color(0xFF8A3AB9)
                      ],
                      stops: [0, 0.45, 0.85],
                    ),
                  ),
                  icon: const _InstagramGlyph(),
                  onTap: (_) => _toStory(StoryTarget.instagram, look),
                ),
              if (_facebook)
                _Action(
                  label: 'Facebook\nstory',
                  enabled: _ready && !_busy,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF1877F2)),
                  icon: const Text('f',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1)),
                  onTap: (_) => _toStory(StoryTarget.facebook, look),
                ),
              _Action(
                label: 'Save\nimage',
                enabled: _ready && !_busy,
                icon: const Icon(CupertinoIcons.arrow_down_to_line,
                    size: 22, color: AppColors.ink),
                onTap: (_) => _save(),
              ),
              _Action(
                label: 'More\n',
                enabled: _ready && !_busy,
                icon: const Icon(CupertinoIcons.ellipsis,
                    size: 22, color: AppColors.ink),
                onTap: _more,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One style at export size, inside the boundary we capture. A sticker
  /// style gets a second boundary around the card alone, which is what
  /// Instagram receives.
  Widget _story(int i, ShareLook look) {
    final t = _templates[i];
    final story = t.sticker
        ? StickerStory(
            look: look,
            sticker:
                RepaintBoundary(key: _stickerKeys[i], child: t.build(look)),
          )
        : t.build(look);
    return RepaintBoundary(key: _storyKeys[i], child: story);
  }
}

/// A sticker style on its gradient: what Instagram shows before anyone
/// moves it, and what Save and More export.
class StickerStory extends StatelessWidget {
  const StickerStory({super.key, required this.look, required this.sticker});

  final ShareLook look;
  final Widget sticker;

  @override
  Widget build(BuildContext context) {
    return StoryCanvas(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [look.top, look.bottom],
            ),
          ),
        ),
        const StoryGrain(),
        // Centred in the space between Instagram's top bar and the brand,
        // whatever the card's height: a one-line take and a paragraph both
        // sit where the eye lands.
        Positioned(
          left: 0,
          right: 0,
          top: 21.u,
          bottom: 28.u,
          child: Center(
            child:
                Transform.rotate(angle: -3.5 * math.pi / 180, child: sticker),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17.u,
          child: const Center(child: StoryBrand()),
        ),
      ],
    );
  }
}

/// A card at export size, scaled to fit the carousel.
class _Preview extends StatelessWidget {
  const _Preview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kStoryWidth / kStoryHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FittedBox(fit: BoxFit.contain, child: child),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? AppColors.ink : AppColors.inkTertiary,
            ),
          ),
      ],
    );
  }
}

/// The colour choices. The first is the card's own look, drawn as the
/// poster's two colours split down the middle.
class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.colors,
    required this.palette,
    required this.index,
    required this.onPick,
  });

  final List<Color?> colors;
  final PosterPalette palette;
  final int index;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < colors.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == index ? AppColors.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i],
                    gradient: colors[i] == null
                        ? SweepGradient(colors: [
                            palette.primary,
                            palette.primary,
                            palette.secondary,
                            palette.secondary,
                            palette.primary,
                          ], stops: const [
                            0,
                            0.25,
                            0.25,
                            0.75,
                            0.75
                          ])
                        : null,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 0.6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.decoration,
  });

  final String label;
  final Widget icon;
  final bool enabled;
  final BoxDecoration? decoration;

  /// Gets the button's own context, which More needs to anchor the system
  /// share sheet on iPad.
  final void Function(BuildContext buttonContext) onTap;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => GlassPressable(
        onTap: enabled ? () => onTap(buttonContext) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.45,
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: decoration ??
                      const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceElevated,
                      ),
                  child: icon,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: AppColors.inkSecondary,
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

/// A camera outline: rounded square, lens, flash dot. Drawn rather than
/// shipped as Instagram's logo.
class _InstagramGlyph extends StatelessWidget {
  const _InstagramGlyph();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(24, 24), painter: _GlyphPainter());
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final s = size.width;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.1, s * 0.1, s * 0.8, s * 0.8),
            Radius.circular(s * 0.24)),
        p);
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.18, p);
    canvas.drawCircle(
        Offset(s * 0.72, s * 0.28), s * 0.035, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
