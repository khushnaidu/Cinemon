import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import 'shell/glass_shell.dart'
    show
        kFloatingTabBarInset,
        kFloatingHeaderInset,
        shellChromeVisible,
        shellTabReselects;
import 'widgets/glass_panel.dart' show GlassPillButton;
import 'widgets/native_glass_button.dart';
import 'widgets/poster_ambience.dart';
import 'widgets/review_card_back.dart';
import '../models/activity_model.dart';
import '../models/explore_post_model.dart';
import '../models/home_feed.dart';
import '../models/sticker_model.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/notification/notification_provider.dart';
import 'explore/explore_post_card.dart';
import 'explore/explore_thread.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/episode_card_front.dart';

import 'widgets/sticker_picker_sheet.dart';
import 'widgets/reactions_preview.dart' show showReactionsBreakdown;
import 'widgets/review_editor.dart';
import 'widgets/verified_mark.dart';
import '../providers/user/verified_provider.dart';

class HomeFeedPage extends ConsumerStatefulWidget {
  const HomeFeedPage({super.key});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  StreamSubscription<int>? _reselectSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
    // Tapping Home while on Home goes back to the top of the feed.
    _reselectSub = shellTabReselects.listen((tab) {
      if (tab == 0) _toTop();
    });
  }

  @override
  void dispose() {
    _reselectSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// A long way jumps most of it first, so every card in between isn't
  /// built on the way up.
  void _toTop() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page?.round() ?? 0;
    if (page == 0) return;
    if (page > 3) _pageController.jumpToPage(3);
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  void _onScroll() {
    final currentIndex = _pageController.page?.round() ?? 0;
    if (currentIndex != _currentIndex) {
      setState(() {
        _currentIndex = currentIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      // No app bar at all. The feed is edge-to-edge artwork, and a bar — even
      // a blurred one — is a horizontal rule across the top of it. The two
      // actions it held now float over the content as glass, so the poster
      // runs the full height of the screen and refracts under them.
      //
      // extendBody so the feed also runs under the shell's floating tab bar.
      extendBody: true,
      body: Stack(
        children: [
          SizedBox.expand(
            child: feedAsync.when(
              loading: () => const _LoadingShimmer(),
              error: (error, _) => _ErrorView(
                error: error.toString(),
                onRetry: () => ref.refresh(homeFeedProvider),
              ),
              data: (feed) {
                final items = feed.items;
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(homeFeedProvider);
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 150,
                        child: _EmptyFeedView(
                          onRefresh: () => ref.refresh(homeFeedProvider),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(homeFeedProvider);
                    ref.invalidate(verifiedUsersProvider);
                    // Wait a bit for the refresh to complete
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: items.length,
                    // A few pages before the end, so the next page is there
                    // by the time anyone reaches it.
                    onPageChanged: (i) {
                      if (i >= items.length - 4) {
                        ref.read(homeFeedProvider.notifier).loadMore();
                      }
                    },
                    itemBuilder: (context, index) => switch (items[index]) {
                      HomeActivity(:final activity) => _ActivityCard(
                          key: ValueKey(activity.id), activity: activity),
                      HomeExplorePost(:final post) =>
                        _ExplorePostPage(key: ValueKey(post.id), post: post),
                    },
                  ),
                );
              },
            ),
          ),

          // Floating actions, where the app bar used to be.
          //
          // Gated on shellChromeVisible for the same reason the tab bar is:
          // these are platform views, so they composite above every Flutter
          // layer and would otherwise float over sheets and pushed screens.
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: AppSpace.lg,
            right: AppSpace.lg,
            child: ValueListenableBuilder<bool>(
              valueListenable: shellChromeVisible,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NativeGlassButton(
                      symbol: 'person.2',
                      label: 'People',
                      fallbackIcon: CupertinoIcons.person_2,
                      onTap: () => context.push('/friends'),
                    ),
                    NativeGlassButton(
                      symbol: 'heart',
                      label: 'Activity',
                      fallbackIcon: CupertinoIcons.heart,
                      badge: unreadCount.valueOrNull ?? 0,
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The flip card's intrinsic size. Everything inside it, including where the
/// stickers spill past the poster, is positioned against these.
const double _kCardWidth = 300;
const double _kCardHeight = 440;

/// Height of the author row — avatar diameter, which the name is capped to.
const double _kAuthorHeight = 60;

/// How far the author row sits above the card's top edge: its own height plus
/// the gap to the poster.
///
/// This is the number that decides how big the poster can be, and it costs
/// double: the card is only centred if the gutters match, so both reserve it.
/// Stacking the avatar over the name made this 132, which took 264 out of a
/// ~640pt band and pulled the card down to ~377. On one line it's 72, and the
/// card keeps its full 440.
const double _kAuthorRise = _kAuthorHeight + 12;

/// The timestamp and tap hint below the card, plus their gap to it.
const double _kFooterBlock = 52;

/// Who posted it: avatar over @username, centred above the card.
///
/// This replaced a left-aligned row that also carried "reviewed <film>". The
/// film title is already the largest thing on the poster directly below, so
/// the line was restating it — and pinning the block to the left edge of a
/// centred card left it visibly off-axis.
class _PostAuthor extends StatelessWidget {
  const _PostAuthor({required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final photo = activity.userPhotoUrl;

    return GestureDetector(
      onTap: () => context.push('/profile/${activity.userId}'),
      // Opaque so the gap between avatar and name is tappable too, rather than
      // the two reading as separate targets.
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: _kAuthorHeight,
        child: Row(
          // Centred explicitly, not via mainAxisSize.min: the Positioned above
          // pins left and right, so the Row's width is already tight and min
          // has nothing to shrink to. Without this the pair sits left.
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: _kAuthorHeight / 2,
              backgroundColor: AppColors.surfaceElevated,
              backgroundImage:
                  photo != null ? CachedNetworkImageProvider(photo) : null,
              child: photo == null
                  ? const Icon(CupertinoIcons.person_fill,
                      color: AppColors.inkTertiary, size: 30)
                  : null,
            ),
            const SizedBox(width: AppSpace.md),

            // The username in the username face, as on the profile. A long name
            // shrinks to fit the width rather than being cut off: losing
            // letters off a username is worse than losing a few points.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '@',
                        style: TextStyle(
                          fontFamily: 'Helvetica Neue',
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                      TextSpan(
                        text: activity.username,
                        style: const TextStyle(
                          fontFamily: AppText.usernameFamily,
                          fontSize: 30,
                          color: AppColors.ink,
                        ),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: VerifiedMark(
                            userId: activity.userId, size: 18, gap: 6),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  // Load-bearing, not decoration: this sits directly above the
                  // poster and posters are frequently pale up there.
                  style: const TextStyle(
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 12),
                      Shadow(color: Colors.black45, blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual activity card with flip animation
class _ActivityCard extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const _ActivityCard({super.key, required this.activity});

  @override
  ConsumerState<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends ConsumerState<_ActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  /// Every card flips, including your own.
  ///
  /// Your posts used to open an edit sheet instead, which meant the one person
  /// who couldn't see their own review the way everyone else does was the
  /// person who wrote it. Editing is now a button on the back, where it's a
  /// deliberate choice rather than the only thing a tap can do.
  void _onCardTap() => _toggleCard();

  void _navigateToFilmDetail() {
    final mediaType = widget.activity.mediaType.isNotEmpty
        ? widget.activity.mediaType
        : 'movie';
    context.push(
      '/film/${widget.activity.filmId}/$mediaType',
      extra: widget.activity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnActivity = currentUser?.uid == widget.activity.userId;

    // Both chrome layers float over the feed, so the page is full-height.
    // Insetting keeps the card centred in the *visible* band without shrinking
    // the page — posters still slide under the glass on scroll.
    //
    // Both edges take the safe-area inset as well as the chrome height. The
    // bottom used to be a flat 78, which ignored the home indicator and so let
    // the band run ~18pt under the tab bar — half of which the card was
    // sitting low by.
    final safeArea = MediaQuery.paddingOf(context);
    final topInset = safeArea.top + kFloatingHeaderInset;
    final bottomInset = safeArea.bottom + kFloatingTabBarInset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final band = constraints.maxHeight - topInset - bottomInset;

        // Room the gutters must never give up, so neither block is clipped on
        // a short screen. Both sides reserve the larger of the two, since the
        // gutters are equal by construction.
        final reserve = math.max(_kAuthorRise, _kFooterBlock) * 2;
        final cardHeight = math.min(_kCardHeight, band - reserve);
        final cardWidth = _kCardWidth * (cardHeight / _kCardHeight);

        return Stack(
          children: [
            // The poster's own light, thrown onto the black behind it. Sized
            // and aimed from the same numbers as the card, since the beam only
            // works if it's actually centred on the thing casting it.
            //
            // Painted per page rather than once behind the PageView so the
            // light travels with its poster on a swipe. It fades out well
            // before the page edges, so the seam between two pages mid-scroll
            // never shows.
            Positioned.fill(
              child: PosterAmbience(
                posterUrl: _posterUrl,
                cardCenter: Offset(
                  constraints.maxWidth / 2,
                  topInset + band / 2,
                ),
                cardSize: Size(cardWidth, cardHeight),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
              // Two equal Expanded gutters with the card between them is what
              // actually centres it. A `mainAxisAlignment: center` could not:
              // the card was Flexible, so it absorbed every spare pixel and
              // there was no slack left for the alignment to distribute. What
              // you got instead was the card centred in the gap *between* the
              // header and footer blocks — and since those aren't the same
              // height, it sat low by half their difference.
              child: Column(
                children: [
                  const Expanded(child: SizedBox.shrink()),

                  // The flip card, scaled rather than reflowed. Its internals —
                  // and the sticker spill offsets — are built against fixed
                  // 300x440 metrics, so scaling the whole thing keeps that
                  // geometry intact where recomputing it would not.
                  SizedBox(
                    height: cardHeight,
                    width: cardWidth,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: GestureDetector(
                              onTap: _onCardTap,
                              child: AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, child) {
                                  final angle = _flipAnimation.value * math.pi;
                                  final transform = Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(angle);

                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: transform,
                                    child: angle < math.pi / 2
                                        ? _buildFrontCard()
                                        : Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(math.pi),
                                            child: _buildBackCard(),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpace.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.activity.relativeTime,
                              style: AppText.caption
                                  .copyWith(color: AppColors.inkSecondary),
                            ),
                            if (!_showBack)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpace.sm),
                                child: Text(
                                  isOwnActivity
                                      ? 'Tap to edit'
                                      : (widget.activity.hasRating ||
                                              widget.activity.hasReview)
                                          ? 'Tap to see review'
                                          : 'Tap to view',
                                  style: AppText.footnote
                                      .copyWith(color: AppColors.inkTertiary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The author, over the card's top edge rather than stacked above
            // it in the Column.
            //
            // This is what lets both get bigger. In a Column the block and
            // the card compete for the same band — and because the card can
            // only be centred if the gutters match, every extra point of
            // header cost the card two. Overlapping means only the part that
            // actually protrudes (_kAuthorRise) has to be reserved.
            //
            // It's placed here, in the page's Stack, and not in the card's
            // own Stack at a negative offset: Flutter only delivers taps
            // inside a widget's bounds, so there it drew but couldn't be
            // tapped. The card is centred in the band (equal gutters), which
            // gives its top.
            Positioned(
              top: topInset + (band - cardHeight) / 2 - _kAuthorRise,
              left: (constraints.maxWidth - cardWidth) / 2,
              width: cardWidth,
              child: _PostAuthor(activity: widget.activity),
            ),
          ],
        );
      },
    );
  }

  /// The poster the card shows — and the image the ambience samples. Both go
  /// through the same helper at the same size so they hit one cache entry
  /// rather than downloading the artwork twice.
  String get _posterUrl => ApiConstants.getPosterUrl(
        widget.activity.filmPosterPath,
        size: ApiConstants.posterSizeLarge,
      );

  Widget _buildFrontCard() {
    final posterUrl = _posterUrl;

    // Get unique stickers from reactions for scattered display (up to 5)
    final reactionStickers = widget.activity.reactions.values.toList();
    final uniqueStickers = reactionStickers.toSet().toList();

    return SizedBox(
      width: 300, // Slight extra width for sticker spill
      height: 440, // Slight extra height for sticker spill
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main poster card - centered
          Positioned(
            left: 10,
            top: 15,
            child: Container(
              width: 280,
              height: 420,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Poster — or, for an episode post, the still with the
                    // show / season / episode spelled out beneath it.
                    Positioned.fill(
                      child: widget.activity.isEpisode
                          ? EpisodeCardFront(activity: widget.activity)
                          : posterUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      _buildPosterPlaceholder(),
                                  errorWidget: (context, url, error) =>
                                      _buildPosterPlaceholder(),
                                )
                              : _buildPosterPlaceholder(),
                    ),

                    // Comment count badge at bottom-left
                    if (widget.activity.commentCount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: GestureDetector(
                          onTap: _showComments,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${widget.activity.commentCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Scattered stickers at top-right corner (spilling off card)
          ..._buildScatteredStickers(uniqueStickers, reactionStickers),
        ],
      ),
    );
  }

  /// The sticker artwork itself, sized explicitly because it's drawn twice —
  /// once as the shadow's silhouette and once on top — and both copies have to
  /// lay out identically or the shadow won't register with the sticker.
  Widget _stickerArt(StickerModel sticker) => Image.asset(
        sticker.assetPath,
        width: 95,
        height: 95,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => SizedBox(
          width: 95,
          height: 95,
          child: Center(
            child: Text(
              sticker.emoji,
              style: const TextStyle(fontSize: 65),
            ),
          ),
        ),
      );

  List<Widget> _buildScatteredStickers(
      List<String> uniqueStickers, List<String> allStickers) {
    if (uniqueStickers.isEmpty) return [];

    final widgets = <Widget>[];
    final count = uniqueStickers.length.clamp(0, 5);

    // Card position within the SizedBox: left=10, top=15, width=280
    // Card right edge is at 10 + 280 = 290, SizedBox width = 300
    // So from SizedBox right edge, card right edge is at 300 - 290 = 10
    const cardRightOffset = 10.0;
    const cardTop = 15.0;

    for (int i = 0; i < count; i++) {
      final stickerId = uniqueStickers[i];
      final sticker = StickerRegistry.getStickerById(stickerId);
      if (sticker == null) continue;

      // Get deterministic placement at top-right corner
      final placement = StickerRegistry.getSeededPlacement(
        widget.activity.id,
        i,
        totalStickers: count,
      );

      // Count how many of this sticker
      final stickerCount = allStickers.where((s) => s == stickerId).length;

      // Position relative to card's top-right corner
      final stickerRight = cardRightOffset + placement.right;
      final stickerTop = cardTop + placement.top;

      widgets.add(
        Positioned(
          top: stickerTop,
          right: stickerRight,
          child: Transform.rotate(
            angle: placement.rotation,
            child: GestureDetector(
              onTap: () => showReactionsBreakdown(
                context: context,
                reactions: widget.activity.reactions,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The sticker's shadow, cast by its silhouette.
                  //
                  // A BoxShadow can't do this: it's a shadow of the *box*, so
                  // a cut-out PNG in a 95x95 container threw a 95x95 square.
                  // Drawing the artwork a second time collapsed to black gives
                  // a shape that follows the alpha, and blurring and offsetting
                  // that is the shadow. Sigma is BoxShadow's blurRadius/2 —
                  // its own conversion — so the softness is unchanged.
                  Transform.translate(
                    offset: const Offset(3, 4),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.5),
                          BlendMode.srcIn,
                        ),
                        child: _stickerArt(sticker),
                      ),
                    ),
                  ),
                  _stickerArt(sticker),
                  // Count badge if more than 1
                  if (stickerCount > 1)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'x$stickerCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _showComments() {
    showCommentsSheet(
      context,
      activityId: widget.activity.id,
      filmTitle: widget.activity.displayTitle,
      activityOwnerId: widget.activity.userId,
      filmPosterPath: widget.activity.filmPosterPath,
    );
  }

  Widget _buildBackCard() {
    final currentUser = ref.watch(currentUserProvider);

    return ReviewCardBack(
      activity: widget.activity,
      // Matches the front's poster exactly, so the card doesn't change size
      // through the flip.
      width: 280,
      height: 420,
      posterUrl: _posterUrl,
      currentUserId: currentUser?.uid,
      onEdit: currentUser?.uid == widget.activity.userId
          ? () => showReviewEditor(context, widget.activity)
          : null,
      onOpenFilm: _navigateToFilmDetail,
      onComment: _showComments,
      onReact: () => showStickerPicker(
        context: context,
        activityId: widget.activity.id,
        currentStickerId: currentUser != null
            ? widget.activity.getReactionFrom(currentUser.uid)
            : null,
        activityOwnerId: widget.activity.userId,
        filmTitle: widget.activity.filmTitle,
        filmPosterPath: widget.activity.filmPosterPath,
      ),
      onLike: () {
        if (currentUser == null) return;
        ref.read(likeNotifierProvider.notifier).toggleLike(
              widget.activity.id,
              likedNow(ref, widget.activity, currentUser.uid),
            );
      },
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      width: 280,
      height: 420,
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 8),
          Text(
            widget.activity.displayTitle,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A friend's Explore post, on Home (ADR 0001, 4.6).
///
/// The same card as on Explore, so a like here is a like there, under a
/// small kicker that says it's public. Centred in the band between the
/// floating chrome, and scaled down rather than clipped if a long one
/// doesn't fit. Lit like the log cards, from the post's own artwork.
class _ExplorePostPage extends ConsumerStatefulWidget {
  const _ExplorePostPage({super.key, required this.post});

  final ExplorePost post;

  @override
  ConsumerState<_ExplorePostPage> createState() => _ExplorePostPageState();
}

class _ExplorePostPageState extends ConsumerState<_ExplorePostPage> {
  final _page = GlobalKey();
  final _card = GlobalKey();

  /// Where the card ended up, in page coordinates. The card's height depends
  /// on what's in it, so the light is aimed after layout rather than guessed.
  Rect? _cardRect;

  ExplorePost get post => widget.post;

  /// What to light the page with: the film, the playlist's lead poster, or
  /// for a post about nothing in particular, the author's photo.
  String get _lightSource {
    final s = post.subject;
    if (s != null) {
      final url = ApiConstants.getPosterUrl(s.posterPath,
          size: ApiConstants.posterSizeLarge);
      if (url.isNotEmpty) return url;
    }
    final lead = post.list?.posters.whereType<String>().firstOrNull;
    if (lead != null) {
      return ApiConstants.getPosterUrl(lead,
          size: ApiConstants.posterSizeLarge);
    }
    return post.userPhotoUrl ?? '';
  }

  void _measure() {
    final page = _page.currentContext?.findRenderObject() as RenderBox?;
    final card = _card.currentContext?.findRenderObject() as RenderBox?;
    if (page == null || card == null || !card.hasSize) return;
    final rect = card.localToGlobal(Offset.zero, ancestor: page) & card.size;
    if (rect != _cardRect) setState(() => _cardRect = rect);
  }

  void _openSubject(ExploreSubject s) =>
      context.push('/film/${s.filmId}/${s.mediaType}');

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.paddingOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final light = _lightSource;
    final rect = _cardRect;

    return Stack(
      key: _page,
      children: [
        if (light.isNotEmpty && rect != null)
          Positioned.fill(
            child: PosterAmbience(
              posterUrl: light,
              cardCenter: rect.center,
              cardSize: rect.size,
              // A text card, not a poster: the light sits further back.
              intensity: 0.7,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.lg,
            safeArea.top + kFloatingHeaderInset,
            AppSpace.lg,
            safeArea.bottom + kFloatingTabBarInset,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 420.0);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.globe,
                            size: 13, color: AppColors.inkSecondary),
                        const SizedBox(width: 5),
                        Text(
                          'POSTED ON EXPLORE',
                          style: AppText.footnote.copyWith(
                            color: AppColors.inkSecondary,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Flexible(
                      child: FittedBox(
                        key: _card,
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: width,
                          // The card's own fill is nearly clear; over the
                          // light it needs a darker base to stay readable.
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ExplorePostCard(
                              post: post,
                              onOpen: () => showExploreThread(
                                context,
                                post,
                                onSubjectTap: _openSubject,
                              ),
                              onSubjectTap: _openSubject,
                              onMenu: () =>
                                  showExplorePostMenu(context, ref, post),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      post.relativeTime,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Loading shimmer placeholder
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 150,
                      height: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 280,
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty feed view
class _EmptyFeedView extends StatelessWidget {
  final VoidCallback? onRefresh;

  const _EmptyFeedView({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Your feed is empty',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Follow some people or post your first watch to get started!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GlassPillButton(
              label: 'Search Films',
              icon: CupertinoIcons.search,
              prominent: true,
              onTap: () => context.push('/search'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _ErrorView({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              GlassPillButton(
                label: 'Try Again',
                icon: CupertinoIcons.arrow_clockwise,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
