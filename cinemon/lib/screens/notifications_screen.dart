import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'widgets/glass_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import '../models/sticker_model.dart';
import '../providers/follow/follow_provider.dart'
    show followRequestCountProvider;
import '../providers/explore/explore_provider.dart'
    show exploreRepositoryProvider;
import '../providers/feed/feed_provider.dart' show feedRepositoryProvider;
import '../providers/notification/notification_provider.dart';
import 'explore/explore_thread.dart' show showExploreThread;
import 'widgets/comments_sheet.dart' show showCommentsSheet;
import 'follow_list_screen.dart'
    show FollowRequestsBanner, showFollowRequestsPanel;

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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'clear') {
                _showClearConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Clear all',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              AppColors.canvas,
            ],
          ),
        ),
        child: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Could not load activity',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          data: (all) {
            final notifications = all.where(_filter.matches).toList();
            // Requests to follow your private account sit above everything.
            final requests =
                ref.watch(followRequestCountProvider).valueOrNull ?? 0;
            final lead = requests > 0 &&
                    (_filter == _ActivityFilter.all ||
                        _filter == _ActivityFilter.follows)
                ? 1
                : 0;
            final chips = SizedBox(
              height: 32 + AppSpace.md * 2,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg, vertical: AppSpace.md),
                children: [
                  for (final f in _ActivityFilter.values) ...[
                    if (f != _ActivityFilter.all)
                      const SizedBox(width: AppSpace.sm),
                    GlassChip(
                      label: f.label,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                  ],
                ],
              ),
            );
            if (notifications.isEmpty && lead == 0) {
              return Column(
                children: [
                  chips,
                  Expanded(
                    child: _filter == _ActivityFilter.all
                        ? _buildEmptyState()
                        : Center(
                            child: Text(
                              'No ${_filter.label.toLowerCase()} yet',
                              style: AppText.body
                                  .copyWith(color: AppColors.inkSecondary),
                            ),
                          ),
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsStreamProvider);
              },
              color: Colors.white,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: notifications.length + lead + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return chips;
                  index -= 1;
                  if (index < lead) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
                      child: FollowRequestsBanner(count: requests),
                    );
                  }
                  final n = notifications[index - lead];
                  return _NotificationTile(
                    notification: n,
                    onTap: () => _handleNotificationTap(n),
                    onDismiss: () => _handleDismiss(n),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 24),
          Text(
            'No activity yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'When people interact with your posts,\nyou\'ll see it here.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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

/// Individual notification tile
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.3),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : Colors.white.withOpacity(0.05),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actor avatar
              GestureDetector(
                onTap: () => context.push(_isCredit
                    ? '/person/${notification.personId}'
                    : '/profile/${notification.actorId}'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: _avatarUrl != null
                      ? CachedNetworkImageProvider(_avatarUrl!)
                      : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: _isCredit
                                ? (notification.personName ??
                                    'Someone you follow')
                                : notification.actorUsername,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' ${notification.message}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    // Comment preview, or for new work the role in it.
                    if (notification.commentPreview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _isCredit
                            ? notification.commentPreview!
                            : '"${notification.commentPreview}"',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 4),
                    Text(
                      notification.relativeTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Trailing icon/image
              _buildTrailing(),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isCredit => notification.type == NotificationType.personNewCredit;

  /// The actor's photo, or for new work the person's portrait.
  String? get _avatarUrl {
    if (!_isCredit) return notification.actorPhotoUrl;
    final url = ApiConstants.getProfileUrl(notification.personProfilePath);
    return url.isEmpty ? null : url;
  }

  Widget _buildTrailing() {
    // Show sticker for reaction notifications
    if (notification.type == NotificationType.reaction &&
        notification.stickerId != null) {
      final sticker = StickerRegistry.getStickerById(notification.stickerId!);
      if (sticker != null) {
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            sticker.assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Text(
              sticker.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        );
      }
    }

    // Show film poster for activity notifications
    if (notification.filmPosterPath != null) {
      final posterUrl = ApiConstants.getPosterUrl(
        notification.filmPosterPath,
        size: ApiConstants.posterSizeSmall,
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: posterUrl,
          width: 40,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 40,
            height: 56,
            color: Colors.grey[800],
          ),
          errorWidget: (context, url, error) => Container(
            width: 40,
            height: 56,
            color: Colors.grey[800],
            child: const Icon(Icons.movie, color: Colors.white24, size: 20),
          ),
        ),
      );
    }

    // Show icon based on notification type
    IconData icon;
    Color color;
    switch (notification.type) {
      case NotificationType.like:
        icon = Icons.favorite;
        color = AppColors.destructive;
        break;
      case NotificationType.comment:
        icon = Icons.chat_bubble;
        color = AppColors.info;
        break;
      case NotificationType.reaction:
        icon = Icons.add_reaction;
        color = AppColors.gold;
        break;
      case NotificationType.follow:
        icon = Icons.person_add_alt_1;
        color = AppColors.info;
        break;
      case NotificationType.vote:
        icon = notification.vote == -1 ? Icons.thumb_down : Icons.thumb_up;
        color =
            notification.vote == -1 ? AppColors.destructive : AppColors.success;
        break;
      case NotificationType.exploreComment:
      case NotificationType.exploreReply:
        icon = Icons.forum;
        color = AppColors.info;
        break;
      case NotificationType.listSave:
        icon = Icons.bookmark;
        color = AppColors.gold;
        break;
      case NotificationType.followRequest:
        icon = Icons.person_add;
        color = AppColors.gold;
        break;
      case NotificationType.followAccepted:
        icon = Icons.how_to_reg;
        color = AppColors.success;
        break;
      case NotificationType.personNewCredit:
        icon = Icons.movie_filter;
        color = AppColors.info;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
