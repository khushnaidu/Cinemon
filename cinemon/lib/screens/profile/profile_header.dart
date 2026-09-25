import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/follow/follow_provider.dart';
import '../follow_list_screen.dart' show confirmUnfollow;
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
              _FollowCount(
                profile: profile,
                isOwnProfile: isOwnProfile,
                kind: FollowListKind.followers,
                child: _buildStatColumn(
                    profile.followerCount.toString(), 'Followers'),
              ),
              const SizedBox(width: 40),
              _FollowCount(
                profile: profile,
                isOwnProfile: isOwnProfile,
                kind: FollowListKind.following,
                child: _buildStatColumn(
                    profile.followingCount.toString(), 'Following'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Edit, or Follow and anything waiting between you.
          if (isOwnProfile)
            const _EditProfileButton()
          else
            _FollowControls(profile: profile),

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

/// A count that opens the list behind it, unless the account is private and
/// you don't follow it: then there's nothing you're allowed to see.
class _FollowCount extends ConsumerWidget {
  const _FollowCount({
    required this.profile,
    required this.isOwnProfile,
    required this.kind,
    required this.child,
  });

  final UserModel profile;
  final bool isOwnProfile;
  final FollowListKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        !isOwnProfile && ref.watch(profileLockedProvider(profile.uid));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: locked
          ? null
          : () => context.push(
              '/follows/${profile.uid}?tab=${kind == FollowListKind.followers ? 'followers' : 'following'}'),
      child: child,
    );
  }
}

/// Whether [userId]'s profile is private to you: private, and you don't
/// follow it. The profile shows only its header then (ADR 0004 D3).
final profileLockedProvider =
    Provider.autoDispose.family<bool, String>((ref, userId) {
  final private = ref.watch(isPrivateProvider(userId)).valueOrNull ?? false;
  if (!private) return false;
  final rel = ref.watch(followRelationProvider(userId)).valueOrNull;
  return rel?.outgoing != FollowState.following;
});

/// Someone else's profile: a request they've sent you, and the Follow button
/// (ADR 0004 D8): Follow, Follow back, Requested, Following, or Friends when
/// you follow each other.
class _FollowControls extends ConsumerWidget {
  const _FollowControls({required this.profile});

  final UserModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = ref.watch(followRelationProvider(profile.uid)).valueOrNull ??
        FollowRelation.nothing;
    final actions = ref.read(followActionsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rel.incoming == FollowState.requested) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
            decoration: glassWellDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '@${profile.username} wants to follow you',
                    style: AppText.body.copyWith(fontSize: 15),
                  ),
                ),
                GlassPillButton(
                  label: 'Confirm',
                  prominent: true,
                  compact: true,
                  onTap: () => actions.accept(profile.uid),
                ),
                const SizedBox(width: AppSpace.sm),
                GlassPillButton(
                  label: 'Delete',
                  compact: true,
                  onTap: () => actions.removeFollower(profile.uid),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        _FollowButton(profile: profile, relation: rel),
      ],
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.profile, required this.relation});

  final UserModel profile;
  final FollowRelation relation;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() op) async {
    setState(() => _busy = true);
    final result = await op();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null || result == false) {
      showGlassToast(context, 'Something went wrong. Try again.',
          destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(followActionsProvider);
    final username = widget.profile.username;
    final (label, icon, primary, onTap) = switch (widget.relation.outgoing) {
      FollowState.none => (
          widget.relation.followsYou ? 'Follow back' : 'Follow',
          CupertinoIcons.person_add,
          true,
          () => _run(() => actions.follow(widget.profile.uid)),
        ),
      FollowState.requested => (
          'Requested',
          CupertinoIcons.clock,
          false,
          () => _run(() => actions.unfollow(widget.profile.uid)),
        ),
      // Following each other reads as friends; one way, as following.
      FollowState.following => (
          widget.relation.followsYou ? 'Friends' : 'Following',
          widget.relation.followsYou
              ? CupertinoIcons.person_2_fill
              : CupertinoIcons.person_crop_circle_badge_checkmark,
          false,
          () async {
            if (await confirmUnfollow(context, username)) {
              await _run(() => actions.unfollow(widget.profile.uid));
            }
          },
        ),
    };
    return SizedBox(
      width: 200,
      child: GlassPillButton(
        label: label,
        icon: icon,
        prominent: primary,
        expand: true,
        busy: _busy,
        onTap: onTap,
      ),
    );
  }
}
