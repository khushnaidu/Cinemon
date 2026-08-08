import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
  bool _covered = false;

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

  @override
  void didPushNext() => setState(() => _covered = true);

  @override
  void didPopNext() => setState(() => _covered = false);

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
            if (!_covered)
              Positioned(
                left: 34,
                right: 34,
                bottom: MediaQuery.of(context).padding.bottom + 6,
                child: NativeGlassTabBar(
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Vertical space the floating bar occupies, for screens that need to keep
/// content clear of it. A plain constant so it can be used in `const` padding.
const double kFloatingTabBarInset = 78;
