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
import '../../models/genres.dart';
import '../../models/trailer_item.dart';
import '../../providers/trailer/trailer_provider.dart';
import '../../providers/trailer/trailer_seen.dart';
import '../film/film_extras_sections.dart';
import '../lists/watchlist_button.dart';
import '../shell/glass_shell.dart';
import '../widgets/glass_panel.dart';
import '../widgets/liquid_glass.dart' show GlassLens, LiquidGlass;
import '../widgets/poster_ambience.dart';

/// This tab's index in the shell.
const _kTrailersTab = 3;

/// Discover (ADR 0001, Phase 7): one trailer per page, swiped vertically,
/// from feeds the database keeps (migrations 012, 013 and 027). Home is
/// what's trending and then what's popular, New is the last 60 days' trailers;
/// either for films or shows, and narrowed to a genre if you like.
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
  TrailerFeed _feed = TrailerFeed.home;
  MediaType _type = MediaType.movie;

  /// TMDB's genre id, or every genre.
  int? _genre;

  DiscoverQuery get _query => (feed: _feed, type: _type, genre: _genre);
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

  /// A different feed, type or genre: a fresh pager from its first page.
  /// What you've watched still goes to the back, whatever the filter.
  void _setQuery({TrailerFeed? feed, MediaType? type, int? Function()? genre}) {
    final nextType = type ?? _type;
    var nextGenre = genre != null ? genre() : _genre;
    // Comedy is Comedy either way; Horror has no TV twin.
    if (genreById(nextType, nextGenre) == null) nextGenre = null;
    final next = (feed: feed ?? _feed, type: nextType, genre: nextGenre);
    if (next == _query) return;
    _detach();
    final old = _pages;
    setState(() {
      _feed = next.feed;
      _type = next.type;
      _genre = next.genre;
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
    final q = _query;
    ref.invalidate(trailerFeedProvider(q));
    try {
      await ref.read(trailerFeedProvider(q).future);
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
    final feed = ref.watch(trailerFeedProvider(_query));
    // A fresh feed (first load, refresh) may have moved what's on this page.
    ref.listen(trailerFeedProvider(_query), (_, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
      }
    });

    final padding = MediaQuery.paddingOf(context);
    final headerHeight = padding.top + _DiscoverHeader.inset;

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
                final genre = genreById(_type, _genre);
                if (genre != null) {
                  return _Message(
                    title: 'No ${genre.name} trailers yet',
                    body: _feed == TrailerFeed.latest
                        ? 'Nothing new lately. Try Home, or another genre.'
                        : 'Try another genre, or check back soon.',
                    actionLabel: 'All genres',
                    onRetry: () async => _setQuery(genre: () => null),
                  );
                }
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
                    key: ValueKey(_query),
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
                        headerHeight: headerHeight,
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
              child: _DiscoverHeader(
                feed: _feed,
                type: _type,
                genre: _genre,
                onFeed: (f) => _setQuery(feed: f),
                onType: (t) => _setQuery(type: t),
                onGenre: (g) => _setQuery(genre: () => g),
              ),
            ),
        ],
      ),
    );
  }
}

/// Discover's switches, floating over the top of the page: Home or New,
/// and under it one quiet line saying what you're looking at ("Films · All
/// genres"), which opens the panel to change it.
class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.feed,
    required this.type,
    required this.genre,
    required this.onFeed,
    required this.onType,
    required this.onGenre,
  });

  final TrailerFeed feed;
  final MediaType type;
  final int? genre;
  final ValueChanged<TrailerFeed> onFeed;
  final ValueChanged<MediaType> onType;
  final ValueChanged<int?> onGenre;

  static const _switchHeight = 34.0;
  static const _lineHeight = 30.0;

  /// How far below the status bar the page's content starts.
  static const inset = 6 + _switchHeight + _lineHeight + AppSpace.sm;

  @override
  Widget build(BuildContext context) {
    final kind = type == MediaType.tv ? 'Shows' : 'Films';
    final name = genreById(type, genre)?.name ?? 'All genres';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: GlassSegmentedControl(
            labels: const ['Home', 'New'],
            index: feed.index,
            onChanged: (i) => onFeed(TrailerFeed.values[i]),
          ),
        ),
        Semantics(
          button: true,
          label: '$kind, $name. Change',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showGlassPanel<void>(
              context,
              builder: (_) => _FilterPanel(
                type: type,
                genre: genre,
                onType: onType,
                onGenre: onGenre,
              ),
            ),
            child: SizedBox(
              height: _lineHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$kind  ·  $name',
                      style: AppText.footnote.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_down,
                        size: 11, color: AppColors.ink.withValues(alpha: 0.75)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Films or shows, and a genre: the popular ones first, then the rest.
/// Films or Shows applies at once and the list follows it; a genre applies
/// and closes.
class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.type,
    required this.genre,
    required this.onType,
    required this.onGenre,
  });

  final MediaType type;
  final int? genre;
  final ValueChanged<MediaType> onType;
  final ValueChanged<int?> onGenre;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late MediaType _type = widget.type;
  late int? _genre = widget.genre;

  void _setType(MediaType t) {
    if (t == _type) return;
    widget.onType(t);
    setState(() {
      _type = t;
      // As the screen does: a genre only carries over if it exists there.
      if (genreById(t, _genre) == null) _genre = null;
    });
  }

  void _pick(int? id) {
    widget.onGenre(id);
    Navigator.of(context).pop();
  }

  /// Genres two to a row.
  Widget _grid(List<Genre?> genres) => Column(
        children: [
          for (var i = 0; i < genres.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(child: _cell(genres[i])),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: i + 1 < genres.length
                        ? _cell(genres[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      );

  /// One genre, or every genre for null.
  Widget _cell(Genre? g) => _GenreCell(
        label: g?.name ?? 'All genres',
        selected: g?.id == _genre,
        onTap: () => _pick(g?.id),
      );

  @override
  Widget build(BuildContext context) {
    final popular = popularGenresFor(_type);
    final rest = [
      for (final g in genresFor(_type))
        if (!popular.contains(g)) g,
    ];

    return ConstrainedBox(
      // Never taller than most of the screen; the genres scroll inside.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GlassPanelHeader(title: 'Discover'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.md),
            child: GlassSegmentedControl(
              labels: const ['Films', 'Shows'],
              index: _type == MediaType.tv ? 1 : 0,
              onChanged: (i) =>
                  _setType(i == 1 ? MediaType.tv : MediaType.movie),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cell(null),
                  const SizedBox(height: AppSpace.lg),
                  const GlassSectionLabel('Popular'),
                  const SizedBox(height: AppSpace.sm),
                  _grid(popular),
                  const SizedBox(height: AppSpace.md),
                  const GlassSectionLabel('More genres'),
                  const SizedBox(height: AppSpace.sm),
                  _grid(rest),
                ],
              ),
            ),
          ),
          // The way out, pinned under the list so it's always in reach.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
            child: GlassPillButton(
              label: 'Done',
              prominent: true,
              expand: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A genre in the filter panel: a quiet well, lit with a check when chosen.
class _GenreCell extends StatelessWidget {
  const _GenreCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 42.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GlassPressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selected)
                GlassLens(radius: radius)
              else
                DecoratedBox(decoration: glassWellDecoration(radius: 12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(
                          fontSize: 14,
                          color: AppColors.ink,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(CupertinoIcons.checkmark_alt,
                          size: 15, color: AppColors.ink),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    required this.headerHeight,
    required this.player,
    required this.muted,
    required this.landscape,
    required this.onToggleMute,
    required this.onLandscape,
    required this.onPlay,
  });

  final TrailerItem item;
  final bool current;

  /// Status bar plus Discover's switches, which float over the page.
  final double headerHeight;
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
        final top = headerHeight;
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
    this.actionLabel = 'Check again',
  });

  final String title;
  final String body;
  final Future<void> Function() onRetry;
  final String actionLabel;

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
            GlassPillButton(label: actionLabel, compact: true, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
