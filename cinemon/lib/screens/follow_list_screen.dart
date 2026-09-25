import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/feed/feed_provider.dart' show userProfileProvider;
import '../providers/follow/follow_provider.dart';
import 'widgets/app_search_field.dart';
import 'widgets/comments_sheet.dart' show GlassHint;
import 'widgets/glass_panel.dart';

/// Followers and Following (ADR 0004 D2), yours or anyone's you can see.
///
/// On your own: the follow requests waiting on you sit at the top, you can
/// remove a follower, and unfollow from the Following side. On someone
/// else's, rows just open profiles.
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    this.userId,
    this.initial = FollowListKind.following,
  });

  /// Whose lists; yours when null.
  final String? userId;
  final FollowListKind initial;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  late FollowListKind _kind = widget.initial;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id;
    final userId = widget.userId ?? me;
    if (userId == null) return const SizedBox.shrink();
    final own = userId == me;
    final owner =
        own ? null : ref.watch(userProfileProvider(userId)).valueOrNull;
    final list = ref.watch(followListProvider((userId: userId, kind: _kind)));
    final requests = own
        ? (ref.watch(followRequestsProvider).valueOrNull ?? const [])
        : const <FollowRequest>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xs, AppSpace.xs, AppSpace.lg, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(CupertinoIcons.chevron_back,
                        color: AppColors.ink),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      own ? 'People' : '@${owner?.username ?? ''}',
                      style: AppText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (own)
                    GlassPillButton(
                      label: 'Find people',
                      icon: CupertinoIcons.person_add,
                      compact: true,
                      onTap: () => context.push('/search-users'),
                    ),
                ],
              ),
            ),
            if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: FollowRequestsBanner(count: requests.length),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: GlassSegmentedControl(
                labels: const ['Followers', 'Following'],
                index: _kind == FollowListKind.followers ? 0 : 1,
                onChanged: (i) => setState(() => _kind = i == 0
                    ? FollowListKind.followers
                    : FollowListKind.following),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: AppSearchField(
                controller: _search,
                placeholder: 'Search',
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: list.when(
                loading: () => const Center(
                  child:
                      CupertinoActivityIndicator(color: AppColors.inkSecondary),
                ),
                error: (_, __) => GlassHint(
                  icon: CupertinoIcons.wifi_exclamationmark,
                  title: 'Couldn\'t load this list',
                  body: 'Check your connection and try again.',
                ),
                data: (users) {
                  final shown = _query.isEmpty
                      ? users
                      : users
                          .where((u) =>
                              u.username.toLowerCase().contains(_query) ||
                              (u.displayName ?? '')
                                  .toLowerCase()
                                  .contains(_query))
                          .toList();
                  if (shown.isEmpty) {
                    return GlassHint(
                      icon: CupertinoIcons.person_2,
                      title: _query.isNotEmpty
                          ? 'No one matches'
                          : _kind == FollowListKind.followers
                              ? 'No followers yet'
                              : 'Not following anyone yet',
                      body: own && _query.isEmpty
                          ? 'Find people you know with Find people.'
                          : '',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(followListProvider),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm,
                          AppSpace.lg, MediaQuery.of(context).padding.bottom),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpace.xs),
                      itemBuilder: (_, i) => _PersonRow(
                        user: shown[i],
                        trailing: own
                            ? _OwnListAction(user: shown[i], kind: _kind)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.user, this.trailing});

  final UserModel user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => context.push('/profile/${user.uid}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            PersonAvatar(photoUrl: user.photoUrl),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: AppText.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((user.displayName ?? '').isNotEmpty &&
                      user.displayName != user.username)
                    Text(
                      user.displayName!,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// On your own lists: Remove a follower, or Following (tap to unfollow).
class _OwnListAction extends ConsumerWidget {
  const _OwnListAction({required this.user, required this.kind});

  final UserModel user;
  final FollowListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(followActionsProvider);
    if (kind == FollowListKind.followers) {
      return GlassPillButton(
        label: 'Remove',
        compact: true,
        onTap: () async {
          final ok = await showGlassConfirm(
            context,
            title: 'Remove @${user.username}?',
            message: 'They won\'t be told. If your account is private, '
                'they\'ll have to ask again to see your posts.',
            confirmLabel: 'Remove',
            destructive: true,
          );
          if (ok) await actions.removeFollower(user.uid);
        },
      );
    }
    return GlassPillButton(
      label: 'Following',
      compact: true,
      onTap: () async {
        final ok = await confirmUnfollow(context, user.username);
        if (ok) await actions.unfollow(user.uid);
      },
    );
  }
}

Future<bool> confirmUnfollow(BuildContext context, String username) =>
    showGlassConfirm(
      context,
      title: 'Unfollow @$username?',
      message: 'Their posts will leave your Home. If their account is '
          'private, you\'ll have to ask again to see them.',
      confirmLabel: 'Unfollow',
      destructive: true,
    );

/// A round avatar with the person glyph when there's no photo.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, this.photoUrl, this.size = 44});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl ?? '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceElevated,
      backgroundImage: url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: url.isEmpty
          ? Icon(CupertinoIcons.person_fill,
              size: size * 0.5, color: AppColors.inkTertiary)
          : null,
    );
  }
}

/// "Follow requests (n)": the way into approving them, at the top of People
/// and of Notifications.
class FollowRequestsBanner extends StatelessWidget {
  const FollowRequestsBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => showFollowRequestsPanel(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        decoration: glassWellDecoration(),
        child: Row(
          children: [
            const Icon(CupertinoIcons.person_badge_plus,
                color: AppColors.ink, size: 22),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text('Follow requests', style: AppText.headline),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.destructive,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: AppText.caption
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

/// The people asking to follow your private account: Confirm or Delete.
Future<void> showFollowRequestsPanel(BuildContext context) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (panelContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanelHeader(
          title: 'Follow requests',
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(panelContext).pop(),
        ),
        const Expanded(child: _RequestList()),
      ],
    ),
  );
}

class _RequestList extends ConsumerWidget {
  const _RequestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(followRequestsProvider);
    return requests.when(
      loading: () => const Center(
        child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
      ),
      error: (_, __) => const GlassHint(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'Couldn\'t load requests',
        body: 'Check your connection and try again.',
      ),
      data: (list) {
        if (list.isEmpty) {
          return const GlassHint(
            icon: CupertinoIcons.person_badge_plus,
            title: 'No requests',
            body: 'When someone asks to follow your private account, '
                'they\'ll show up here.',
          );
        }
        final actions = ref.read(followActionsProvider);
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpace.lg),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
          itemBuilder: (_, i) {
            final r = list[i];
            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/profile/${r.followerId}');
                  },
                  child: PersonAvatar(photoUrl: r.photoUrl),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(r.username,
                      style: AppText.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                GlassPillButton(
                  label: 'Confirm',
                  prominent: true,
                  compact: true,
                  onTap: () => actions.accept(r.followerId),
                ),
                const SizedBox(width: AppSpace.sm),
                GlassPillButton(
                  label: 'Delete',
                  compact: true,
                  onTap: () => actions.removeFollower(r.followerId),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
