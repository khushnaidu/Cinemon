import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../screens/widgets/glass_panel.dart' show GlassPressable;
import '../share_subject.dart';
import '../story_canvas.dart';

/// Critiques read like print criticism (ADR 0003, D5): Instrument Serif for
/// the words, IBM Plex Mono for the furniture.
const _serif = 'InstrumentSerif';
const _mono = 'IBMPlexMono';
const _gold = Color(0xFFE6C08A);

TextStyle _monoStyle(double size, {double alpha = 0.7}) => TextStyle(
      fontFamily: _mono,
      fontWeight: FontWeight.w500,
      fontSize: size,
      letterSpacing: size * 0.12,
      height: 1,
      color: Colors.white.withValues(alpha: alpha),
    );

/// The headline with the film's title, where it appears, in gold italic.
List<InlineSpan> critiqueHeadlineSpans(String headline, String? title,
    {Color accent = _gold}) {
  if (title == null || title.isEmpty) return [TextSpan(text: headline)];
  final i = headline.toLowerCase().indexOf(title.toLowerCase());
  if (i < 0) return [TextSpan(text: headline)];
  return [
    TextSpan(text: headline.substring(0, i)),
    TextSpan(
      text: headline.substring(i, i + title.length),
      style: TextStyle(fontStyle: FontStyle.italic, color: accent),
    ),
    TextSpan(text: headline.substring(i + title.length)),
  ];
}

/// The critique's opening sentence, as a standfirst.
String critiqueStandfirst(String body) {
  final first = RegExp(r'^[^.!?]+[.!?]+')
          .firstMatch(body.trim().replaceAll(RegExp(r'\s+'), ' '))
          ?.group(0) ??
      body.trim();
  return first.length <= 180 ? first : '${first.substring(0, 170).trim()}…';
}

String _byline(CritiqueShare c) =>
    'By @${c.post.username}  ·  ${c.post.readMinutes} min read'.toUpperCase();

/// C1: a magazine cover. The film's still across the top, the serif
/// headline over its foot, then the standfirst and the byline.
class CritiqueCoverCard extends StatelessWidget {
  const CritiqueCoverCard({
    super.key,
    required this.critique,
    required this.look,
  });

  final CritiqueShare critique;
  final ShareLook look;

  static const _ground = Color(0xFF0B0D0C);

  @override
  Widget build(BuildContext context) {
    final post = critique.post;
    final headline = post.headline ?? '';
    final n = headline.length;
    final size = n <= 60
        ? 11.4.u
        : n <= 100
            ? 9.u
            : 7.4.u;
    final hero =
        critique.heroUrl.isNotEmpty ? critique.heroUrl : critique.posterUrl;

    return StoryCanvas(
      background: _ground,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 112.u,
          child: StoryImage(hero, alignment: const Alignment(0.24, 0)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 40.u,
          height: 74.u,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000B0D0C), _ground],
                stops: [0, 0.92],
              ),
            ),
          ),
        ),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 19.u,
          child: DefaultTextStyle(
            style: _monoStyle(2.8.u, alpha: 1).copyWith(
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 3.u),
              ],
            ),
            child: Row(
              children: [
                const Text('CRITIQUE'),
                const Spacer(),
                Text(DateFormat('MMM yyyy')
                    .format(post.createdAt)
                    .toUpperCase()),
              ],
            ),
          ),
        ),
        Positioned(
          left: 7.u,
          right: 7.u,
          bottom: 16.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                TextSpan(
                    children:
                        critiqueHeadlineSpans(headline, post.subject?.title)),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _serif,
                  fontSize: size,
                  height: 0.98,
                  letterSpacing: -size * 0.01,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 3.4.u),
              Text(
                critiqueStandfirst(post.body),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: _serif,
                  fontStyle: FontStyle.italic,
                  fontSize: 4.6.u,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(height: 3.4.u),
              Container(
                padding: EdgeInsets.only(top: 3.u),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.25.u),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _byline(critique),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _monoStyle(2.7.u),
                      ),
                    ),
                    const StoryBrand(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// C2: one sentence of the critique, set large, with its closing clause in
/// gold italic. The author picks the sentence in the sheet.
class PullQuoteCard extends StatelessWidget {
  const PullQuoteCard({super.key, required this.critique, required this.look});

  final CritiqueShare critique;
  final ShareLook look;

  @override
  Widget build(BuildContext context) {
    final post = critique.post;
    final hsl = HSLColor.fromColor(look.tint ?? look.palette.primary);
    final glow = hsl
        .withLightness(0.2)
        .withSaturation((hsl.saturation * 0.7).clamp(0.0, 0.6))
        .toColor();

    return ValueListenableBuilder<int>(
      valueListenable: critique.quote,
      builder: (context, index, _) {
        final quote = critique.quotes[index % critique.quotes.length];
        final n = quote.length;
        final size = n <= 90
            ? 8.6.u
            : n <= 150
                ? 7.2.u
                : 6.u;

        return StoryCanvas(
          background: const Color(0xFF08100F),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.6),
                  radius: 1.1,
                  colors: [glow, const Color(0xFF08100F)],
                  stops: const [0, 0.7],
                ),
              ),
            ),
            const StoryGrain(),
            Positioned(
              left: 7.u,
              right: 7.u,
              top: 21.u,
              bottom: 16.u,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  SizedBox(
                    height: 22.u,
                    child: Text(
                      '“',
                      style: TextStyle(
                        fontFamily: _serif,
                        fontSize: 44.u,
                        height: 0.9,
                        color: _gold,
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(children: _quoteSpans(quote)),
                    style: TextStyle(
                      fontFamily: _serif,
                      fontSize: size,
                      height: 1.08,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.u),
                  Container(
                    padding: EdgeInsets.only(top: 5.u),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.25.u),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (critique.posterUrl.isNotEmpty) ...[
                          StoryPoster(
                            url: critique.posterUrl,
                            width: 13.u,
                            radius: 1.u,
                            shadow: false,
                          ),
                          SizedBox(width: 3.6.u),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.headline ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _serif,
                                  fontSize: 5.u,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 1.6.u),
                              Text(
                                'Critique by @${post.username}  ·  ${post.readMinutes} min'
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _monoStyle(2.6.u, alpha: 0.55),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Center(child: StoryBrand()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The quote, with what follows its last comma in gold italic when that
  /// last clause is long enough to land.
  static List<InlineSpan> _quoteSpans(String quote) {
    final i = quote.lastIndexOf(', ');
    if (i < 0 || quote.length - i < 14 || i < 12) {
      return [TextSpan(text: quote)];
    }
    return [
      TextSpan(text: quote.substring(0, i + 2)),
      TextSpan(
        text: quote.substring(i + 2),
        style: const TextStyle(fontStyle: FontStyle.italic, color: _gold),
      ),
    ];
  }
}

/// Steps through the critique's candidate sentences for C2.
class QuotePicker extends StatelessWidget {
  const QuotePicker({super.key, required this.critique});

  final CritiqueShare critique;

  @override
  Widget build(BuildContext context) {
    final count = critique.quotes.length;
    return ValueListenableBuilder<int>(
      valueListenable: critique.quote,
      builder: (context, index, _) {
        void go(int d) {
          HapticFeedback.selectionClick();
          critique.quote.value = (index + d) % count;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Arrow(icon: CupertinoIcons.chevron_left, onTap: () => go(-1)),
            SizedBox(
              width: 132,
              child: Text(
                'Quote ${index + 1} of $count',
                textAlign: TextAlign.center,
                style: AppText.label.copyWith(color: AppColors.inkSecondary),
              ),
            ),
            _Arrow(icon: CupertinoIcons.chevron_right, onTap: () => go(1)),
          ],
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 16, color: AppColors.ink),
      ),
    );
  }
}
