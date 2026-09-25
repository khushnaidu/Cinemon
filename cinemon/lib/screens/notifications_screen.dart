import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'widgets/glass_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import '../models/sticker_model.dart';
import '../providers/follow/follow_provider.dart';
import '../providers/explore/explore_provider.dart'
    show exploreRepositoryProvider;
import '../providers/feed/feed_provider.dart' show feedRepositoryProvider;
import '../providers/notification/notification_provider.dart';
import 'explore/explore_thread.dart' show showExploreThread;
import 'widgets/comments_sheet.dart' show GlassHint, showCommentsSheet;
import 'follow_list_screen.dart'
    show
        FollowRequestsBanner,
        PersonAvatar,
        PersonFollowButton,
        showFollowRequestsPanel;

/// Activity/Notifications screen - Instagram-style activity feed
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

/// The Activity filter chips.
enum _ActivityFilter {
  all('All', {}),
  likes('Likes', {NotificationType.like, NotificationType.reaction}),
  comments('Comments', {
    NotificationType.comment,
    NotificationType.exploreComment,
    NotificationType.exploreReply,
  }),
  votes('Votes', {NotificationType.vote}),
  saves('Saves', {NotificationType.listSave}),
  follows('Follows', {
    NotificationType.follow,
    NotificationType.followRequest,
    NotificationType.followAccepted,
  });

  const _ActivityFilter(this.label, this.types);

  final String label;
  final Set<NotificationType> types;

  bool matches(NotificationModel n) => types.isEmpty || types.contains(n.type);
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationNotifierProvider.notifier).markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final requests = ref.watch(followRequestCountProvider).valueOrNull ?? 0;

    final header = Padding(
      padding:
          const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xs, AppSpace.lg, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(CupertinoIcons.chevron_back, color: AppColors.ink),
            tooltip: 'Back',
          ),
          const Expanded(child: Text('Activity', style: AppText.title)),
          if (notificationsAsync.valueOrNull?.isNotEmpty ?? false)
            GlassPillButton(
              label: 'Clear',
              compact: true,
              onTap: _showClearConfirmation,
            ),
        ],
      ),
    );

    final chips = SizedBox(
      height: 32 + AppSpace.md * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        children: [
          for (final f in _ActivityFilter.values) ...[
            if (f != _ActivityFilter.all) const SizedBox(width: AppSpace.sm),
            GlassChip(
              label: f.label,
              selected: _filter == f,
              onTap: () => setState(() => _filter = f),
            ),
          ],
        ],
      ),
    );

    final Widget body = notificationsAsync.when(
      loading: () => const Center(
        child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
      ),
      error: (_, __) => const GlassHint(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'Couldn\'t load activity',
        body: 'Check your connection and try again.',
      ),
      data: (all) {
        final notifications = all.where(_filter.matches).toList();
        // Requests to follow your private account sit above everything.
        final lead = requests > 0 &&
                (_filter == _ActivityFilter.all ||
                    _filter == _ActivityFilter.follows)
            ? 1
            : 0;
        if (notifications.isEmpty && lead == 0) {
          return _filter == _ActivityFilter.all
              ? const GlassHint(
                  icon: CupertinoIcons.bell,
                  title: 'No activity yet',
                  body: 'When people follow you or interact with your posts, '
                      'you\'ll see it here.',
                )
              : GlassHint(
                  icon: CupertinoIcons.line_horizontal_3_decrease,
                  title: 'No ${_filter.label.toLowerCase()} yet',
                  body: '',
                );
        }

        // Grouped the way iOS lists time: today, this week, earlier.
        final rows = <Object>[];
        String? section;
        for (final n in notifications) {
          final s = _sectionFor(n.createdAt);
          if (s != section) {
            rows.add(s);
            section = s;
          }
          rows.add(n);
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsStreamProvider),
          color: AppColors.ink,
          backgroundColor: AppColors.surfaceElevated,
          child: ListView.builder(
            padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + AppSpace.lg),
            itemCount: rows.length + lead,
            itemBuilder: (context, index) {
              if (index < lead) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
                  child: FollowRequestsBanner(count: requests),
                );
              }
              final row = rows[index - lead];
              if (row is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
                  child: Text(row, style: AppText.headline),
                );
              }
              final n = row as NotificationModel;
              return _NotificationTile(
                notification: n,
                onTap: () => _handleNotificationTap(n),
                onDismiss: () => _handleDismiss(n),
              );
            },
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            header,
            chips,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  static String _sectionFor(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = at.toLocal();
    if (!local.isBefore(today)) return 'Today';
    if (today.difference(local).inDays < 7) return 'This week';
    return 'Earlier';
  }

  /// A notification opens what it's about; its avatar opens who did it.
  Future<void> _handleNotificationTap(NotificationModel n) async {
    switch (n.type) {
      case NotificationType.personNewCredit:
        if (n.filmId != null) {
          context.push('/film/${n.filmId}/${n.mediaType ?? 'movie'}');
        }
      case NotificationType.followRequest:
        showFollowRequestsPanel(context);
      case NotificationType.follow || NotificationType.followAccepted:
        context.push('/profile/${n.actorId}');
      case NotificationType.listSave:
        if (n.listId != null) context.push('/lists/${n.listId}');
      case NotificationType.vote ||
            NotificationType.exploreComment ||
            NotificationType.exploreReply:
        final id = n.explorePostId;
        if (id == null) return;
        final post = await ref.read(exploreRepositoryProvider).getPost(id);
        if (!mounted) return;
        if (post == null) return _gone();
        showExploreThread(context, post);
      case NotificationType.like ||
            NotificationType.reaction ||
            NotificationType.comment:
        final id = n.activityId;
        if (id == null) return;
        final activity = await ref.read(feedRepositoryProvider).getActivity(id);
        if (!mounted) return;
        if (activity == null) return _gone();
        if (n.type == NotificationType.comment) {
          // Straight to the conversation.
          showCommentsSheet(
            context,
            activityId: activity.id,
            filmTitle: activity.displayTitle,
            activityOwnerId: activity.userId,
            filmPosterPath: activity.filmPosterPath,
          );
        } else {
          final type =
              activity.mediaType.isNotEmpty ? activity.mediaType : 'movie';
          context.push('/film/${activity.filmId}/$type', extra: activity);
        }
    }
  }

  void _gone() => showGlassToast(context, 'That\'s been deleted.',
      icon: CupertinoIcons.trash);

  void _handleDismiss(NotificationModel notification) {
    ref
        .read(notificationNotifierProvider.notifier)
        .deleteNotification(notification.id);
  }

  Future<void> _showClearConfirmation() async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Clear all activity?',
      message: 'This removes every notification. It can\'t be undone.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    ref.read(notificationNotifierProvider.notifier).clearAllNotifications();
  }
}

/// One row of Activity: who, what, when, and on the right what it's about
/// or, for follows, what you can do back.
class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  bool get _isCredit => notification.type == NotificationType.personNewCredit;

  /// The actor's photo, or for new work the person's portrait.
  String? get _avatarUrl {
    if (!_isCredit) return notification.actorPhotoUrl;
    final url = ApiConstants.getProfileUrl(notification.personProfilePath);
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final name =
        _isCredit ? (n.personName ?? 'Someone you follow') : n.actorUsername;

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.xl),
        color: AppColors.destructive.withValues(alpha: 0.85),
        child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
      ),
      child: GlassPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.sm + 2),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push(_isCredit
                    ? '/person/${n.personId}'
                    : '/profile/${n.actorId}'),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PersonAvatar(photoUrl: _avatarUrl),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _TypeBadge(notification: n),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: AppText.body.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' ${n.message} '),
                          TextSpan(
                            text: n.relativeTime,
                            style:
                                const TextStyle(color: AppColors.inkTertiary),
                          ),
                        ],
                      ),
                      style:
                          AppText.body.copyWith(color: AppColors.inkSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (n.commentPreview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _isCredit ? n.commentPreview! : '“${n.commentPreview}”',
                        style: AppText.caption
                            .copyWith(color: AppColors.inkTertiary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              _Trailing(notification: n),
              if (!n.isRead) ...[
                const SizedBox(width: AppSpace.sm),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small glyph on the avatar's corner: what kind of thing happened.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (notification.type) {
      NotificationType.like => (
          CupertinoIcons.heart_fill,
          AppColors.destructive
        ),
      NotificationType.reaction => (CupertinoIcons.smiley_fill, AppColors.gold),
      NotificationType.comment ||
      NotificationType.exploreComment ||
      NotificationType.exploreReply =>
        (CupertinoIcons.chat_bubble_fill, AppColors.info),
      NotificationType.vote => notification.vote == -1
          ? (CupertinoIcons.hand_thumbsdown_fill, AppColors.destructive)
          : (CupertinoIcons.hand_thumbsup_fill, AppColors.success),
      NotificationType.listSave => (
          CupertinoIcons.bookmark_fill,
          AppColors.gold
        ),
      NotificationType.follow || NotificationType.followRequest => (
          CupertinoIcons.person_add_solid,
          AppColors.info
        ),
      NotificationType.followAccepted => (
          CupertinoIcons.checkmark_alt,
          AppColors.success
        ),
      NotificationType.personNewCredit => (
          CupertinoIcons.film_fill,
          AppColors.info
        ),
    };
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.canvas, width: 2),
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}

/// What sits on the right: follow actions for follows, the sticker for a
/// reaction, otherwise the poster of what it's about.
class _Trailing extends ConsumerWidget {
  const _Trailing({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final actor = n.actorId;

    switch (n.type) {
      case NotificationType.followRequest when actor != null:
        // The row only exists while the request is waiting (migration 017
        // turns it into a follow, or deletes it).
        final actions = ref.read(followActionsProvider);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassPillButton(
              label: 'Confirm',
              prominent: true,
              compact: true,
              onTap: () => actions.accept(actor),
            ),
            const SizedBox(width: AppSpace.xs),
            GlassPillButton(
              label: 'Delete',
              compact: true,
              onTap: () => actions.removeFollower(actor),
            ),
          ],
        );
      case NotificationType.follow || NotificationType.followAccepted
          when actor != null:
        return PersonFollowButton(userId: actor, username: n.actorUsername);
      default:
        break;
    }

    if (n.type == NotificationType.reaction && n.stickerId != null) {
      final sticker = StickerRegistry.getStickerById(n.stickerId!);
      if (sticker != null) {
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            sticker.assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Text(sticker.emoji, style: const TextStyle(fontSize: 28)),
          ),
        );
      }
    }

    if (n.filmPosterPath != null) {
      final posterUrl = ApiConstants.getPosterUrl(
        n.filmPosterPath,
        size: ApiConstants.posterSizeSmall,
      );
      const placeholder = ColoredBox(color: AppColors.surfaceElevated);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: posterUrl,
          width: 38,
          height: 54,
          fit: BoxFit.cover,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
