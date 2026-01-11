import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/api_constants.dart';
import '../models/notification_model.dart';
import '../models/sticker_model.dart';
import '../providers/notification/notification_provider.dart';

/// Activity/Notifications screen - Instagram-style activity feed
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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
            color: const Color.fromARGB(255, 30, 30, 50),
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
              Color.fromARGB(255, 3, 1, 32),
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
          data: (notifications) {
            if (notifications.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsStreamProvider);
              },
              color: Colors.white,
              backgroundColor: const Color.fromARGB(255, 30, 30, 50),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  return _NotificationTile(
                    notification: notifications[index],
                    onTap: () => _handleNotificationTap(notifications[index]),
                    onDismiss: () => _handleDismiss(notifications[index]),
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

  void _handleNotificationTap(NotificationModel notification) {
    // Navigate based on notification type
    if (notification.type == NotificationType.followRequest ||
        notification.type == NotificationType.followAccepted) {
      context.push('/profile/${notification.actorId}');
    } else if (notification.activityId != null) {
      // For now, navigate to the actor's profile
      // Could be enhanced to navigate to the specific activity
      context.push('/profile/${notification.actorId}');
    }
  }

  void _handleDismiss(NotificationModel notification) {
    ref.read(notificationNotifierProvider.notifier)
        .deleteNotification(notification.id);
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 50),
        title: const Text(
          'Clear all activity?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove all notifications. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(notificationNotifierProvider.notifier).clearAllNotifications();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
                onTap: () => context.push('/profile/${notification.actorId}'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: notification.actorPhotoUrl != null
                      ? CachedNetworkImageProvider(notification.actorPhotoUrl!)
                      : null,
                  child: notification.actorPhotoUrl == null
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
                            text: notification.actorUsername,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' ${notification.message}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    // Comment preview
                    if (notification.commentPreview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${notification.commentPreview}"',
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

  Widget _buildTrailing() {
    // Show sticker for reaction notifications
    if (notification.type == NotificationType.reaction && notification.stickerId != null) {
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
        color = Colors.red;
        break;
      case NotificationType.comment:
        icon = Icons.chat_bubble;
        color = Colors.blue;
        break;
      case NotificationType.reaction:
        icon = Icons.add_reaction;
        color = Colors.amber;
        break;
      case NotificationType.followRequest:
        icon = Icons.person_add;
        color = Colors.orange;
        break;
      case NotificationType.followAccepted:
        icon = Icons.how_to_reg;
        color = Colors.green;
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
