import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'critique_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../../providers/explore/explore_provider.dart';
import '../../share/cards/critique_cards.dart' show critiqueHeadlineSpans;
import '../../share/share_sheet.dart';
import '../../share/share_subject.dart'
    show pullQuoteCandidates, shareSubjectForPost;
import '../../share/story_canvas.dart' show StoryGrain;
import '../widgets/comments_sheet.dart' show CommentAvatar;
import '../widgets/glass_panel.dart' show GlassPressable, showGlassToast;
import '../widgets/verified_mark.dart';
import 'explore_thread.dart' show showExplorePostMenu;

// A critique, read like a magazine feature: the film's still as the cover,
// the headline in Instrument Serif with the title in gold italic, a byline
// set in mono, then the piece itself at book size with a drop cap, a pull
// quote at its middle and an end mark. The share card C1 in print, scrolled.
// Its colours come from the film's poster (critique_colors.dart).

const _serif = 'InstrumentSerif';
const _mono = 'IBMPlexMono';

/// The body face, for reading and writing alike. Charter ships with iOS;
/// Georgia is there if it ever doesn't.
TextStyle critiqueBodyStyle({double size = 19, Color? color}) => TextStyle(
      fontFamily: 'Charter',
      fontFamilyFallback: const ['Georgia', 'Times New Roman'],
      fontSize: size,
      height: 1.62,
      letterSpacing: 0.05,
      color: color ?? Colors.white.withValues(alpha: 0.88),
    );

TextStyle critiqueMonoStyle(double size, {double alpha = 0.6}) => TextStyle(
      fontFamily: _mono,
      fontWeight: FontWeight.w500,
      fontSize: size,
      letterSpacing: size * 0.12,
      height: 1.2,
      color: Colors.white.withValues(alpha: alpha),
    );

/// The headline's size, by its length: short ones set like a cover line.
double critiqueHeadlineSize(String headline) {
  final n = headline.characters.length;
  return n <= 40
      ? 48
      : n <= 70
          ? 42
          : n <= 100
              ? 36
              : 31;
}

/// How a critique's body is laid out: its paragraphs, and the pull quote
/// with the paragraph it follows. A return starts a paragraph, one or two.
/// Short pieces get no quote; repeating a line of a three-paragraph piece
/// reads as padding.
typedef CritiqueLayout = ({
  List<String> paragraphs,
  String? pullQuote,
  int pullAfter,
});

CritiqueLayout critiqueLayout(String body) {
  final paragraphs = body
      .split(RegExp(r'\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final words = body.trim().split(RegExp(r'\s+')).length;
  if (paragraphs.length < 4 || words < 250) {
    return (paragraphs: paragraphs, pullQuote: null, pullAfter: -1);
  }
  // From anywhere but the opening, where it would echo the drop cap.
  final opening = paragraphs.first;
  final candidates =
      pullQuoteCandidates(body).where((q) => !opening.contains(q)).toList();
  if (candidates.isEmpty) {
    return (paragraphs: paragraphs, pullQuote: null, pullAfter: -1);
  }
  final quote = candidates[candidates.length ~/ 2];
  return (
    paragraphs: paragraphs,
    pullQuote: quote,
    pullAfter: (paragraphs.length ~/ 2) - 1,
  );
}

/// Opens [post] as an article over everything, tab bar included. Swipe
/// right to go back. [preview] is the writer's look at an unposted draft:
/// nothing to like, share or report yet.
Future<void> showCritiqueReader(
  BuildContext context,
  ExplorePost post, {
  ValueChanged<ExploreSubject>? onSubjectTap,
  bool preview = false,
}) {
  HapticFeedback.lightImpact();
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      builder: (_) => CritiqueReader(
        post: post,
        onSubjectTap: onSubjectTap,
        preview: preview,
      ),
    ),
  );
}

class CritiqueReader extends ConsumerStatefulWidget {
  const CritiqueReader({
    super.key,
    required this.post,
    this.onSubjectTap,
    this.preview = false,
  });

  final ExplorePost post;
  final ValueChanged<ExploreSubject>? onSubjectTap;
  final bool preview;

  @override
  ConsumerState<CritiqueReader> createState() => _CritiqueReaderState();
}

class _CritiqueReaderState extends ConsumerState<CritiqueReader> {
  final _progress = ValueNotifier<double>(0);
  bool _revealed = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (m.axis == Axis.vertical && m.maxScrollExtent > 0) {
      _progress.value = (m.pixels / m.maxScrollExtent).clamp(0.0, 1.0);
    }
    return false;
  }

  /// Leaves the article for somewhere in the app. The reader sits above the
  /// tab navigators, so anything pushed now would open underneath it.
  void _leaveFor(String location) {
    Navigator.of(context).pop();
    context.push(location);
  }

  Future<void> _like(ExplorePost post) async {
    HapticFeedback.selectionClick();
    final ok = await ref.read(exploreActionsProvider).vote(post, 1);
    if (!ok && mounted) {
      showGlassToast(context, "Couldn't save that. Try again.",
          destructive: true);
    }
  }

  void _share(ExplorePost post) {
    final share = shareSubjectForPost(post);
    if (share != null) showShareSheet(context, share);
  }

  void _menu(ExplorePost post) => showExplorePostMenu(
        context,
        ref,
        post,
        onSubjectTap: widget.onSubjectTap,
        fromThread: true,
      );

  @override
  Widget build(BuildContext context) {
    final post = widget.preview ? widget.post : watchLivePost(ref, widget.post);
    final layout = critiqueLayout(post.body);
    final veiled = post.hasSpoilers && !_revealed && !widget.preview;
    final top = MediaQuery.paddingOf(context).top;

    return CritiqueColorScope(
      subject: post.subject,
      seed: post.id,
      builder: (context) => _page(context, post, layout, veiled, top),
    );
  }

  Widget _page(BuildContext context, ExplorePost post, CritiqueLayout layout,
      bool veiled, double top) {
    final c = CritiqueColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.ground,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Masthead(
                      post: post,
                      topInset: top,
                      onAuthor: widget.preview
                          ? null
                          : () => _leaveFor('/profile/${post.userId}'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                    sliver: veiled
                        ? SliverToBoxAdapter(
                            child: _SpoilerNotice(
                              title: post.subject?.title,
                              onReveal: () {
                                HapticFeedback.lightImpact();
                                setState(() => _revealed = true);
                              },
                            ),
                          )
                        : SliverList.list(
                            children: _article(layout, c),
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: _Colophon(
                      post: post,
                      preview: widget.preview,
                      onSubject: post.subject == null
                          ? null
                          : () => _leaveFor(
                              '/film/${post.subject!.filmId}/${post.subject!.mediaType}'),
                      onLike: () => _like(post),
                      onShare: () => _share(post),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 48),
                  ),
                ],
              ),
            ),
            // Reading progress, a hairline in the film's two inks under the
            // status bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 2,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _progress,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: [c.accent, c.accent2]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _RoundButton(
                    icon: CupertinoIcons.chevron_left,
                    label: 'Back',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.preview)
                    const _PreviewTag()
                  else ...[
                    _RoundButton(
                      icon: CupertinoIcons.square_arrow_up,
                      label: 'Share',
                      onTap: () => _share(post),
                    ),
                    const SizedBox(width: 10),
                    _RoundButton(
                      icon: CupertinoIcons.ellipsis,
                      label: 'More',
                      onTap: () => _menu(post),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _article(CritiqueLayout layout, CritiqueColors c) {
    final style = critiqueBodyStyle(color: c.ink);
    final paragraphs = layout.paragraphs;
    final out = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final last = i == paragraphs.length - 1;
      final text = paragraphs[i];
      out.add(Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 22),
        child: i == 0
            ? DropCapParagraph(
                text: text,
                style: style,
                endMark: last,
                capColor: c.accent,
              )
            : Text.rich(
                TextSpan(children: [
                  TextSpan(text: text),
                  if (last) ..._endMark(c.accent),
                ]),
                style: style,
              ),
      ));
      if (i == layout.pullAfter && layout.pullQuote != null) {
        out.add(_PullQuote(quote: layout.pullQuote!));
      }
    }
    return out;
  }
}

/// The small square that ends a magazine piece, in the piece's ink.
List<InlineSpan> _endMark(Color color) => [
      const TextSpan(text: '  '),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(
          width: 8,
          height: 8,
          child: ColoredBox(color: color),
        ),
      ),
    ];

// ─────────────────────────────────────────────────────────────
// Masthead
// ─────────────────────────────────────────────────────────────

class _Masthead extends StatelessWidget {
  const _Masthead({
    required this.post,
    required this.topInset,
    this.onAuthor,
  });

  final ExplorePost post;
  final double topInset;
  final VoidCallback? onAuthor;

  String get _heroUrl {
    final s = post.subject;
    if (s == null) return '';
    if (s.isEpisode && (s.episodeStillPath ?? '').isNotEmpty) {
      return ApiConstants.getStillUrl(s.episodeStillPath, size: '/w1280');
    }
    final wide = ApiConstants.getBackdropUrl(s.backdropPath, size: '/w1280');
    if (wide.isNotEmpty) return wide;
    return ApiConstants.getPosterUrl(s.posterPath, size: '/w780');
  }

  /// "On Past Lives (2023)", "On Severance, S2 E5, “Chikhai Bardo”".
  List<InlineSpan>? _dek(Color accent) {
    final s = post.subject;
    if (s == null) return null;
    final title = TextSpan(
      text: s.title,
      style: TextStyle(color: accent),
    );
    if (s.isEpisode) {
      return [
        const TextSpan(text: 'On '),
        title,
        TextSpan(text: ', ${s.episodeCode}'),
        if ((s.episodeTitle ?? '').isNotEmpty)
          TextSpan(text: ', “${s.episodeTitle}”'),
      ];
    }
    return [
      const TextSpan(text: 'On '),
      title,
      if ((s.year ?? '').isNotEmpty) TextSpan(text: ' (${s.year})'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hero = _heroUrl;
    final heroHeight = hero.isEmpty ? topInset + 120 : width * 1.18;
    final headline = post.headline ?? '';
    final size = critiqueHeadlineSize(headline);
    final c = CritiqueColors.of(context);
    final dek = _dek(c.accent);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight,
          child: hero.isEmpty
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.5, -0.7),
                      radius: 1.3,
                      colors: [c.glow, c.ground],
                    ),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: hero,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 500),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
        Positioned(
          top: heroHeight * 0.3,
          left: 0,
          right: 0,
          height: heroHeight * 0.7 + 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.ground.withValues(alpha: 0),
                  c.ground.withValues(alpha: 0.7),
                  c.ground,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ),
        // The still graded toward the page: a wash of the film's own hue
        // rising from the foot, so the cover and the paper are one colour.
        if (hero.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, 1.0),
                  radius: 1.1,
                  colors: [
                    c.glow.withValues(alpha: 0.75),
                    c.glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        // A little darkness under the buttons, whatever the still is.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 90,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.ground.withValues(alpha: 0.5),
                  c.ground.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight,
          child: const StoryGrain(opacity: 0.06),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, hero.isEmpty ? topInset + 84 : heroHeight - 190, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DefaultTextStyle(
                style: critiqueMonoStyle(11, alpha: 0.85),
                child: Row(
                  children: [
                    Text('CRITIQUE', style: TextStyle(color: c.accent)),
                    const Spacer(),
                    Text(DateFormat('d MMM yyyy')
                        .format(post.createdAt)
                        .toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: critiqueHeadlineSpans(headline, post.subject?.title,
                      accent: c.accent),
                ),
                style: TextStyle(
                  fontFamily: _serif,
                  fontSize: size,
                  height: 1.0,
                  letterSpacing: -size * 0.01,
                  color: Colors.white,
                ),
              ),
              if (dek != null) ...[
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(children: dek),
                  style: TextStyle(
                    fontFamily: _serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 21,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _Byline(post: post, onTap: onAuthor),
            ],
          ),
        ),
      ],
    );
  }
}

class _Byline extends StatelessWidget {
  const _Byline({required this.post, this.onTap});

  final ExplorePost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(
        color: CritiqueColors.of(context).accent.withValues(alpha: 0.28),
        width: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(top: rule, bottom: rule)),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CommentAvatar(
                  photoUrl: post.userPhotoUrl,
                  username: post.username,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text('BY @${post.username.toUpperCase()}',
                    style: critiqueMonoStyle(11, alpha: 0.85)),
                VerifiedMark(userId: post.userId, size: 12, gap: 5),
              ],
            ),
          ),
          const Spacer(),
          Text('${post.readMinutes} MIN READ',
              style: critiqueMonoStyle(11, alpha: 0.5)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Article pieces
// ─────────────────────────────────────────────────────────────

/// A paragraph whose first letter drops three lines deep, in the headline's
/// serif and gold. Flutter doesn't float, so the paragraph is laid out once
/// beside the letter to find where its third line ends, and set in two
/// parts: those lines beside it, the rest full width under it.
class DropCapParagraph extends StatelessWidget {
  const DropCapParagraph({
    super.key,
    required this.text,
    required this.style,
    this.lines = 3,
    this.endMark = false,
    this.capColor = const Color(0xFFE6C08A),
  });

  final String text;
  final TextStyle style;
  final int lines;
  final bool endMark;
  final Color capColor;

  @override
  Widget build(BuildContext context) {
    final chars = text.characters;
    final first = chars.isEmpty ? '' : chars.first;
    final plain = Text.rich(
      TextSpan(
          children: [TextSpan(text: text), if (endMark) ..._endMark(capColor)]),
      style: style,
    );
    // Only a letter or numeral drops; a quote mark or a dash would look lost.
    if (!RegExp(r'^[\p{L}\p{N}]$', unicode: true).hasMatch(first)) {
      return plain;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final lineHeight = scaler.scale(style.fontSize!) * style.height!;
      final capStyle = TextStyle(
        fontFamily: _serif,
        fontSize: lineHeight * lines * 0.98,
        height: 1,
        color: capColor,
      );
      final cap = TextPainter(
        text: TextSpan(text: first, style: capStyle),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      final capWidth = cap.width + 10;
      final rest = text.substring(first.length);

      final body = TextPainter(
        text: TextSpan(text: rest, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: constraints.maxWidth - capWidth);
      final metrics = body.computeLineMetrics();

      final beside = metrics.length <= lines
          ? rest
          : rest.substring(
              0,
              body
                  .getLineBoundary(body.getPositionForOffset(Offset(
                      constraints.maxWidth - capWidth - 1,
                      metrics[lines - 1].baseline)))
                  .end,
            );
      final under = rest.substring(beside.length).trimLeft();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: capWidth,
                height: lineHeight * lines,
                child: Transform.translate(
                  // Sit the letter's top on the first line's cap height
                  // and its foot on the third line's baseline.
                  offset: Offset(-1, lineHeight * 0.1),
                  child: Text(first,
                      style: capStyle, textScaler: TextScaler.noScaling),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: beside),
                    if (endMark && under.isEmpty) ..._endMark(capColor),
                  ]),
                  style: style,
                ),
              ),
            ],
          ),
          if (under.isNotEmpty)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: under),
                if (endMark) ..._endMark(capColor),
              ]),
              style: style,
            ),
        ],
      );
    });
  }
}

class _PullQuote extends StatelessWidget {
  const _PullQuote({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final c = CritiqueColors.of(context);
    final rule =
        BorderSide(color: c.accent2.withValues(alpha: 0.6), width: 0.8);
    // Lit from behind in the poster's second colour, bleeding past the
    // margins like a spread's colour block.
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 34),
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: rule),
        gradient: RadialGradient(
          center: const Alignment(-0.9, -0.6),
          radius: 1.4,
          colors: [c.glow, c.glow.withValues(alpha: 0)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Text(
              '“',
              style: TextStyle(
                fontFamily: _serif,
                fontSize: 72,
                height: 0.95,
                color: c.accent2,
              ),
            ),
          ),
          Text(
            quote,
            style: const TextStyle(
              fontFamily: _serif,
              fontStyle: FontStyle.italic,
              fontSize: 29,
              height: 1.12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpoilerNotice extends StatelessWidget {
  const _SpoilerNotice({this.title, required this.onReveal});

  final String? title;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final accent = CritiqueColors.of(context).accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SPOILERS AHEAD',
            style: critiqueMonoStyle(11, alpha: 1).copyWith(color: accent)),
        const SizedBox(height: 12),
        Text(
          title == null
              ? 'This critique gives the plot away.'
              : 'This critique gives away the plot of $title.',
          style: const TextStyle(
            fontFamily: _serif,
            fontStyle: FontStyle.italic,
            fontSize: 26,
            height: 1.15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        GlassPressable(
          onTap: onReveal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: accent.withValues(alpha: 0.7)),
            ),
            child: Text('READ ANYWAY',
                style: critiqueMonoStyle(12, alpha: 1)
                    .copyWith(color: CritiqueColors.of(context).accent)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// After the piece
// ─────────────────────────────────────────────────────────────

class _Colophon extends StatelessWidget {
  const _Colophon({
    required this.post,
    required this.preview,
    required this.onLike,
    required this.onShare,
    this.onSubject,
  });

  final ExplorePost post;
  final bool preview;
  final VoidCallback? onSubject;
  final VoidCallback onLike;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final subject = post.subject;
    final liked = post.myVote == 1;
    final rule =
        BorderSide(color: Colors.white.withValues(alpha: 0.14), width: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.isEdited)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('EDITED', style: critiqueMonoStyle(10, alpha: 0.4)),
            ),
          if (subject != null)
            GestureDetector(
              onTap: preview ? null : onSubject,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration:
                    BoxDecoration(border: Border(top: rule, bottom: rule)),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        width: 48,
                        height: 72,
                        child: subject.posterUrl.isEmpty
                            ? const ColoredBox(color: Color(0xFF1A1C1B))
                            : CachedNetworkImage(
                                imageUrl: subject.posterUrl,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FILED UNDER',
                              style: critiqueMonoStyle(10, alpha: 0.45)),
                          const SizedBox(height: 6),
                          Text(
                            subject.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: _serif,
                              fontSize: 24,
                              height: 1.05,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(subject.caption.toUpperCase(),
                              style: critiqueMonoStyle(10, alpha: 0.45)),
                        ],
                      ),
                    ),
                    if (!preview)
                      Icon(CupertinoIcons.chevron_right,
                          size: 15, color: Colors.white.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          if (!preview) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                _OutlineAction(
                  icon:
                      liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  label: post.agreeCount > 0 ? '${post.agreeCount}' : 'LIKE',
                  active: liked,
                  onTap: onLike,
                ),
                const SizedBox(width: 10),
                _OutlineAction(
                  icon: CupertinoIcons.square_arrow_up,
                  label: 'SHARE',
                  onTap: onShare,
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
          Center(
            child: Text('35MM  ·  CRITIQUE',
                style: critiqueMonoStyle(10, alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? CritiqueColors.of(context).accent
        : Colors.white.withValues(alpha: 0.85);
    return GlassPressable(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? CritiqueColors.of(context).accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: critiqueMonoStyle(11, alpha: 1).copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GlassPressable(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 0.6),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: CritiqueColors.of(context).accent.withValues(alpha: 0.6)),
      ),
      child: Text('PREVIEW',
          style: critiqueMonoStyle(10, alpha: 1)
              .copyWith(color: CritiqueColors.of(context).accent)),
    );
  }
}
