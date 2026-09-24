import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/explore_post_model.dart';
import '../../../providers/explore/explore_provider.dart';
import '../../explore/explore_composer.dart';
import '../../explore/explore_post_card.dart';
import '../../explore/explore_thread.dart';
import '../../widgets/comments_sheet.dart' show GlassHint;
import '../../widgets/glass_panel.dart';

/// Which kind a profile's Posts tab is narrowed to, per profile.
final _postsKindProvider =
    StateProvider.autoDispose.family<ExploreKind?, String>((ref, _) => null);

/// A profile's Posts tab: only their Explore posts (ADR 0001, D12). What
/// they've watched stays behind Recently watched, above the tabs.
class PostsTab extends ConsumerWidget {
  const PostsTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  /// Past this many, the kinds are worth filtering by.
  static const _filterAfter = 10;

  void _openSubject(BuildContext context, ExploreSubject s) =>
      context.push('/film/${s.filmId}/${s.mediaType}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(_postsKindProvider(userId));
    final key = (userId: userId, kind: kind);
    final feed = ref.watch(userExploreFeedProvider(key));
    final showChips = kind != null ||
        feed.posts.length > _filterAfter ||
        (feed.hasMore && feed.posts.length >= _filterAfter);

    final chips = SliverToBoxAdapter(
      child: SizedBox(
        height: 32 + AppSpace.md * 2,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.md),
          children: [
            GlassChip(
              label: 'All',
              selected: kind == null,
              onTap: () =>
                  ref.read(_postsKindProvider(userId).notifier).state = null,
            ),
            for (final k in ExploreKind.values) ...[
              const SizedBox(width: AppSpace.sm),
              GlassChip(
                label: k.plural,
                selected: kind == k,
                onTap: () => ref
                    .read(_postsKindProvider(userId).notifier)
                    .state = kind == k ? null : k,
              ),
            ],
          ],
        ),
      ),
    );

    final Widget body;
    if (feed.loading) {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xxl),
          child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
        ),
      );
    } else if (feed.error != null && feed.posts.isEmpty) {
      body = SliverToBoxAdapter(
        child: Column(
          children: [
            const GlassHint(
              icon: CupertinoIcons.wifi_exclamationmark,
              title: 'Couldn\'t load posts',
              body: 'Check your connection and try again.',
            ),
            GlassPillButton(
              label: 'Try again',
              icon: CupertinoIcons.arrow_clockwise,
              onTap: () =>
                  ref.read(userExploreFeedProvider(key).notifier).refresh(),
            ),
          ],
        ),
      );
    } else if (feed.posts.isEmpty) {
      body = SliverToBoxAdapter(
        child: Column(
          children: [
            GlassHint(
              icon: kind?.icon ?? CupertinoIcons.text_bubble,
              title: kind != null
                  ? 'No ${kind.plural.toLowerCase()} yet'
                  : 'No posts yet',
              body: isOwnProfile
                  ? 'What you post to Explore shows up here.'
                  : 'Their Explore posts will show up here.',
            ),
            if (isOwnProfile)
              GlassPillButton(
                label: 'Write a post',
                icon: CupertinoIcons.square_pencil,
                prominent: true,
                onTap: () => showExploreComposer(context,
                    kind: kind ?? ExploreKind.thought),
              ),
          ],
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        sliver: SliverList.separated(
          itemCount: feed.posts.length + (feed.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
          itemBuilder: (context, i) {
            if (i >= feed.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child:
                    CupertinoActivityIndicator(color: AppColors.inkSecondary),
              );
            }
            // Reaching the last card asks for the next page.
            if (i == feed.posts.length - 1 && feed.hasMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(userExploreFeedProvider(key).notifier).loadMore();
              });
            }
            final post = feed.posts[i];
            return ExplorePostCard(
              key: ValueKey(post.id),
              post: post,
              onOpen: () => showExploreThread(
                context,
                post,
                onSubjectTap: (s) => _openSubject(context, s),
              ),
              onSubjectTap: (s) => _openSubject(context, s),
              onMenu: () => showExplorePostMenu(context, ref, post),
            );
          },
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (showChips)
          chips
        else
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
        body,
      ],
    );
  }
}
