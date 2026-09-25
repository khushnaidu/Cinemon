import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/film_model.dart';
import '../../models/trailer_item.dart';
import '../../providers/trailer/trailer_provider.dart';
import '../../providers/trailer/trailer_seen.dart';
import '../film/film_extras_sections.dart';
import '../lists/watchlist_button.dart';
import '../shell/glass_shell.dart';
import '../widgets/glass_panel.dart';
import '../widgets/liquid_glass.dart' show LiquidGlass;
import '../widgets/poster_ambience.dart';

/// This tab's index in the shell.
const _kTrailersTab = 3;

/// The Trailers tab (ADR 0001, Phase 7): one trailer per page, swiped
/// vertically, from a feed the database keeps (migrations 012–013).
///
/// The playback budget is a single web view. Only the settled page has a
/// player; every other page is its thumbnail. The player is created when a
/// page settles and closed when you move on, leave the tab, or something
/// covers it, so there is never more than one WKWebView alive.
///
/// It's also the one screen that turns on its side: Landscape fills the
/// screen with the video and hides the tab bar, and you keep swiping up for
/// the next one. Leaving the tab, or anything covering it, turns it back.
class TrailersScreen extends ConsumerStatefulWidget {
  const TrailersScreen({super.key});

  @override
  ConsumerState<TrailersScreen> createState() => _TrailersScreenState();
}

class _TrailersScreenState extends ConsumerState<TrailersScreen>
    with WidgetsBindingObserver {
  TrailerFeed _feed = TrailerFeed.trending;
  PageController _pages = PageController();
  int _page = 0;

  YoutubePlayerController? _player;
  StreamSubscription<YoutubePlayerValue>? _playerSub;
  int? _playerPage;
  String? _playerVideo;

  /// Muted until you ask for sound, then it stays on from page to page.
  bool _muted = true;

  /// On its side, full screen.
  bool _landscape = false;

  /// Where a trailer was when its player was closed for a sheet or another
  /// tab, so coming back carries on rather than starting over.
  String? _resumeVideo;
  double? _resumeAt;

  /// The video already skipped past, so an error and an end don't both
  /// advance.
  String? _advancedFrom;

  bool _appActive = true;

  StreamSubscription<int>? _reselectSub;

  /// A vertical drag that started on the player, handed to the pager.
  Drag? _drag;

  bool get _active =>
      mounted &&
      _appActive &&
      shellBranchIndex.value == _kTrailersTab &&
      shellChromeVisible.value;

  /// What you've watched on this device. Until it loads the tab waits, so
  /// the first order it shows is already the right one.
  TrailerSeenStore? _seen;

  /// The feed as shown: what you haven't watched first. Worked out once per
  /// load or refresh, never while you're swiping, so pages don't move under
  /// you.
  List<TrailerItem> _ordered = const [];
  List<TrailerItem>? _orderedFrom;

  List<TrailerItem> get _items => _ordered;

  List<TrailerItem> _orderFor(List<TrailerItem> feed) {
    if (!identical(feed, _orderedFrom)) {
      _orderedFrom = feed;
      _ordered =
          orderUnseenFirst(feed, _seen?.seen ?? const {}, now: DateTime.now());
    }
    return _ordered;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    shellBranchIndex.addListener(_sync);
    shellChromeVisible.addListener(_sync);
    _reselectSub = shellTabReselects.listen((tab) {
      if (tab == _kTrailersTab) _toTop();
    });
    TrailerSeenStore.load().then((store) {
      if (!mounted) return;
      setState(() => _seen = store);
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    });
  }

  @override
  void dispose() {
    if (_landscape) _restoreOrientation();
    WidgetsBinding.instance.removeObserver(this);
    shellBranchIndex.removeListener(_sync);
    shellChromeVisible.removeListener(_sync);
    _reselectSub?.cancel();
    _playerSub?.cancel();
    _player?.close();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive is Control Center or a call banner: the video can stay.
    _appActive = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _sync();
  }

  /// One player on the settled page while the tab is on screen; none
  /// otherwise.
  void _sync() {
    if (!mounted) return;
    // Landscape belongs to this tab only: going to another tab or opening
    // anything on top turns the app back upright.
    if (_landscape &&
        (shellBranchIndex.value != _kTrailersTab ||
            !shellChromeVisible.value)) {
      _setLandscape(false);
    }
    if (_active) {
      _attach(_page);
    } else {
      _detach(remember: true);
    }
  }

  void _attach(int page) {
    final items = _items;
    if (page >= items.length) return;
    final item = items[page];
    if (_player != null &&
        _playerPage == page &&
        _playerVideo == item.videoId) {
      return;
    }
    _detach();

    final start = _resumeVideo == item.videoId ? _resumeAt : null;
    _resumeVideo = null;
    _resumeAt = null;

    final controller = YoutubePlayerController.fromVideoId(
      videoId: item.videoId,
      autoPlay: true,
      startSeconds: start,
      params: YoutubePlayerParams(
        // Autoplay is muted, like every feed of video. The sound button
        // turns it on for this and every trailer after.
        mute: _muted,
        playsInline: true,
        showControls: true,
        // Our Landscape replaces YouTube's full screen, which would stop
        // the swiping.
        showFullscreenButton: false,
        strictRelatedVideos: true,
      ),
    );
    _seen?.markSeen(item.videoId);
    _playerSub = controller.stream.listen((v) => _onPlayer(item.videoId, v));
    setState(() {
      _player = controller;
      _playerPage = page;
      _playerVideo = item.videoId;
    });
  }

  void _detach({bool remember = false}) {
    final controller = _player;
    if (controller == null) return;
    final video = _playerVideo;
    _playerSub?.cancel();
    _playerSub = null;
    setState(() {
      _player = null;
      _playerPage = null;
      _playerVideo = null;
    });

    if (remember && video != null) {
      _resumeVideo = video;
      controller.currentTime
          .then((t) {
            if (_resumeVideo == video && t > 1) _resumeAt = t;
          })
          .catchError((_) {})
          .whenComplete(controller.close);
    } else {
      // After this frame, once the player's widget has gone.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(controller.close()));
    }
  }

  void _onPlayer(String video, YoutubePlayerValue v) {
    if (video != _playerVideo || _advancedFrom == video) return;
    // Age-restricted or not embeddable: YouTube won't play it here, so move
    // on rather than leave an error on screen. And when one ends, the next.
    final failed = v.error != YoutubeError.none;
    if (failed || v.playerState == PlayerState.ended) {
      _advancedFrom = video;
      if (failed && mounted) {
        showGlassToast(context, "That one won't play here. Skipped it.");
      }
      _next();
    }
  }

  void _next() {
    if (!_pages.hasClients || _page + 1 >= _items.length) return;
    _pages.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n is ScrollEndNotification) {
      // Settled. Only now does the new page get the player.
      if (_active) _attach(_page);
    }
    return false;
  }

  /// Back to the first trailer, where pulling down refreshes. A long way
  /// jumps most of it, so the pages in between aren't all built.
  void _toTop() {
    if (!_pages.hasClients || _page == 0) return;
    if (_page > 3) _pages.jumpToPage(3);
    _pages.animateToPage(0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _muted = !_muted);
    final player = _player;
    if (player == null) return;
    _muted ? player.mute() : player.unMute();
  }

  void _setLandscape(bool on) {
    if (on == _landscape) return;
    HapticFeedback.selectionClick();
    setState(() => _landscape = on);
    shellImmersive.value = on;
    SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  static void _restoreOrientation() {
    shellImmersive.value = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Landscape without rotating the phone: the app stays portrait and the
  /// trailers are drawn a quarter turn round, at the screen's long side. A
  /// forced system rotation left touches landing in the wrong place on iOS,
  /// so nothing could be tapped or swiped until the app restarted.
  ///
  /// The media query is turned to match, so the video, the notch margin and
  /// the button rail lay out as if the phone were sideways.
  static const _landscapeTurns = 3;

  MediaQueryData _sideways(MediaQueryData mq) {
    // Three quarter turns: the content's right edge is the screen's top
    // (the notch), its left the screen's bottom (the home indicator).
    final p = mq.padding;
    final turned = EdgeInsets.only(left: p.bottom, right: p.top);
    return mq.copyWith(
      size: Size(mq.size.height, mq.size.width),
      padding: turned,
      viewPadding: turned,
      viewInsets: EdgeInsets.zero,
    );
  }

  void _setFeed(int index) {
    final feed = TrailerFeed.values[index];
    if (feed == _feed) return;
    _detach();
    final old = _pages;
    setState(() {
      _feed = feed;
      _page = 0;
      _orderedFrom = null;
      _pages = PageController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      _sync();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(trailerFeedProvider(_feed));
    try {
      await ref.read(trailerFeedProvider(_feed).future);
    } catch (_) {}
  }

  /// Vertical drags that start on the video still turn the page. Taps go
  /// through to YouTube's own controls.
  late final Set<Factory<OneSequenceGestureRecognizer>> _playerGestures = {
    Factory<VerticalDragGestureRecognizer>(
      () => VerticalDragGestureRecognizer()
        ..onStart = (d) {
          if (_pages.hasClients) {
            _drag = _pages.position.drag(d, () => _drag = null);
          }
        }
        ..onUpdate = ((d) => _drag?.update(d))
        ..onEnd = ((d) => _drag?.end(d))
        ..onCancel = (() => _drag?.cancel()),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(trailerFeedProvider(_feed));
    // A fresh feed (first load, refresh) may have moved what's on this page.
    ref.listen(trailerFeedProvider(_feed), (_, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      }
    });

    final padding = MediaQuery.paddingOf(context);
    final headerHeight = padding.top + kFloatingHeaderInset;

    final Widget body = _seen == null
        ? const Center(child: CupertinoActivityIndicator())
        : feed.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (_, __) => _Message(
              title: "Couldn't load trailers",
              body: 'Check your connection and try again.',
              onRetry: _refresh,
            ),
            data: (fetched) {
              final items = _orderFor(fetched);
              if (items.isEmpty) {
                return _Message(
                  title: 'Trailers are on their way',
                  body: 'The feed fills a few minutes after it first runs.',
                  onRetry: _refresh,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                edgeOffset: _landscape ? 0 : headerHeight,
                color: AppColors.ink,
                backgroundColor: AppColors.surfaceElevated,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: PageView.builder(
                    key: ValueKey(_feed),
                    controller: _pages,
                    scrollDirection: Axis.vertical,
                    // Bouncing at the top is what pulls down to refresh.
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: items.length,
                    onPageChanged: (i) => setState(() {
                      _page = i;
                      _advancedFrom = null;
                    }),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final player = _player;
                      return _TrailerPage(
                        item: item,
                        current: i == _page,
                        player: player != null &&
                                _playerPage == i &&
                                _playerVideo == item.videoId
                            ? YoutubePlayer(
                                key: ValueKey(player),
                                controller: player,
                                aspectRatio: 16 / 9,
                                backgroundColor: Colors.black,
                                gestureRecognizers: _playerGestures,
                                enableFullScreenOnVerticalDrag: false,
                              )
                            : null,
                        muted: _muted,
                        landscape: _landscape,
                        onToggleMute: _toggleMute,
                        onLandscape: () => _setLandscape(!_landscape),
                        onPlay: () => _attach(i),
                      );
                    },
                  ),
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          // Always the same widgets, turned or not, so switching keeps the
          // playing video rather than reloading it.
          Positioned.fill(
            child: RotatedBox(
              quarterTurns: _landscape ? _landscapeTurns : 0,
              child: MediaQuery(
                data: _landscape
                    ? _sideways(MediaQuery.of(context))
                    : MediaQuery.of(context),
                child: body,
              ),
            ),
          ),
          if (!_landscape)
            Positioned(
              top: padding.top + 6,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 220,
                  child: GlassSegmentedControl(
                    labels: const ['Trending', 'New'],
                    index: _feed.index,
                    onChanged: _setFeed,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One trailer: the video full width, lit by its poster, with the title
/// and what you can do with it underneath.
class _TrailerPage extends StatelessWidget {
  const _TrailerPage({
    required this.item,
    required this.current,
    required this.player,
    required this.muted,
    required this.landscape,
    required this.onToggleMute,
    required this.onLandscape,
    required this.onPlay,
  });

  final TrailerItem item;
  final bool current;
  final Widget? player;
  final bool muted;
  final bool landscape;
  final VoidCallback onToggleMute;
  final VoidCallback onLandscape;
  final VoidCallback onPlay;

  /// Width of the button column beside the video on its side.
  static const _sideRail = 56.0;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final poster = ApiConstants.getPosterUrl(item.posterPath);

    return LayoutBuilder(builder: (context, c) {
      final Rect videoRect;
      if (landscape) {
        // As big as fits beside the buttons, clear of the notch.
        final left = padding.left;
        final width = c.maxWidth - padding.left - padding.right - _sideRail;
        final w = width.clamp(0.0, c.maxHeight * 16 / 9);
        final h = w * 9 / 16;
        videoRect =
            Rect.fromLTWH(left + (width - w) / 2, (c.maxHeight - h) / 2, w, h);
      } else {
        final top = padding.top + kFloatingHeaderInset;
        final bottom = padding.bottom + kFloatingTabBarInset;
        final band = c.maxHeight - top - bottom;
        final videoHeight = c.maxWidth * 9 / 16;
        // A little above centre, so the title and buttons fit beneath it.
        final videoTop = top + (band * 0.2).clamp(AppSpace.lg, double.infinity);
        videoRect = Rect.fromLTWH(0, videoTop, c.maxWidth, videoHeight);
      }

      // The same children in the same order either way, so turning the
      // phone resizes the playing video rather than reloading it.
      return Stack(
        children: [
          if (poster.isNotEmpty)
            Positioned.fill(
              child: PosterAmbience(
                posterUrl: poster,
                cardCenter: videoRect.center,
                cardSize: videoRect.size,
                intensity: 0.8,
              ),
            ),
          Positioned.fromRect(
            rect: videoRect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: item.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppColors.surface),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.surface),
                ),
                if (player != null)
                  player!
                else
                  GestureDetector(
                    onTap: current ? onPlay : null,
                    child: Center(child: _PlayGlyph()),
                  ),
              ],
            ),
          ),
          if (landscape)
            Positioned(
              top: 0,
              bottom: 0,
              right: padding.right,
              width: _sideRail,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundGlassButton(
                    icon: CupertinoIcons.fullscreen_exit,
                    label: 'Back to portrait',
                    onTap: onLandscape,
                  ),
                  const SizedBox(height: AppSpace.md),
                  _RoundGlassButton(
                    icon: muted
                        ? CupertinoIcons.speaker_slash_fill
                        : CupertinoIcons.speaker_2_fill,
                    label: muted ? 'Sound off' : 'Sound on',
                    onTap: onToggleMute,
                  ),
                ],
              ),
            )
          else
            Positioned(
              top: videoRect.bottom + AppSpace.lg,
              left: AppSpace.lg,
              right: AppSpace.lg,
              child: _Info(
                item: item,
                current: current,
                muted: muted,
                onToggleMute: onToggleMute,
                onLandscape: onLandscape,
              ),
            ),
        ],
      );
    });
  }
}

/// A round glass icon button, for the rail beside the video on its side.
class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({
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
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(22),
          blur: 16,
          tint: 0.18,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 18, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.item,
    required this.current,
    required this.muted,
    required this.onToggleMute,
    required this.onLandscape,
  });

  final TrailerItem item;
  final bool current;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onLandscape;

  @override
  Widget build(BuildContext context) {
    final kicker = [
      (item.category ?? 'Trailer').toUpperCase(),
      if (item.year != null) '${item.year}',
      if (item.isTv) 'SERIES',
    ].join('  ·  ');
    final film = item.film;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: AppText.caption.copyWith(
            color: AppColors.inkTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        GestureDetector(
          onTap: () => _openFilm(context),
          child: Text(
            item.title,
            style: AppText.title.copyWith(color: AppColors.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (item.videoTitle != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            item.videoTitle!,
            style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        // Only the page you're on asks TMDB where it's streaming.
        if (current) ...[
          const SizedBox(height: AppSpace.md),
          CompactWhereToWatch(
            filmKey: (id: item.tmdbId, mediaType: item.mediaType),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            WatchlistButton(film: film),
            AddToListButton(film: film),
            const Spacer(),
            _SmallGlassIcon(
              icon: muted
                  ? CupertinoIcons.speaker_slash_fill
                  : CupertinoIcons.speaker_2_fill,
              label: muted ? 'Sound off' : 'Sound on',
              onTap: onToggleMute,
            ),
            const SizedBox(width: AppSpace.sm),
            _SmallGlassIcon(
              icon: CupertinoIcons.device_phone_landscape,
              label: 'Landscape',
              onTap: onLandscape,
            ),
            const SizedBox(width: AppSpace.sm),
            GlassPillButton(
              label: 'Open',
              compact: true,
              prominent: true,
              onTap: () => _openFilm(context),
            ),
          ],
        ),
      ],
    );
  }

  void _openFilm(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(
        '/film/${item.tmdbId}/${item.mediaType == MediaType.tv ? 'tv' : 'movie'}');
  }
}

/// A compact round glass button the height of the compact pills beside it.
class _SmallGlassIcon extends StatelessWidget {
  const _SmallGlassIcon({
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
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(15),
          blur: 16,
          tint: 0.18,
          shadow: false,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 15, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.8),
      ),
      child:
          const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final String title;
  final String body;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: AppText.headline.copyWith(color: AppColors.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(body,
                style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            GlassPillButton(
                label: 'Check again', compact: true, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
