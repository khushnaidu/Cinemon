import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoIcons,
        CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../../models/film_model.dart';
import '../../providers/explore/explore_provider.dart';
import '../../providers/movie/movie_provider.dart';
import '../../repositories/explore_repository.dart' show ExploreSort;
import '../shell/glass_shell.dart'
    show kFloatingTabBarInset, shellChromeVisible;
import '../widgets/app_search_field.dart';
import '../widgets/comments_sheet.dart' show GlassHint;
import '../widgets/glass_panel.dart';
import '../widgets/native_glass_button.dart';
import 'explore_composer.dart';
import 'explore_post_card.dart';
import 'explore_thread.dart';
import 'subject_picker.dart' show MediaResultRow;

/// Explore: what everyone is saying about film and TV.
///
/// One scrolling column: title and compose, a search that narrows the feed
/// to one title, the kinds as chips, then the posts. Searching swaps the feed
/// for results in place; picking one pins a banner for that title above the
/// feed until it's cleared.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String _term = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_searching) {
        setState(() => _searching = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  ExploreFilter get _filter => ref.read(exploreFilterProvider);

  void _setFilter(ExploreFilter f) {
    ref.read(exploreFilterProvider.notifier).state = f;
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _term = value.trim());
    });
  }

  void _endSearch() {
    _search.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _term = '';
      _searching = false;
    });
  }

  void _filterBySubject(ExploreSubject subject) {
    _endSearch();
    _setFilter(_filter.copyWith(subject: subject));
  }

  Future<void> _compose() async {
    final f = _filter;
    await showExploreComposer(
      context,
      subject: f.subject,
      kind: f.kind ?? ExploreKind.thought,
    );
  }

  void _open(ExplorePost post, {bool reply = false}) {
    showExploreThread(
      context,
      post,
      onSubjectTap: _filterBySubject,
      focusComposer: reply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final filter = ref.watch(exploreFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (!_searching && n.metrics.extentAfter < 700) {
                ref.read(exploreFeedProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: pad.top + 4)),
                if (!_searching)
                  CupertinoSliverRefreshControl(
                    onRefresh: () =>
                        ref.read(exploreFeedProvider.notifier).refresh(),
                  ),

                // Title. The compose button floats beside it (see below).
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding:
                          EdgeInsets.only(left: AppSpace.lg + 2, right: 72),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Explore', style: AppText.largeTitle),
                      ),
                    ),
                  ),
                ),

                // Search, with the iOS Cancel beside it while active.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FocusableSearch(
                            controller: _search,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _searching
                              ? GestureDetector(
                                  onTap: _endSearch,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: AppSpace.md),
                                    child: Text(
                                      'Cancel',
                                      style: AppText.body.copyWith(
                                        fontSize: 17,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_searching)
                  ..._searchSlivers()
                else ...[
                  // Kinds.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 32 + AppSpace.lg * 2,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.lg, vertical: AppSpace.lg),
                        children: [
                          GlassChip(
                            label: 'All',
                            selected: filter.kind == null,
                            onTap: () =>
                                _setFilter(filter.copyWith(clearKind: true)),
                          ),
                          for (final k in _chipOrder) ...[
                            const SizedBox(width: AppSpace.sm),
                            GlassChip(
                              label: k.plural,
                              selected: filter.kind == k,
                              onTap: () => _setFilter(filter.kind == k
                                  ? filter.copyWith(clearKind: true)
                                  : filter.copyWith(kind: k)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (filter.subject != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                        child: _SubjectBanner(
                          subject: filter.subject!,
                          onClear: () =>
                              _setFilter(filter.copyWith(clearSubject: true)),
                          onPost: _compose,
                        ),
                      ),
                    ),

                  // Section label + sort.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xl, 0, AppSpace.lg, AppSpace.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: GlassSectionLabel(
                              filter.kind?.plural ?? 'From everyone',
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: GlassSegmentedControl(
                              labels: const ['Latest', 'Top'],
                              index: filter.sort == ExploreSort.top ? 1 : 0,
                              onChanged: (i) => _setFilter(filter.copyWith(
                                sort: i == 1
                                    ? ExploreSort.top
                                    : ExploreSort.latest,
                              )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  ..._feedSlivers(filter),
                ],

                SliverToBoxAdapter(
                  child: SizedBox(
                      height: pad.bottom + kFloatingTabBarInset + AppSpace.xl),
                ),
              ],
            ),
          ),

          // Compose. A platform view, so gated on shellChromeVisible like the
          // home feed's buttons — it would otherwise float over panels.
          Positioned(
            top: pad.top + 4,
            right: AppSpace.lg,
            child: ValueListenableBuilder<bool>(
              valueListenable: shellChromeVisible,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return NativeGlassButton(
                  symbol: 'square.and.pencil',
                  label: 'New post',
                  fallbackIcon: CupertinoIcons.square_pencil,
                  onTap: _compose,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _chipOrder = [
    ExploreKind.take,
    ExploreKind.review,
    ExploreKind.critique,
    ExploreKind.discussion,
    ExploreKind.list,
    ExploreKind.thought,
  ];

  List<Widget> _feedSlivers(ExploreFilter filter) {
    final feed = ref.watch(exploreFeedProvider);

    if (feed.loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
            itemBuilder: (_, i) => _PlaceholderCard(tall: i == 1),
          ),
        ),
      ];
    }

    if (feed.error != null && feed.posts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const GlassHint(
                icon: CupertinoIcons.wifi_exclamationmark,
                title: 'Couldn\'t load Explore',
                body: 'Check your connection and try again.',
              ),
              GlassPillButton(
                label: 'Try again',
                icon: CupertinoIcons.arrow_clockwise,
                onTap: () => ref.read(exploreFeedProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ];
    }

    if (feed.posts.isEmpty) {
      final about = filter.subject?.title;
      return [
        SliverToBoxAdapter(
          child: Column(
            children: [
              GlassHint(
                icon: filter.kind?.icon ?? CupertinoIcons.globe,
                title: about != null
                    ? 'Nobody\'s posted about $about yet'
                    : filter.kind != null
                        ? 'No ${filter.kind!.plural.toLowerCase()} yet'
                        : 'Nothing here yet',
                body: 'Start the conversation.',
              ),
              GlassPillButton(
                label: 'Write the first post',
                icon: CupertinoIcons.square_pencil,
                prominent: true,
                onTap: _compose,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        sliver: SliverList.separated(
          itemCount: feed.posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
          itemBuilder: (_, i) {
            final post = feed.posts[i];
            return ExplorePostCard(
              key: ValueKey(post.id),
              post: post,
              onOpen: () => _open(post),
              onSubjectTap: _filterBySubject,
              onMenu: () => showExplorePostMenu(context, ref, post,
                  onSubjectTap: _filterBySubject),
            );
          },
        ),
      ),
      if (feed.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.xl),
            child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
          ),
        ),
    ];
  }

  List<Widget> _searchSlivers() {
    if (_term.isEmpty) {
      final trending = ref.watch(trendingMoviesProvider).valueOrNull ?? [];
      final shows = ref.watch(trendingTvShowsProvider).valueOrNull ?? [];
      final mixed = <FilmModel>[
        for (var i = 0; i < 6; i++) ...[
          if (i < trending.length) trending[i],
          if (i < shows.length) shows[i],
        ],
      ];
      return [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.sm),
          sliver: SliverToBoxAdapter(
            child: GlassSectionLabel('Trending this week'),
          ),
        ),
        _resultList(mixed),
      ];
    }

    final results = ref.watch(searchMoviesProvider(_term));
    return results.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpace.xxl),
            child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
          ),
        ),
      ],
      error: (_, __) => const [
        SliverToBoxAdapter(
          child: GlassHint(
            icon: CupertinoIcons.wifi_exclamationmark,
            title: 'Couldn\'t search',
            body: 'Check your connection and try again.',
          ),
        ),
      ],
      data: (films) => films.isEmpty
          ? const [
              SliverToBoxAdapter(
                child: GlassHint(
                  icon: CupertinoIcons.search,
                  title: 'Nothing found',
                  body: 'Try a different spelling or the original title.',
                ),
              ),
            ]
          : [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.sm),
                sliver: SliverToBoxAdapter(
                  child: GlassSectionLabel('See what people are saying'),
                ),
              ),
              _resultList(films),
            ],
    );
  }

  Widget _resultList(List<FilmModel> films) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      sliver: SliverList.builder(
        itemCount: films.length,
        itemBuilder: (_, i) => MediaResultRow(
          film: films[i],
          onTap: () => _filterBySubject(ExploreSubject.fromFilm(films[i])),
        ),
      ),
    );
  }
}

/// [AppSearchField] with a focus node, so the screen can tell when search
/// starts. The shared field doesn't take one; wrapping keeps it untouched.
class _FocusableSearch extends StatelessWidget {
  const _FocusableSearch({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      // The field inside takes primary focus; this node reports it.
      canRequestFocus: false,
      skipTraversal: true,
      child: AppSearchField(
        controller: controller,
        onChanged: onChanged,
        placeholder: 'Search a film or show',
      ),
    );
  }
}

/// The title Explore is narrowed to: its artwork, name, post count, and the
/// two things you'd do next — post about it, or open it.
class _SubjectBanner extends ConsumerWidget {
  const _SubjectBanner({
    required this.subject,
    required this.onClear,
    required this.onPost,
  });

  final ExploreSubject subject;
  final VoidCallback onClear;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(exploreSubjectCountProvider(
        (filmId: subject.filmId, mediaType: subject.mediaType)));
    final n = count.valueOrNull;
    final wide = subject.wideUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.6,
          ),
        ),
        child: Stack(
          children: [
            if (wide.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: 22, sigmaY: 22, tileMode: TileMode.mirror),
                  child: CachedNetworkImage(
                    imageUrl: wide,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PillPortrait(
                        imageUrl: subject.posterUrl.isEmpty
                            ? null
                            : subject.posterUrl,
                        width: 56,
                        height: 84,
                        placeholderIcon: subject.isTv
                            ? CupertinoIcons.tv
                            : CupertinoIcons.film,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.title,
                              style: AppText.title.copyWith(
                                fontSize: 21,
                                height: 1.12,
                                color: AppColors.ink,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subject.caption,
                              style: AppText.caption.copyWith(
                                color: AppColors.ink.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              n == null
                                  ? ' '
                                  : '$n ${n == 1 ? 'post' : 'posts'}',
                              style: AppText.caption.copyWith(
                                color: AppColors.ink.withValues(alpha: 0.7),
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onClear,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(left: AppSpace.sm),
                          child: Icon(CupertinoIcons.xmark_circle_fill,
                              size: 24, color: AppColors.inkSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: GlassPillButton(
                          label: 'Post about this',
                          icon: CupertinoIcons.square_pencil,
                          prominent: true,
                          compact: true,
                          expand: true,
                          onTap: onPost,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: GlassPillButton(
                          label: subject.isTv ? 'View show' : 'View film',
                          icon: subject.isTv
                              ? CupertinoIcons.tv
                              : CupertinoIcons.film,
                          compact: true,
                          expand: true,
                          onTap: () => context.push(
                              '/film/${subject.filmId}/${subject.mediaType}'),
                        ),
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
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({this.tall = false});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );
    return Container(
      height: tall ? 220 : 150,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            bar(32, 32),
            const SizedBox(width: AppSpace.sm),
            bar(90, 12),
          ]),
          const SizedBox(height: AppSpace.lg),
          bar(double.infinity, 14),
          const SizedBox(height: AppSpace.sm),
          bar(220, 14),
        ],
      ),
    );
  }
}
