import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/list_model.dart';
import '../../providers/lists/list_provider.dart';
import '../lists/playlist_cover.dart';
import '../shell/glass_shell.dart' show shellBranchIndex, shellChromeVisible;
import '../widgets/comments_sheet.dart' show GlassHint;
import '../widgets/glass_panel.dart';
import '../widgets/verified_mark.dart';

/// Explore › Lists (migration 029): our 35mm Selects up top, the first
/// one featured and the rest leaning in a row, then the community's best
/// lists this week, then every mood.
class ExploreListsSection extends ConsumerWidget {
  const ExploreListsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selects = ref.watch(selectsProvider);
    final community = ref.watch(exploreListsProvider(null));
    final moods = ref.watch(moodCountsProvider).valueOrNull ?? const {};

    final picks = selects.valueOrNull ?? const <ExploreListEntry>[];
    final lists = community.valueOrNull ?? const <ExploreListEntry>[];
    final loading = (selects.isLoading && picks.isEmpty) ||
        (community.isLoading && lists.isEmpty);

    if (loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xxl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    if (picks.isEmpty && lists.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            GlassHint(
              icon: CupertinoIcons.square_stack,
              title: selects.hasError || community.hasError
                  ? 'Couldn\'t load lists'
                  : 'Lists are on their way',
              body: selects.hasError || community.hasError
                  ? 'Check your connection and pull to refresh.'
                  : 'Make a public playlist with three or more films and it '
                      'can show up here.',
            ),
          ],
        ),
      );
    }

    final today = dailyFeatured(picks, DateTime.now());

    return SliverMainAxisGroup(
      slivers: [
        if (picks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _HeroCarousel(entries: today.featured),
          ),
          if (today.rest.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.xxl, AppSpace.lg, AppSpace.md),
                child: Text('35mm Selects', style: AppText.title),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: _SelectCard.height + 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
                  itemCount: today.rest.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 18),
                  itemBuilder: (_, i) => _SelectCard(entry: today.rest[i]),
                ),
              ),
            ),
          ],
        ],
        if (lists.isNotEmpty) ...[
          const SliverToBoxAdapter(child: _Rule()),
          const SliverToBoxAdapter(
            child: _Kicker('From the community', trailing: 'This week'),
          ),
          SliverList.builder(
            itemCount: lists.length,
            itemBuilder: (_, i) =>
                CommunityListRow(entry: lists[i], rank: i + 1),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
        const SliverToBoxAdapter(child: _Kicker('Browse by mood')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpace.lg,
              mainAxisExtent: 48,
            ),
            itemCount: ListMood.values.length,
            itemBuilder: (_, i) {
              final m = ListMood.values[i];
              return _MoodCell(mood: m, count: moods[m] ?? 0);
            },
          ),
        ),
      ],
    );
  }
}

/// Today's featured Selects and the rest, in our order. Three at a time,
/// moving on by three each day, so over a few days every Select gets its
/// turn up top, and everyone sees the same three on the same day.
({List<ExploreListEntry> featured, List<ExploreListEntry> rest}) dailyFeatured(
    List<ExploreListEntry> selects, DateTime now,
    {int count = 3}) {
  final n = selects.length;
  if (n <= count) return (featured: selects, rest: const []);
  // The calendar day, not 24-hour blocks, so it turns over at midnight.
  final day =
      DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  final start = (day * count) % n;
  final picked = {for (var i = 0; i < count; i++) (start + i) % n};
  return (
    featured: [for (final i in picked) selects[i]],
    rest: [
      for (var i = 0; i < n; i++)
        if (!picked.contains(i)) selects[i],
    ],
  );
}

/// The featured Selects, one at a time, moving on by themselves. A swipe
/// takes over and the autoscroll waits a while before it carries on; it
/// also rests while Explore isn't on screen.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.entries});

  final List<ExploreListEntry> entries;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  static const _exploreTab = 2;
  static const _every = Duration(seconds: 5);

  /// Far enough into a long run of pages to go either way forever.
  static const _middle = 3000;

  late final PageController _pages =
      PageController(initialPage: widget.entries.length > 1 ? _middle : 0);
  Timer? _timer;
  DateTime _heldUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _page = 0;

  int get _n => widget.entries.length;

  @override
  void initState() {
    super.initState();
    if (_n > 1) _timer = Timer.periodic(_every, (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || !_pages.hasClients) return;
    final onScreen = shellBranchIndex.value == _exploreTab &&
        shellChromeVisible.value &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!onScreen || DateTime.now().isBefore(_heldUntil)) return;
    _pages.nextPage(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const height = _SelectHero.height;
    return Column(
      children: [
        SizedBox(
          // Room for the card's shadow below it.
          height: height + 28,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) {
                _heldUntil = DateTime.now().add(const Duration(seconds: 10));
              }
              return false;
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: _n > 1 ? _middle * 2 : _n,
              onPageChanged: (i) => setState(() => _page = i % _n),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.sm, AppSpace.lg, 20),
                child: _SelectHero(entry: widget.entries[i % _n]),
              ),
            ),
          ),
        ),
        if (_n > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _n; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _page
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The featured Select: its cover full width, the title set over it.
class _SelectHero extends StatelessWidget {
  const _SelectHero({required this.entry});

  final ExploreListEntry entry;

  static const height = 380.0;

  @override
  Widget build(BuildContext context) {
    final list = entry.list;
    return Semantics(
      button: true,
      label: '35mm Selects: ${list.displayTitle}',
      child: GlassPressable(
        onTap: () => context.push('/lists/${list.id}'),
        child: LayoutBuilder(builder: (context, c) {
          const height = _SelectHero.height;
          return Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlaylistCover.of(list,
                      posters: entry.posters,
                      size: c.maxWidth,
                      height: height,
                      radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1],
                        colors: [Colors.transparent, Color(0xE0000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '35MM SELECTS',
                          style: AppText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          list.displayTitle,
                          style: AppText.largeTitle.copyWith(
                            fontSize: 32,
                            height: 1.0,
                            letterSpacing: -0.8,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (list.tagline != null) ...[
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            list.tagline!,
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A Select in the row: its cover turned a little away, every one at the
/// same angle, with its title and line flat underneath.
class _SelectCard extends StatelessWidget {
  const _SelectCard({required this.entry});

  final ExploreListEntry entry;

  static const width = 164.0;
  static const height = 219.0;

  /// Each card gets its own perspective, so they all look the same rather
  /// than bending towards one vanishing point.
  static final Matrix4 _lean = Matrix4.identity()
    ..setEntry(3, 2, 0.0011)
    ..rotateY(20 * math.pi / 180)
    ..rotateX(-2 * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    final list = entry.list;
    // Our artwork carries its own title; anything else gets it set over.
    final titled = list.coverStyle != ListCoverStyle.artwork;
    return Semantics(
      button: true,
      label: list.displayTitle,
      child: GlassPressable(
        onTap: () => context.push('/lists/${list.id}'),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform(
                transform: _lean,
                alignment: Alignment.center,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 30,
                        offset: const Offset(12, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlaylistCover.of(list,
                            posters: entry.posters,
                            size: width,
                            height: height,
                            radius: 0),
                        if (titled) ...[
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.45, 1],
                                colors: [Colors.transparent, Color(0xD0000000)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Text(
                              list.displayTitle,
                              style: AppText.headline.copyWith(
                                fontSize: 18,
                                height: 1.05,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                list.displayTitle,
                style: AppText.label
                    .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (list.tagline != null)
                Text(
                  list.tagline!,
                  style:
                      AppText.footnote.copyWith(color: AppColors.inkSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A community list, ranked: three of its posters fanned back, the title,
/// and who made it. Also the rows of a mood.
class CommunityListRow extends StatelessWidget {
  const CommunityListRow({super.key, required this.entry, this.rank});

  final ExploreListEntry entry;

  /// Shown as a large numeral when given.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final list = entry.list;
    final n = list.itemCount;
    final saves = list.saveCount;
    final meta = [
      '$n film${n == 1 ? '' : 's'}',
      if (saves > 0) '${_compact(saves)} save${saves == 1 ? '' : 's'}',
    ].join(' · ');

    return GlassPressable(
      onTap: () => context.push('/lists/${list.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.lg - 2),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x73545458), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 34,
                child: Text(
                  rank!.toString().padLeft(2, '0'),
                  style: AppText.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppColors.inkTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            _PosterFan(posters: entry.posters),
            const SizedBox(width: AppSpace.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.displayTitle,
                    style: AppText.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (entry.ownerUsername != null) ...[
                        Flexible(
                          child: Text(
                            entry.ownerUsername!,
                            style: const TextStyle(
                              fontFamily: AppText.usernameFamily,
                              fontSize: 19,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        VerifiedMark(userId: list.userId, size: 12),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        entry.ownerUsername != null ? '· $meta' : meta,
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';
}

/// Three posters overlapping, the back ones fainter: a list's thumbnail in
/// a row. Whatever the list's own cover is, this is how it's previewed.
class _PosterFan extends StatelessWidget {
  const _PosterFan({required this.posters});

  final List<String> posters;

  static const _w = 48.0;
  static const _h = 72.0;
  static const _step = 22.0;

  @override
  Widget build(BuildContext context) {
    final shown = posters.take(3).toList();
    return SizedBox(
      width: _w + _step * 2,
      height: _h,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: _step * i,
              child: Opacity(
                opacity: const [1.0, 0.8, 0.55][i],
                child: Container(
                  width: _w,
                  height: _h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: i == shown.length - 1
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 10,
                              offset: const Offset(4, 0),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: CachedNetworkImage(
                      imageUrl: ApiConstants.getPosterUrl(shown[i],
                          size: ApiConstants.posterSizeSmall),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: AppColors.surface),
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: AppColors.surface),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoodCell extends StatelessWidget {
  const _MoodCell({required this.mood, required this.count});

  final ListMood mood;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/explore/mood/${mood.slug}');
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x73545458), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                mood.label,
                style: AppText.title.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: AppText.caption.copyWith(
                  color: AppColors.inkTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small caps over a section, with a quiet note on the right.
class _Kicker extends StatelessWidget {
  const _Kicker(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.9,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary)),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
      color: const Color(0x99545458),
    );
  }
}

/// `/explore/mood/:mood`: every public list with that mood, Selects too.
class MoodListsScreen extends ConsumerWidget {
  const MoodListsScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ListMood.parse(slug);
    final lists = mood == null
        ? const AsyncValue<List<ExploreListEntry>>.data([])
        : ref.watch(exploreListsProvider(mood));
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.canvas,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: AppColors.ink),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOOD',
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.9,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(mood?.label ?? 'Lists', style: AppText.largeTitle),
                ],
              ),
            ),
          ),
          ...lists.when(
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.xxl),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ),
            ],
            error: (_, __) => const [
              SliverToBoxAdapter(
                child: GlassHint(
                  icon: CupertinoIcons.wifi_exclamationmark,
                  title: 'Couldn\'t load lists',
                  body: 'Check your connection and try again.',
                ),
              ),
            ],
            data: (entries) => entries.isEmpty
                ? [
                    SliverToBoxAdapter(
                      child: GlassHint(
                        icon: CupertinoIcons.square_stack,
                        title:
                            'No ${mood?.label.toLowerCase() ?? ''} lists yet',
                        body: 'Give one of your playlists this mood in Edit '
                            'and it shows up here.',
                      ),
                    ),
                  ]
                : [
                    SliverList.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) =>
                          CommunityListRow(entry: entries[i]),
                    ),
                  ],
          ),
          SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 40)),
        ],
      ),
    );
  }
}

/// Whether Explore is on Lists rather than Takes. Kept for the session, so
/// coming back to the tab finds it where you left it.
final exploreShowsListsProvider = StateProvider<bool>((ref) => false);
