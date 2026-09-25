import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/lists/list_provider.dart';
import '../../lists/playlist_cover.dart';
import '../../lists/playlist_editor.dart';
import '../../lists/profile_watchlist_row.dart';
import '../../widgets/comments_sheet.dart' show GlassHint;
import '../../widgets/glass_panel.dart';

/// A profile's Lists tab: the watchlist pinned first, then playlists as a
/// grid of covers. On your own, "New playlist" is the first tile.
class ListsTab extends ConsumerWidget {
  const ListsTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  Future<void> _create(BuildContext context) async {
    final router = GoRouter.of(context);
    final result = await showPlaylistEditor(context);
    if (result is PlaylistSaved) router.push('/lists/${result.list.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider(userId));
    final lists = playlists.valueOrNull ?? const <PlaylistSummary>[];
    final tiles = lists.length + (isOwnProfile ? 1 : 0);

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),
        SliverToBoxAdapter(
          child: ProfileWatchlistRow(
            userId: userId,
            isOwnProfile: isOwnProfile,
          ),
        ),
        if (playlists.isLoading && lists.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.xl),
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
          )
        else if (tiles == 0)
          const SliverToBoxAdapter(
            child: GlassHint(
              icon: CupertinoIcons.rectangle_stack,
              title: 'No playlists',
              body: 'Nothing they\'ve shared with you yet.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.lg,
                crossAxisSpacing: AppSpace.md,
                // A square cover plus two lines under it.
                childAspectRatio: 0.78,
              ),
              itemCount: tiles,
              itemBuilder: (context, i) {
                if (isOwnProfile && i == 0) {
                  return _Tile(
                    cover: LayoutBuilder(
                      builder: (_, c) => Container(
                        width: c.maxWidth,
                        height: c.maxWidth,
                        decoration: glassWellDecoration(radius: 14),
                        child: const Icon(CupertinoIcons.plus,
                            size: 28, color: AppColors.inkSecondary),
                      ),
                    ),
                    title: 'New playlist',
                    muted: true,
                    onTap: () => _create(context),
                  );
                }
                final p = lists[isOwnProfile ? i - 1 : i];
                final n = p.list.itemCount;
                return _Tile(
                  cover: LayoutBuilder(
                    builder: (_, c) => PlaylistCover.of(p.list,
                        posters: p.posters, size: c.maxWidth, radius: 14),
                  ),
                  title: p.list.displayTitle,
                  subtitle: [
                    '$n title${n == 1 ? '' : 's'}',
                    if (isOwnProfile && p.list.visibility.name != 'public')
                      p.list.visibility.label,
                  ].join(' · '),
                  onTap: () => context.push('/lists/${p.list.id}'),
                );
              },
            ),
          ),
        // Other people's playlists you've saved. Only on your own profile:
        // what you save is yours to know.
        if (isOwnProfile) const _SavedPlaylists(),
      ],
    );
  }
}

class _SavedPlaylists extends ConsumerWidget {
  const _SavedPlaylists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlaylistsProvider).valueOrNull ?? const [];
    if (saved.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverMainAxisGroup(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.md),
          sliver: SliverToBoxAdapter(child: GlassSectionLabel('Saved')),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpace.lg,
              crossAxisSpacing: AppSpace.md,
              childAspectRatio: 0.78,
            ),
            itemCount: saved.length,
            itemBuilder: (context, i) {
              final p = saved[i];
              return _Tile(
                cover: LayoutBuilder(
                  builder: (_, c) => PlaylistCover.of(p.list,
                      posters: p.posters, size: c.maxWidth, radius: 14),
                ),
                title: p.list.displayTitle,
                subtitle: p.ownerUsername != null
                    ? 'by @${p.ownerUsername}'
                    : '${p.list.itemCount} titles',
                onTap: () => context.push('/lists/${p.list.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.cover,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.muted = false,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: cover),
          const SizedBox(height: AppSpace.sm),
          Text(
            title,
            style: AppText.label.copyWith(
              fontSize: 14,
              color: muted ? AppColors.inkSecondary : AppColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
