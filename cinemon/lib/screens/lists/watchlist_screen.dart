import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart' show userProfileProvider;
import '../../providers/lists/list_provider.dart';
import '../../providers/movie/movie_provider.dart';
import '../explore/explore_composer.dart' show showExploreComposer;
import '../widgets/glass_panel.dart';
import '../widgets/post_review_sheet.dart';

/// `/lists/:listId` for a watchlist (ADR 0001, Phase 3).
///
/// To watch, in the order they were added, then a collapsed "Watched"
/// section. The owner strikes titles off with the circle or a swipe right,
/// removes them with a swipe left, and picks who can see the list.
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listProvider(listId));
    final items = ref.watch(listItemsProvider(listId));
    final me = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Message(
          "Couldn't load this list.",
          onRetry: () => ref.invalidate(listProvider(listId)),
        ),
        data: (l) {
          // Hidden from you, or gone.
          if (l == null) return const _Message("This list isn't available.");
          return _ListBody(
            list: l,
            items: items,
            isOwner: l.userId == me,
          );
        },
      ),
    );
  }
}

class _ListBody extends ConsumerStatefulWidget {
  const _ListBody({
    required this.list,
    required this.items,
    required this.isOwner,
  });

  final FilmList list;
  final AsyncValue<List<ListItem>> items;
  final bool isOwner;

  @override
  ConsumerState<_ListBody> createState() => _ListBodyState();
}

class _ListBodyState extends ConsumerState<_ListBody> {
  bool _showWatched = false;

  /// Keys mid-strike: drawn struck through before the list reloads, so the
  /// line has a moment to land.
  final _striking = <String>{};

  Future<void> _strike(ListItem item) async {
    HapticFeedback.mediumImpact();
    setState(() => _striking.add(item.key));
    await Future<void>.delayed(const Duration(milliseconds: 380));
    final ok = await ref
        .read(watchlistActionsProvider)
        .setWatched(item, watched: true);
    if (!mounted) return;
    setState(() => _striking.remove(item.key));
    if (!ok) {
      showGlassToast(context, "Couldn't update your watchlist.",
          destructive: true);
      return;
    }
    await _showWatchedPrompt(context, ref, item);
  }

  Future<void> _unstrike(ListItem item) async {
    final ok = await ref
        .read(watchlistActionsProvider)
        .setWatched(item, watched: false);
    if (!ok && mounted) {
      showGlassToast(context, "Couldn't update your watchlist.",
          destructive: true);
    }
  }

  Future<void> _remove(ListItem item) async {
    final ok = await ref.read(watchlistActionsProvider).remove(item);
    if (!mounted) return;
    showGlassToast(
      context,
      ok ? 'Removed ${item.title}' : "Couldn't remove that.",
      destructive: !ok,
      icon: ok ? CupertinoIcons.bookmark : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final owner = ref.watch(userProfileProvider(list.userId)).valueOrNull;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          actions: [
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.md),
                child: GlassPillButton(
                  label: list.visibility.label,
                  icon: _visibilityIcon(list.visibility),
                  compact: true,
                  onTap: () => _pickVisibility(context, ref, list),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(list.displayTitle,
                    style: AppText.title.copyWith(fontSize: 30)),
                if (!widget.isOwner && owner != null)
                  Text('@${owner.username}',
                      style: AppText.footnote
                          .copyWith(color: AppColors.inkSecondary)),
              ],
            ),
          ),
        ),
        ...widget.items.when(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (_, __) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                "Couldn't load this list.",
                onRetry: () => ref.invalidate(listItemsProvider(list.id)),
              ),
            ),
          ],
          data: _itemSlivers,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  List<Widget> _itemSlivers(List<ListItem> items) {
    final toWatch = items.where((i) => !i.watched).toList().reversed.toList();
    final watched = items.where((i) => i.watched).toList()
      ..sort((a, b) => b.watchedAt!.compareTo(a.watchedAt!));

    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(widget.isOwner
              ? 'Nothing to watch yet.\nTap the bookmark on any film or show '
                  'to save it here.'
              : 'Nothing on this watchlist yet.'),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpace.sm),
          child: GlassSectionLabel(
              '${toWatch.length} to watch'),
        ),
      ),
      SliverList.builder(
        itemCount: toWatch.length,
        itemBuilder: (_, i) {
          final item = toWatch[i];
          final row = _ItemRow(
            item: item,
            struck: _striking.contains(item.key),
            onCircle: widget.isOwner ? () => _strike(item) : null,
          );
          if (!widget.isOwner) return row;
          return _Swipeable(
            key: ValueKey(item.key),
            onStrike: () => _strike(item),
            onRemove: () => _remove(item),
            child: row,
          );
        },
      ),
      if (watched.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: GlassPressable(
            onTap: () => setState(() => _showWatched = !_showWatched),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, AppSpace.xl, 20, AppSpace.sm),
              child: GlassSectionLabel(
                'Watched (${watched.length})',
                trailing: Icon(
                  _showWatched
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.inkTertiary,
                ),
              ),
            ),
          ),
        ),
        if (_showWatched)
          SliverList.builder(
            itemCount: watched.length,
            itemBuilder: (_, i) {
              final item = watched[i];
              final row = _ItemRow(
                item: item,
                struck: true,
                onCircle: widget.isOwner ? () => _unstrike(item) : null,
              );
              if (!widget.isOwner) return row;
              return _Swipeable(
                key: ValueKey('w:${item.key}'),
                onRemove: () => _remove(item),
                child: row,
              );
            },
          ),
      ],
    ];
  }
}

/// Swipe right to strike off (the row stays put; the list reloads with it
/// moved), swipe left to remove.
class _Swipeable extends StatelessWidget {
  const _Swipeable({
    super.key,
    required this.child,
    required this.onRemove,
    this.onStrike,
  });

  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback? onStrike;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: onStrike == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onStrike?.call();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onRemove(),
      background: const _SwipeBackground(
        icon: CupertinoIcons.checkmark_alt,
        label: 'Watched',
        color: Color(0xFF30D158),
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBackground(
        icon: CupertinoIcons.trash,
        label: 'Remove',
        color: AppColors.destructive,
        alignment: Alignment.centerRight,
      ),
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.22),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpace.sm),
          Text(label, style: AppText.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.struck, this.onCircle});

  final ListItem item;
  final bool struck;

  /// Null for someone else's list: no circle.
  final VoidCallback? onCircle;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getPosterUrl(item.posterPath, size: '/w154');
    final meta = [
      if (item.year != null) item.year!,
      item.isTv ? 'Show' : 'Film',
    ].join(' · ');

    return GlassPressable(
      onTap: () => context.push('/film/${item.filmId}/${item.mediaType}'),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: struck ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 46,
                  height: 69,
                  child: url.isEmpty
                      ? const ColoredBox(color: AppColors.surface)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppColors.surface),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: AppColors.surface),
                        ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        decoration: struck
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.ink,
                        decorationThickness: 2,
                      ),
                      child: Text(item.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 2),
                    Text(meta,
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkTertiary)),
                  ],
                ),
              ),
              if (onCircle != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCircle,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.sm),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        struck
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        key: ValueKey(struck),
                        size: 26,
                        color: struck
                            ? const Color(0xFF30D158)
                            : AppColors.inkTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Straight after striking a title off: log it, post about it, or not.
Future<void> _showWatchedPrompt(
  BuildContext context,
  WidgetRef ref,
  ListItem item,
) async {
  final choice = await showGlassPanel<String>(
    context,
    builder: (panelContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill,
              size: 34, color: Color(0xFF30D158)),
          const SizedBox(height: AppSpace.md),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'You watched '),
              TextSpan(
                text: item.title,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ]),
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Want to log it while it\'s fresh?',
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xl),
          GlassPillButton(
            label: 'Log or review it',
            icon: CupertinoIcons.star,
            prominent: true,
            expand: true,
            onTap: () => Navigator.of(panelContext).pop('log'),
          ),
          const SizedBox(height: AppSpace.sm),
          GlassPillButton(
            label: 'Post to Explore',
            icon: CupertinoIcons.globe,
            expand: true,
            onTap: () => Navigator.of(panelContext).pop('explore'),
          ),
          const SizedBox(height: AppSpace.sm),
          GlassPillButton(
            label: 'Not now',
            expand: true,
            onTap: () => Navigator.of(panelContext).pop(),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'explore') {
    await showExploreComposer(
      context,
      subject: ExploreSubject(
        filmId: item.filmId,
        mediaType: item.mediaType,
        title: item.title,
        posterPath: item.posterPath,
        backdropPath: item.backdropPath,
        year: item.year,
      ),
      kind: ExploreKind.review,
    );
    return;
  }

  // The post flow wants the full film (runtime, seasons); the snapshot on the
  // list item is only enough to fall back on.
  FilmModel film;
  try {
    film = await ref.read(filmDetailsProvider((
      id: item.filmId,
      mediaType: item.isTv ? MediaType.tv : MediaType.movie,
    )).future);
  } catch (_) {
    film = FilmModel(
      id: item.filmId,
      title: item.isTv ? null : item.title,
      name: item.isTv ? item.title : null,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      mediaType: item.isTv ? MediaType.tv : MediaType.movie,
    );
  }
  if (!context.mounted) return;
  await showPostReviewSheet(context, film);
}

Future<void> _pickVisibility(
  BuildContext context,
  WidgetRef ref,
  FilmList list,
) async {
  final picked = await showGlassPanel<ListVisibility>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassPanelHeader(
          title: 'Who can see it',
          subtitle: 'Your watchlist',
        ),
        for (final v in ListVisibility.values) ...[
          if (v.index > 0) const GlassMenuDivider(),
          GlassMenuRow(
            icon: _visibilityIcon(v),
            title: v.label,
            subtitle: v.detail,
            trailing: v == list.visibility
                ? const Icon(CupertinoIcons.checkmark_alt,
                    size: 18, color: AppColors.ink)
                : null,
            onTap: () => Navigator.of(panelContext).pop(v),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
      ],
    ),
  );
  if (picked == null || picked == list.visibility || !context.mounted) return;
  final ok =
      await ref.read(watchlistActionsProvider).setVisibility(list, picked);
  if (!context.mounted) return;
  showGlassToast(
    context,
    ok ? 'Visible to: ${picked.label}' : "Couldn't change that.",
    destructive: !ok,
  );
}

IconData _visibilityIcon(ListVisibility v) => switch (v) {
      ListVisibility.public => CupertinoIcons.globe,
      ListVisibility.friends => CupertinoIcons.person_2,
      ListVisibility.private => CupertinoIcons.lock,
    };

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.md),
              GlassPillButton(
                  label: 'Try again', compact: true, onTap: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
