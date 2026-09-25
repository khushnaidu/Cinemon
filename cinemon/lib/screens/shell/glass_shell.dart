import '../../core/platform/age_signal.dart';
import '../../repositories/user_repository.dart';
import '../auth/age_gate.dart' show blockAgeGate;
import '../widgets/glass_panel.dart' show showGlassConfirm, showGlassToast;
import '../../core/config/supabase_config.dart';
import 'first_run_tour.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:go_router/go_router.dart';

import '../widgets/native_glass_tab_bar.dart';

/// Watches route pushes so the shell knows when something covers it.
///
/// A platform view composites in the UIKit layer, above everything Flutter
/// draws. Relying on Flutter's paint order to cover it is fragile, so the bar
/// is unmounted outright whenever another route — a pushed screen or a modal
/// sheet — sits on top. Registered on the router via `observers:`.
final RouteObserver<ModalRoute<void>> shellRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Whether floating native chrome should be mounted right now.
///
/// Everything drawn with real Liquid Glass is a platform view, and a platform
/// view composites in the UIKit layer — above everything Flutter draws. There
/// is no paint order that puts a sheet on top of one. So "covered" has to mean
/// *unmounted*, and every floating overlay in the app watches this one flag:
/// the shell's tab bar, and the home feed's floating buttons.
///
/// Two independent things can cover the shell, and they're detected
/// differently — see [shellRouteObserver] and the branch observers below.
final ValueNotifier<bool> shellChromeVisible = ValueNotifier<bool>(true);

/// A tab playing full screen (Trailers on its side) hides the tab bar
/// without counting as covered: the tab is still the one on screen.
final ValueNotifier<bool> shellImmersive = ValueNotifier<bool>(false);

/// Which tab is showing. The Trailers tab watches it to stop its player as
/// soon as you leave, since the indexed stack keeps it alive offstage.
final ValueNotifier<int> shellBranchIndex = ValueNotifier<int>(0);

final StreamController<int> _reselects = StreamController<int>.broadcast();

/// The index of a tab tapped while it was already showing. Screens scroll
/// back to the top on it, the way iOS tab bars do.
Stream<int> get shellTabReselects => _reselects.stream;

bool _rootCovered = false;
int _branchDepth = 0;

/// Recomputes [shellChromeVisible], deferring if we're mid-frame.
///
/// A [Navigator] diffs its page list from inside its own `build`, so the
/// observer callbacks that feed this can land during the build phase.
/// Notifying synchronously there marks listeners dirty while the tree is
/// already building, which throws `markNeedsBuild() called during build`.
/// The value is recomputed inside the callback rather than captured, so a
/// second push landing in the same frame can't publish a stale answer.
void _publishChrome() {
  void apply() => shellChromeVisible.value = !_rootCovered && _branchDepth == 0;

  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => apply());
  } else {
    apply();
  }
}

/// Counts routes stacked *inside* a tab.
///
/// [shellRouteObserver] only sees the root navigator, which is where
/// `context.push('/notifications')` and friends land. A modal sheet is
/// different: `showModalBottomSheet` defaults to the nearest navigator, and
/// inside a [StatefulShellRoute] that is the branch's own. Those pushes are
/// invisible to the root observer, so the bar used to keep floating over
/// sheets — right on top of the buttons they put near the bottom edge, which
/// is where a sheet's destructive actions live.
///
/// Registered on every branch via `StatefulShellBranch(observers:)`, so it
/// covers sheets opened anywhere without each call site opting in.
class _BranchDepthObserver extends NavigatorObserver {
  // A null previousRoute means this is the navigator's own first route — the
  // tab itself, which covers nothing.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _bump(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _bump(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _bump(-1);
  }

  void _bump(int delta) {
    // Never below zero: a pop reported after the shell was rebuilt would
    // otherwise hide the bar for good.
    _branchDepth = (_branchDepth + delta).clamp(0, 1 << 20);
    _publishChrome();
  }
}

/// A fresh observer per branch. [NavigatorState] asserts that an observer
/// belongs to exactly one navigator, so the instance can't be shared even
/// though the counter behind it is.
NavigatorObserver branchDepthObserver() => _BranchDepthObserver();

/// The persistent chrome that the five tabs live inside.
///
/// The tab bar is deliberately *outside* the branch navigators rather than in
/// each screen's Scaffold:
///
///   * It survives tab changes, so the travelling selection is visible at
///     all. A bar rebuilt per screen restarts its animation every time.
///   * Each tab keeps its own navigation stack and scroll position, because
///     `StatefulShellRoute.indexedStack` holds all five branches alive.
///   * Content scrolls *under* it, which is what the glass refracts. Chrome
///     in a reserved strip has nothing behind it to bend.
class GlassShell extends StatefulWidget {
  const GlassShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<GlassShell> createState() => _GlassShellState();
}

class _GlassShellState extends State<GlassShell> with RouteAware {
  bool _compact = false;

  /// A shell that's just been built has nothing on top of it. The counts are
  /// app-wide and only move on pushes and pops, so without this a shell torn
  /// down with a sheet or screen still open (signing out from Settings,
  /// deleting an account) left them stuck, and the next account's Home came
  /// up with no tab bar until the app restarted.
  /// The first-run tour is showing.
  bool _touring = false;

  @override
  void initState() {
    super.initState();
    _resetChrome();
    tourRequests.addListener(_replayTour);
    final uid = SupabaseConfig.currentUserId;
    if (uid != null) {
      shouldShowTour(uid).then((show) {
        if (mounted && show) setState(() => _touring = true);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAgeSignal());
    }
  }

  /// Where state law requires it (Texas now), Apple's age signal decides:
  /// under 13 closes the account, 13 to 17 is recorded (and goes private),
  /// and declining to share keeps the app closed until they do. Anywhere
  /// else this returns straight away. Once per launch.
  static bool _ageChecked = false;

  Future<void> _checkAgeSignal() async {
    if (_ageChecked) return;
    final signal = await checkAgeSignal();
    if (!mounted) return;
    switch (signal) {
      case AgeSignalShared(:final under13, :final minor):
        _ageChecked = true;
        if (under13) return _closeUnderage();
        try {
          await SupabaseConfig.client
              .rpc('record_age_signal', params: {'minor': minor});
        } catch (_) {}
      case AgeSignalDeclined():
        final retry = await showGlassConfirm(
          context,
          title: 'Share your age range to continue',
          message: 'In your region, apps like 35mm are required to check '
              'your age range with Apple before you can use them. Only the '
              'range is shared, never your birthday.',
          confirmLabel: 'Try again',
          cancelLabel: 'Sign out',
        );
        if (!mounted) return;
        if (retry) {
          await _checkAgeSignal();
        } else {
          await SupabaseConfig.client.auth.signOut();
          if (mounted) GoRouter.of(context).go('/login');
        }
      case AgeSignalNotRequired():
        _ageChecked = true;
      case AgeSignalUnavailable():
        // Try again next launch rather than lock someone out over a
        // system hiccup.
        break;
    }
  }

  Future<void> _closeUnderage() async {
    final uid = SupabaseConfig.currentUserId;
    await blockAgeGate();
    try {
      if (uid != null) await UserRepository().deleteAccount(uid);
    } catch (_) {}
    await SupabaseConfig.client.auth.signOut();
    if (!mounted) return;
    GoRouter.of(context).go('/login');
    showGlassToast(
        context, 'Sorry, you can\'t use 35mm. Your account has been deleted.');
  }

  void _replayTour() {
    widget.navigationShell.goBranch(0, initialLocation: true);
    setState(() => _touring = true);
  }

  void _endTour() {
    final uid = SupabaseConfig.currentUserId;
    if (uid != null) markTourDone(uid);
    setState(() => _touring = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) shellRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    tourRequests.removeListener(_replayTour);
    shellRouteObserver.unsubscribe(this);
    _resetChrome();
    _ageChecked = false;
    super.dispose();
  }

  static void _resetChrome() {
    _rootCovered = false;
    _branchDepth = 0;
    shellImmersive.value = false;
    _publishChrome();
  }

  // Published rather than held in State: the home feed's floating buttons are
  // platform views too, and they need the same signal from outside this tree.
  @override
  void didPushNext() {
    _rootCovered = true;
    _publishChrome();
  }

  @override
  void didPopNext() {
    _rootCovered = false;
    _publishChrome();
  }

  /// Contract on scroll down, restore on scroll up.
  ///
  /// Driven by [UserScrollNotification] rather than raw offsets so it only
  /// responds to deliberate dragging — momentum settling and programmatic
  /// scrolls don't make the bar twitch.
  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0) return false;
    switch (n.direction) {
      case ScrollDirection.reverse:
        if (!_compact) setState(() => _compact = true);
      case ScrollDirection.forward:
        if (_compact) setState(() => _compact = false);
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  void _onTap(int index) {
    if (index == widget.navigationShell.currentIndex) _reselects.add(index);
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab pops that branch to its root, the way every
      // iOS tab bar behaves.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    if (shellBranchIndex.value != index) {
      // Not during build: listeners would rebuild mid-frame.
      SchedulerBinding.instance
          .addPostFrameCallback((_) => shellBranchIndex.value = index);
    }
    return Scaffold(
      // No bottomNavigationBar: that reserves a strip and stops content from
      // passing beneath the glass. The bar is a floating overlay.
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.navigationShell,
            // Over Home only, and not while anything covers the shell.
            if (_touring && index == 0)
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: shellChromeVisible,
                  builder: (context, visible, _) => visible
                      ? FirstRunTour(onDone: _endTour)
                      : const SizedBox.shrink(),
                ),
              ),
            Positioned(
              left: 34,
              right: 34,
              bottom: MediaQuery.of(context).padding.bottom + 6,
              // Unmounted, not hidden: Offstage would keep the platform view
              // alive and it would keep compositing above Flutter's content.
              child: ListenableBuilder(
                listenable:
                    Listenable.merge([shellChromeVisible, shellImmersive]),
                builder: (context, _) {
                  if (!shellChromeVisible.value || shellImmersive.value) {
                    return const SizedBox.shrink();
                  }
                  return NativeGlassTabBar(
                    currentIndex: widget.navigationShell.currentIndex,
                    onTap: _onTap,
                    compact: _compact,
                    items: const [
                      GlassTabItem(
                        symbol: 'house',
                        activeSymbol: 'house.fill',
                        label: 'Home',
                        fallbackIcon: CupertinoIcons.house,
                        fallbackActiveIcon: CupertinoIcons.house_fill,
                      ),
                      // Search is where a post starts (find the film, post
                      // about it), so it wears the plus. The globe is
                      // Explore: posts from everyone.
                      GlassTabItem(
                        symbol: 'plus.square',
                        activeSymbol: 'plus.square.fill',
                        label: 'Post',
                        fallbackIcon: CupertinoIcons.plus_square,
                        fallbackActiveIcon: CupertinoIcons.plus_square_fill,
                      ),
                      GlassTabItem(
                        symbol: 'globe',
                        activeSymbol: 'globe.americas.fill',
                        label: 'Explore',
                        fallbackIcon: CupertinoIcons.globe,
                        fallbackActiveIcon: CupertinoIcons.globe,
                      ),
                      GlassTabItem(
                        symbol: 'play.rectangle.on.rectangle',
                        activeSymbol: 'play.rectangle.on.rectangle.fill',
                        label: 'Trailers',
                        fallbackIcon: CupertinoIcons.play_rectangle,
                        fallbackActiveIcon: CupertinoIcons.play_rectangle_fill,
                      ),
                      GlassTabItem(
                        symbol: 'person',
                        activeSymbol: 'person.fill',
                        label: 'Profile',
                        fallbackIcon: CupertinoIcons.person,
                        fallbackActiveIcon: CupertinoIcons.person_fill,
                      ),
                    ],
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

/// Height of the floating header buttons plus their gap to the safe area —
/// matching the `Positioned(top: padding.top + 4)` and 52pt button below.
///
/// Both of these are measured from the safe-area edge, not the screen edge, so
/// screens add the relevant `MediaQuery.padding` themselves. That's why they
/// can't be baked into one number: the status bar and home indicator are
/// runtime values that differ per device.
const double kFloatingHeaderInset = 56;

/// Height of the floating tab bar plus its gap — matching the
/// `Positioned(bottom: padding.bottom + 6)` and 56pt bar below.
const double kFloatingTabBarInset = 62;
