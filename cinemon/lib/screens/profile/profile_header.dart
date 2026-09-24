import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart'
    show currentUserProfileProvider, userProfileProvider;
import '../../providers/friendship/friendship_provider.dart';
import '../widgets/arch_profile_frame.dart';
import '../widgets/glass_panel.dart';

/// The top of a profile: photo, names, bio, counts, and Edit or Follow.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isOwnProfile,
  });

  final UserModel profile;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Profile Photo with Arch Frame and Username
          ArchProfileFrame(
            photoUrl: profile.photoUrl,
            username: profile.username,
            width: 120,
            height: 160,
            glowColor: const Color(0xFFFFD54F),
          ),

          // The brush-lettered name above is for looks; this is the one to
          // read, search and tag.
          // Tucked up under the brush name, into the space its line box
          // leaves below the letters.
          Transform.translate(
            offset: const Offset(0, -10),
            child: Text(
              '@${profile.username}',
              style: AppText.footnote.copyWith(
                fontSize: 15,
                color: AppColors.inkTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Display name if different
          if (profile.displayName != null &&
              profile.displayName != profile.username)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile.displayName!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                profile.bio!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatColumn(profile.reviewCount.toString(), 'Reviews'),
              const SizedBox(width: 40),
              _buildStatColumn(profile.followerCount.toString(), 'Followers'),
              const SizedBox(width: 40),
              _buildStatColumn(profile.followingCount.toString(), 'Following'),
            ],
          ),

          const SizedBox(height: 20),

          // Action Button (Edit Profile or Follow/Unfollow)
          if (isOwnProfile)
            const _EditProfileButton()
          else
            _FollowButton(targetUserId: profile.uid, targetProfile: profile),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Isometric3D',
            color: Colors.white,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Edit Profile button for own profile: a compact glass capsule, the same
/// control as the section "Edit" pills further down the page.
class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton();

  @override
  Widget build(BuildContext context) {
    // Centered so it sizes to its label even under a stretching column.
    return Center(
      child: GlassPillButton(
        label: 'Edit profile',
        icon: CupertinoIcons.pencil,
        compact: true,
        onTap: () => context.push('/edit-profile'),
      ),
    );
  }
}

/// Follow/Unfollow button for other users' profiles
class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  final UserModel targetProfile;

  const _FollowButton({
    required this.targetUserId,
    required this.targetProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendshipAsync = ref.watch(friendshipStatusProvider(targetUserId));
    final friendshipNotifier = ref.watch(friendshipNotifierProvider);
    final currentProfile = ref.watch(currentUserProfileProvider).value;

    return friendshipAsync.when(
      data: (friendship) {
        final isLoading = friendshipNotifier.isLoading;

        // Determine button state based on friendship status
        if (friendship == null) {
          // No relationship - show Follow button
          return _buildButton(
            label: 'Follow',
            isLoading: isLoading,
            isPrimary: true,
            onPressed: () async {
              await ref
                  .read(friendshipNotifierProvider.notifier)
                  .sendFriendRequest(
                    receiverId: targetUserId,
                    senderUsername: currentProfile?.username,
                    senderPhotoUrl: currentProfile?.photoUrl,
                    receiverUsername: targetProfile.username,
                    receiverPhotoUrl: targetProfile.photoUrl,
                  );
              // Refresh the status
              ref.invalidate(friendshipStatusProvider(targetUserId));
            },
          );
        }

        if (friendship.isPending) {
          final currentUser = ref.read(currentUserProvider);
          final isSender = friendship.senderId == currentUser?.uid;

          if (isSender) {
            // Current user sent the request - show Requested
            return _buildButton(
              label: 'Requested',
              isLoading: isLoading,
              isPrimary: false,
              onPressed: () async {
                // Cancel the request
                await ref
                    .read(friendshipNotifierProvider.notifier)
                    .unfriend(targetUserId);
                ref.invalidate(friendshipStatusProvider(targetUserId));
              },
            );
          } else {
            // Current user received the request - show Accept/Decline
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton(
                  label: 'Accept',
                  isLoading: isLoading,
                  isPrimary: true,
                  width: 130,
                  onPressed: () async {
                    await ref
                        .read(friendshipNotifierProvider.notifier)
                        .acceptFriendRequest(
                          friendship.id,
                          senderId: friendship.senderId,
                          senderUsername: friendship.senderUsername,
                          senderPhotoUrl: friendship.senderPhotoUrl,
                          receiverUsername: friendship.receiverUsername,
                          receiverPhotoUrl: friendship.receiverPhotoUrl,
                        );
                    ref.invalidate(friendshipStatusProvider(targetUserId));
                    ref.invalidate(currentUserProfileProvider);
                    ref.invalidate(userProfileProvider(targetUserId));
                  },
                ),
                const SizedBox(width: 12),
                _buildButton(
                  label: 'Decline',
                  isLoading: isLoading,
                  isPrimary: false,
                  width: 130,
                  onPressed: () async {
                    await ref
                        .read(friendshipNotifierProvider.notifier)
                        .declineFriendRequest(friendship.id);
                    ref.invalidate(friendshipStatusProvider(targetUserId));
                  },
                ),
              ],
            );
          }
        }

        if (friendship.isAccepted) {
          // Already friends - show Following
          return _buildButton(
            label: 'Following',
            isLoading: isLoading,
            isPrimary: false,
            onPressed: () {
              // Show confirmation dialog before unfollowing
              _showUnfollowDialog(
                  context, ref, targetUserId, targetProfile.username);
            },
          );
        }

        // Declined - show Follow button again
        return _buildButton(
          label: 'Follow',
          isLoading: isLoading,
          isPrimary: true,
          onPressed: () async {
            await ref
                .read(friendshipNotifierProvider.notifier)
                .sendFriendRequest(
                  receiverId: targetUserId,
                  senderUsername: currentProfile?.username,
                  senderPhotoUrl: currentProfile?.photoUrl,
                  receiverUsername: targetProfile.username,
                  receiverPhotoUrl: targetProfile.photoUrl,
                );
            ref.invalidate(friendshipStatusProvider(targetUserId));
          },
        );
      },
      loading: () => _buildButton(
        label: 'Follow',
        isLoading: true,
        isPrimary: false,
        onPressed: null,
      ),
      error: (_, __) => _buildButton(
        label: 'Follow',
        isLoading: false,
        isPrimary: true,
        onPressed: () async {
          await ref.read(friendshipNotifierProvider.notifier).sendFriendRequest(
                receiverId: targetUserId,
                senderUsername: currentProfile?.username,
                senderPhotoUrl: currentProfile?.photoUrl,
                receiverUsername: targetProfile.username,
                receiverPhotoUrl: targetProfile.photoUrl,
              );
          ref.invalidate(friendshipStatusProvider(targetUserId));
        },
      ),
    );
  }

  /// Glass, like every other control (ADR 0004 D8): Follow and Accept are
  /// the bright lens, everything else the darker pill. Never solid white.
  Widget _buildButton({
    required String label,
    required bool isLoading,
    required bool isPrimary,
    VoidCallback? onPressed,
    double width = 200,
  }) {
    final icon = switch (label) {
      'Follow' => CupertinoIcons.person_add,
      'Following' => CupertinoIcons.person_crop_circle_badge_checkmark,
      'Requested' => CupertinoIcons.clock,
      'Accept' => CupertinoIcons.checkmark_alt,
      'Decline' => CupertinoIcons.xmark,
      _ => null,
    };
    return SizedBox(
      width: width,
      child: GlassPillButton(
        label: label,
        icon: icon,
        prominent: isPrimary,
        expand: true,
        busy: isLoading,
        onTap: onPressed,
      ),
    );
  }

  Future<void> _showUnfollowDialog(BuildContext context, WidgetRef ref,
      String userId, String username) async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Unfollow @$username?',
      message:
          'You\'ll stop seeing each other\'s posts until you follow again.',
      confirmLabel: 'Unfollow',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(friendshipNotifierProvider.notifier).unfriend(userId);
    ref.invalidate(friendshipStatusProvider(userId));
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(userProfileProvider(userId));
  }
}
