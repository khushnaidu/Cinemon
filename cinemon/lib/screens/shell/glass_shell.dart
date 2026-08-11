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
    _branchDepth += delta;
    _publishChrome();
  }
}

/// A fresh observer per branch. [NavigatorState] asserts that an observer
/// belongs to exactly one navigator, so the instance can't be shared even
/// though the counter behind it is.
NavigatorObserver branchDepthObserver() => _BranchDepthObserver();

/// The persistent chrome that the four tabs live inside.
///
/// The tab bar is deliberately *outside* the branch navigators rather than in
/// each screen's Scaffold:
///
///   * It survives tab changes, so the travelling selection is visible at
///     all. A bar rebuilt per screen restarts its animation every time.
///   * Each tab keeps its own navigation stack and scroll position, because
///     `StatefulShellRoute.indexedStack` holds all four branches alive.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) shellRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    shellRouteObserver.unsubscribe(this);
    super.dispose();
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
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab pops that branch to its root, the way every
      // iOS tab bar behaves.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No bottomNavigationBar: that reserves a strip and stops content from
      // passing beneath the glass. The bar is a floating overlay.
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.navigationShell,
            Positioned(
              left: 34,
              right: 34,
              bottom: MediaQuery.of(context).padding.bottom + 6,
              // Unmounted, not hidden: Offstage would keep the platform view
              // alive and it would keep compositing above Flutter's content.
              child: ValueListenableBuilder<bool>(
                valueListenable: shellChromeVisible,
                builder: (context, visible, _) {
                  if (!visible) return const SizedBox.shrink();
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
                      GlassTabItem(
                        symbol: 'magnifyingglass',
                        activeSymbol: 'magnifyingglass',
                        label: 'Search',
                        fallbackIcon: CupertinoIcons.search,
                        fallbackActiveIcon: CupertinoIcons.search,
                      ),
                      GlassTabItem(
                        symbol: 'plus.square',
                        activeSymbol: 'plus.square.fill',
                        label: 'Create',
                        fallbackIcon: CupertinoIcons.plus_square,
                        fallbackActiveIcon: CupertinoIcons.plus_square_fill,
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
