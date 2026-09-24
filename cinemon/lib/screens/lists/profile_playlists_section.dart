import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';
import 'playlist_cover.dart';
import 'playlist_editor.dart';

/// A rail of someone's playlists on their profile, until Phase 5 gives lists
/// their own tab. On your own profile it always shows, with a New tile; on
/// anyone else's it only shows if there's something you're allowed to see.
class ProfilePlaylistsSection extends ConsumerWidget {
  const ProfilePlaylistsSection({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  static const _tile = 112.0;

  Future<void> _create(BuildContext context) async {
    final router = GoRouter.of(context);
    final result = await showPlaylistEditor(context);
    if (result is PlaylistSaved) router.push('/lists/${result.list.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider(userId)).valueOrNull;
    if (playlists == null) return const SizedBox.shrink();
    if (playlists.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Playlists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isOwnProfile)
                  GlassPillButton(
                    label: 'New',
                    icon: CupertinoIcons.plus,
                    compact: true,
                    onTap: () => _create(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: _tile + AppSpace.sm + 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              clipBehavior: Clip.none,
              itemCount: playlists.isEmpty ? 1 : playlists.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
              itemBuilder: (_, i) {
                if (playlists.isEmpty) {
                  return GlassPressable(
                    onTap: () => _create(context),
                    child: SizedBox(
                      width: _tile,
                      child: Column(
                        children: [
                          Container(
                            width: _tile,
                            height: _tile,
                            decoration: glassWellDecoration(radius: 11),
                            child: const Icon(CupertinoIcons.plus,
                                color: AppColors.inkSecondary),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text('New playlist',
                              style: AppText.footnote
                                  .copyWith(color: AppColors.inkSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                final p = playlists[i];
                return GlassPressable(
                  onTap: () => context.push('/lists/${p.list.id}'),
                  child: SizedBox(
                    width: _tile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PlaylistCover(posters: p.posters, size: _tile),
                        const SizedBox(height: AppSpace.sm),
                        Text(p.list.displayTitle,
                            style: AppText.footnote
                                .copyWith(color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${p.list.itemCount} title${p.list.itemCount == 1 ? '' : 's'}',
                          style: AppText.footnote.copyWith(
                              color: AppColors.inkTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
