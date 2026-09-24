import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/explore/explore_provider.dart'
    show userExploreFeedProvider;
import '../../providers/feed/feed_provider.dart'
    show
        currentUserProfileProvider,
        userProfileProvider,
        homeFeedProvider,
        userActivitiesProvider,
        syncReviewCountProvider,
        earnedBadgesProvider,
        myBadgeProgressProvider;
import '../../providers/friendship/friendship_provider.dart';
import '../../providers/lists/list_provider.dart'
    show myWatchlistProvider, playlistsProvider, watchlistProvider;
import '../../providers/user/favorites_provider.dart';
import '../shell/glass_shell.dart' show kFloatingTabBarInset;
import '../widgets/block_user.dart';
import '../widgets/glass_panel.dart';
import '../../share/month_stats.dart' show monthInFilmProvider;
import '../../share/share_entry.dart';
import 'delete_account_panel.dart';
import 'profile_header.dart';
import 'recently_watched_section.dart';
import 'tabs/badges_tab.dart';
import 'tabs/favorites_tab.dart';
import 'tabs/lists_tab.dart';
import 'tabs/posts_tab.dart';

/// The four tabs under a profile's header (ADR 0001, 4.5).
enum ProfileTab {
  posts('Posts'),
  lists('Lists'),
  favorites('Favorites'),
  badges('Badges');

  const ProfileTab(this.label);

  final String label;
}

/// Which tab a profile is on, per profile, for as long as it's open.
final profileTabProvider = StateProvider.autoDispose
    .family<ProfileTab, String>((ref, _) => ProfileTab.posts);

/// Profile page showing user info, stats, and posts
/// Can view own profile (userId = null) or another user's profile
class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _scroll = ScrollController();

  /// Measures everything above the tab bar, to know where it pins.
  final _aboveTabs = GlobalKey();

  /// Where each tab was scrolled to, restored when you come back to it.
  final _offsets = <ProfileTab, double>{};

  static const _tabBarHeight = 52.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The scroll offset at which the tab bar reaches the top and pins.
  double get _pinOffset {
    final box = _aboveTabs.currentContext?.findRenderObject() as RenderBox?;
    return (box?.size.height ?? 0) + kToolbarHeight;
  }

  /// Switch tabs, keeping each tab's place.
  ///
  /// With the header on screen the page stays where it is, since the header
  /// looks the same above every tab. Once the bar is pinned, each tab comes
  /// back where it was left, or at its top.
  void _select(String uid, ProfileTab next) {
    final provider = profileTabProvider(uid);
    final current = ref.read(provider);
    if (next == current) return;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    _offsets[current] = offset;
    ref.read(provider.notifier).state = next;

    final pin = _pinOffset;
    if (offset < pin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = math.max(pin, _offsets[next] ?? pin);
      _scroll.jumpTo(math.min(target, _scroll.position.maxScrollExtent));
    });
  }

  /// A horizontal flick on the content moves one tab over. Rails inside a
  /// tab still scroll: their own drag wins the gesture.
  void _swipe(String uid, DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 400) return;
    final tabs = ProfileTab.values;
    final i = ref.read(profileTabProvider(uid)).index + (v < 0 ? 1 : -1);
    if (i < 0 || i >= tabs.length) return;
    _select(uid, tabs[i]);
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = userId == null || userId == currentUser?.uid;

    // Watch the appropriate profile based on whether it's own or other user
    final profileAsync = isOwnProfile
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(userId));
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
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
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            final tab = ref.watch(profileTabProvider(profile.uid));

            // The scroll view starts below the status bar, so the tab bar
            // pins under it rather than behind it.
            return Padding(
              padding: EdgeInsets.only(top: pad.top),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: RefreshIndicator(
                  onRefresh: () => _refresh(profile, isOwnProfile),
                  color: Colors.white,
                  backgroundColor: AppColors.surface,
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) => _swipe(profile.uid, d),
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          expandedHeight: 0,
                          floating: true,
                          pinned: false,
                          leading: !isOwnProfile
                              ? IconButton(
                                  icon: const Icon(Icons.arrow_back,
                                      color: Colors.white),
                                  onPressed: () => context.pop(),
                                )
                              : null,
                          actions: isOwnProfile
                              ? [
                                  IconButton(
                                    icon: const Icon(
                                        CupertinoIcons.square_arrow_up,
                                        color: Colors.white),
                                    onPressed: () =>
                                        shareMyProfile(context, ref),
                                  ),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.gear,
                                        color: Colors.white),
                                    onPressed: () =>
                                        _showSettingsMenu(context, ref),
                                  ),
                                ]
                              : [
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.ellipsis,
                                        color: Colors.white),
                                    onPressed: () => _showOtherProfileMenu(
                                        context, ref, profile),
                                  ),
                                ],
                        ),

                        // The header, then what they've watched: friend
                        // activity lives here, not under a tab (D12).
                        SliverToBoxAdapter(
                          child: Column(
                            key: _aboveTabs,
                            children: [
                              ProfileHeader(
                                profile: profile,
                                isOwnProfile: isOwnProfile,
                              ),
                              if (isOwnProfile)
                                MonthInFilmTile(userId: profile.uid),
                              RecentlyWatchedSection(
                                userId: profile.uid,
                                isOwnProfile: isOwnProfile,
                                username: profile.username,
                              ),
                              const SizedBox(height: AppSpace.md),
                            ],
                          ),
                        ),

                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabBarDelegate(
                            height: _tabBarHeight,
                            tab: tab,
                            onSelect: (t) => _select(profile.uid, t),
                          ),
                        ),

                        switch (tab) {
                          ProfileTab.posts => PostsTab(
                              userId: profile.uid,
                              isOwnProfile: isOwnProfile,
                            ),
                          ProfileTab.lists => ListsTab(
                              userId: profile.uid,
                              isOwnProfile: isOwnProfile,
                            ),
                          ProfileTab.favorites => FavoritesTab(
                              profile: profile,
                              isOwnProfile: isOwnProfile,
                            ),
                          ProfileTab.badges => BadgesTab(
                              userId: profile.uid,
                              isOwnProfile: isOwnProfile,
                              fallbackIds: profile.badgeIds,
                            ),
                        },

                        // Clear of the floating tab bar, and tall enough that
                        // a short tab can still scroll the header away.
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox(
                            height:
                                pad.bottom + kFloatingTabBarInset + AppSpace.xl,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading profile',
                  style: TextStyle(color: Colors.red[300]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    if (isOwnProfile) {
                      ref.invalidate(currentUserProfileProvider);
                    } else {
                      ref.invalidate(userProfileProvider(userId));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(UserModel profile, bool isOwnProfile) async {
    final uid = profile.uid;
    if (isOwnProfile) {
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(currentUserFavoriteFilmsProvider);
      ref.invalidate(currentUserFavoriteShowsProvider);
      ref.invalidate(currentUserFavoriteActorsProvider);
      ref.invalidate(currentUserFavoriteDirectorsProvider);
      ref.invalidate(currentUserRecentlyWatchedProvider);
      ref.invalidate(myWatchlistProvider);
      ref.invalidate(myBadgeProgressProvider);
      final now = DateTime.now();
      ref.invalidate(
          monthInFilmProvider((userId: uid, year: now.year, month: now.month)));
    } else {
      ref.invalidate(userProfileProvider(uid));
      ref.invalidate(recentlyWatchedProvider(uid));
      ref.invalidate(watchlistProvider(uid));
    }
    ref.invalidate(userActivitiesProvider(uid));
    ref.invalidate(playlistsProvider(uid));
    ref.invalidate(userExploreFeedProvider);
    ref.invalidate(earnedBadgesProvider(uid));
    // Wait for refresh to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _showOtherProfileMenu(
      BuildContext context, WidgetRef ref, UserModel profile) {
    showGlassPanel(
      context,
      builder: (panelContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.sm),
          GlassMenuRow(
            icon: CupertinoIcons.hand_raised,
            title: 'Block @${profile.username}',
            destructive: true,
            onTap: () async {
              Navigator.of(panelContext).pop();
              final blocked = await confirmAndBlock(
                context,
                ref,
                userId: profile.uid,
                username: profile.username,
              );
              // Their profile is hidden from you now; nothing to stay for.
              if (blocked && context.mounted && context.canPop()) {
                context.pop();
              }
            },
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, WidgetRef ref) {
    // Captured before the panel closes: the builder's context is deactivated
    // the moment it pops, so anything looked up from it goes nowhere. Toasts
    // are raised from the page's own context, which outlives the panel.
    final router = GoRouter.of(context);

    showGlassPanel(
      context,
      builder: (panelContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanelHeader(
            title: 'Settings',
            trailingLabel: 'Done',
            onTrailing: () => Navigator.of(panelContext).pop(),
          ),
          const SizedBox(height: AppSpace.xs),
          GlassMenuRow(
            icon: CupertinoIcons.person_crop_circle,
            title: 'Edit profile',
            subtitle: 'Photo, username, bio',
            chevron: true,
            onTap: () {
              Navigator.of(panelContext).pop();
              router.push('/edit-profile');
            },
          ),
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: CupertinoIcons.arrow_2_circlepath,
            title: 'Sync review count',
            subtitle: 'Recount your reviews if the number looks wrong',
            onTap: () async {
              Navigator.of(panelContext).pop();
              final currentUser = ref.read(currentUserProvider);
              if (currentUser == null) return;
              showGlassToast(
                context,
                'Syncing review count…',
                icon: CupertinoIcons.arrow_2_circlepath,
              );
              final count = await ref
                  .read(syncReviewCountProvider(currentUser.uid).future);
              if (!context.mounted) return;
              showGlassToast(context, 'Synced — $count reviews');
            },
          ),
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: CupertinoIcons.hand_raised,
            title: 'Blocked accounts',
            chevron: true,
            onTap: () {
              Navigator.of(panelContext).pop();
              showBlockedAccountsPanel(context);
            },
          ),
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: CupertinoIcons.square_arrow_right,
            title: 'Sign out',
            destructive: true,
            onTap: () async {
              Navigator.of(panelContext).pop();
              // Drop cached user data so the next account doesn't inherit it.
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(homeFeedProvider);
              ref.invalidate(friendIdsProvider);
              await ref.read(authControllerProvider.notifier).signOut();
              router.go('/login');
            },
          ),
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: CupertinoIcons.trash,
            title: 'Delete account',
            subtitle: 'Permanently remove your account and everything in it',
            destructive: true,
            onTap: () async {
              Navigator.of(panelContext).pop();
              final currentUser = ref.read(currentUserProvider);
              final profile = ref.read(currentUserProfileProvider).valueOrNull;
              if (currentUser == null || profile == null) return;
              final deleted = await showDeleteAccountPanel(
                context,
                uid: currentUser.uid,
                username: profile.username,
              );
              if (!deleted) return;
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(homeFeedProvider);
              ref.invalidate(friendIdsProvider);
              await ref.read(authControllerProvider.notifier).signOut();
              router.go('/login');
              if (context.mounted) {
                showGlassToast(context, 'Your account has been deleted');
              }
            },
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

/// The pinned tab bar. Opaque black behind the control, so content scrolling
/// up under it disappears rather than showing through.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({
    required this.height,
    required this.tab,
    required this.onSelect,
  });

  final double height;
  final ProfileTab tab;
  final ValueChanged<ProfileTab> onSelect;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        border: overlaps
            ? Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.sm),
        child: Center(
          child: GlassSegmentedControl(
            labels: [for (final t in ProfileTab.values) t.label],
            index: tab.index,
            onChanged: (i) => onSelect(ProfileTab.values[i]),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tab != tab || old.height != height || old.onSelect != onSelect;
}
