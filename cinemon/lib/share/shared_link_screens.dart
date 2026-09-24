import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/explore_post_model.dart';
import '../providers/explore/explore_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../screens/explore/explore_post_card.dart';
import '../screens/explore/explore_thread.dart';

/// Where share links land (ADR 0003, Phase 4). A story's link sticker opens
/// `35mm.contact/p/<id>` or `/u/<username>`; with the app installed iOS
/// hands the path to the router, which brings it here.

final _sharedPostProvider =
    FutureProvider.autoDispose.family<ExplorePost?, String>((ref, id) {
  return ref.watch(exploreRepositoryProvider).getPost(id);
});

/// `/p/<id>`: one Explore post, full size, with its thread a tap away.
class SharedPostScreen extends ConsumerWidget {
  const SharedPostScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(_sharedPostProvider(postId));
    return _Frame(
      child: post.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => const _Missing(
            "Couldn't load this post. Check your connection and try again."),
        data: (p) => p == null
            ? const _Missing(
                "This post isn't available. It may have been deleted.")
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: ExplorePostCard(
                  post: p,
                  expanded: true,
                  onOpen: () => showExploreThread(context, p),
                  onSubjectTap: (s) =>
                      context.push('/film/${s.filmId}/${s.mediaType}'),
                  onMenu: () => showExplorePostMenu(context, ref, p),
                ),
              ),
      ),
    );
  }
}

final _userIdByNameProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, name) async {
  final user = await ref.watch(userRepositoryProvider).getUserByUsername(name);
  return user?.uid;
});

/// `/u/<username>`: looks the name up, then shows that profile.
class SharedProfileScreen extends ConsumerWidget {
  const SharedProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(_userIdByNameProvider(username), (_, next) {
      final id = next.valueOrNull;
      if (id != null) context.pushReplacement('/profile/$id');
    });
    final lookup = ref.watch(_userIdByNameProvider(username));
    return _Frame(
      child: lookup.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => const _Missing(
            "Couldn't load this profile. Check your connection and try again."),
        data: (id) => id == null
            ? _Missing('There’s no one called @$username on 35mm.')
            : const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, color: AppColors.ink),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.inkSecondary),
        ),
      ),
    );
  }
}
