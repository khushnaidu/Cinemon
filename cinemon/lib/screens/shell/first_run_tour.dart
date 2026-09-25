import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/liquid_glass.dart' show LiquidGlass;

/// Ask for the tour again (Help → Replay the tour).
final ValueNotifier<int> tourRequests = ValueNotifier<int>(0);

/// Whether [uid] should see the tour: only an account that has never
/// finished or skipped it (migration 025), so it shows once, after signing
/// up, on whichever phone that is. Stored on the account, not the phone, so
/// reinstalling doesn't bring it back. If the lookup fails, no tour.
Future<bool> shouldShowTour(String uid) async {
  try {
    final row = await SupabaseConfig.client
        .from('profiles')
        .select('tour_seen_at')
        .eq('id', uid)
        .maybeSingle();
    return row != null && row['tour_seen_at'] == null;
  } catch (_) {
    return false;
  }
}

Future<void> markTourDone(String uid) async {
  try {
    await SupabaseConfig.client
        .from('profiles')
        .update({'tour_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', uid);
  } catch (_) {}
}

/// Where a step points.
enum _Target {
  none,
  postTab,
  people,
  activity,
  exploreTab,
  trailersTab,
  profileTab
}

class _Step {
  const _Step(this.target, this.title, this.body);
  final _Target target;
  final String title;
  final String body;
}

const _steps = [
  _Step(_Target.none, 'Welcome to 35mm',
      'A quick look at the basics. It takes about twenty seconds.'),
  _Step(_Target.postTab, 'Log what you watch',
      'Tap here, find a film or show, then rate it and write a review.'),
  _Step(_Target.people, 'Find your people',
      'Follow friends and their reviews show up on Home.'),
  _Step(_Target.activity, 'Activity',
      'Likes, comments, votes and follow requests land here.'),
  _Step(_Target.exploreTab, 'Explore',
      'Hot takes and posts from everyone. Agree, disagree, or reply.'),
  _Step(_Target.trailersTab, 'Discover',
      'Trailers for what\'s trending, by genre. Swipe up for the next one.'),
  _Step(
      _Target.profileTab,
      'Your profile',
      'Favourites, playlists and your watchlist. Help and Settings are '
          'under the gear.'),
];

/// The first-run tour over the tab shell (only the basics, skippable at any
/// step). The tab bar and Home's corner buttons are native views that
/// always draw above Flutter, so they stay lit above the dimming: each step
/// points at one of them with a bubble beside it.
class FirstRunTour extends StatefulWidget {
  const FirstRunTour({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<FirstRunTour> createState() => _FirstRunTourState();
}

class _FirstRunTourState extends State<FirstRunTour>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_step + 1 >= _steps.length) {
      widget.onDone();
    } else {
      setState(() => _step++);
    }
  }

  /// Centre of what a step points at, in this widget's coordinates.
  Offset? _anchor(_Target t, Size size, EdgeInsets pad) {
    // The tab bar: inset 34 each side, 56 tall, 6 above the home indicator
    // (glass_shell.dart); five equal slots.
    Offset tab(int i) {
      final w = size.width - 68;
      return Offset(34 + w * (i + 0.5) / 5, size.height - pad.bottom - 6 - 28);
    }

    // Home's corner buttons: 52 wide, 4 below the status bar, inset lg.
    final cornerY = pad.top + 4 + 26;
    return switch (t) {
      _Target.none => null,
      _Target.postTab => tab(1),
      _Target.exploreTab => tab(2),
      _Target.trailersTab => tab(3),
      _Target.profileTab => tab(4),
      _Target.people => Offset(AppSpace.lg + 26, cornerY),
      _Target.activity => Offset(size.width - AppSpace.lg - 26, cornerY),
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final pad = MediaQuery.paddingOf(context);
    final last = _step == _steps.length - 1;

    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      final anchor = _anchor(step.target, size, pad);
      final below = anchor != null && anchor.dy < size.height / 2;

      final bubble = _Bubble(
        title: step.title,
        body: step.body,
        index: _step,
        count: _steps.length,
        primary: _step == 0 ? 'Show me' : (last ? 'Done' : 'Next'),
        onPrimary: _next,
        onSkip: widget.onDone,
        showSkip: !last,
      );

      return Stack(
        children: [
          // Tapping the dimmed area moves on too.
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
            ),
          ),
          if (anchor != null)
            Positioned(
              left: anchor.dx - 44,
              top: below ? anchor.dy + 30 : null,
              bottom: below ? null : size.height - anchor.dy + 30,
              width: 88,
              child: AnimatedBuilder(
                animation: _bob,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, (below ? -1 : 1) * 6 * _bob.value),
                  child: child,
                ),
                child: Icon(
                  below ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
          if (anchor == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                child: bubble,
              ),
            )
          else
            Positioned(
              left: AppSpace.xl,
              right: AppSpace.xl,
              top: below ? anchor.dy + 30 + 40 : null,
              bottom: below ? null : size.height - anchor.dy + 30 + 40,
              child: bubble,
            ),
        ],
      );
    });
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.title,
    required this.body,
    required this.index,
    required this.count,
    required this.primary,
    required this.onPrimary,
    required this.onSkip,
    required this.showSkip,
  });

  final String title;
  final String body;
  final int index;
  final int count;
  final String primary;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;
  final bool showSkip;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: 0.45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.headline),
            const SizedBox(height: AppSpace.xs),
            Text(body,
                style: AppText.body.copyWith(color: AppColors.inkSecondary)),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                // Progress dots, from the first real step.
                if (index > 0)
                  for (var i = 1; i < count; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= index
                            ? AppColors.ink
                            : AppColors.inkTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                const Spacer(),
                if (showSkip)
                  GlassPressable(
                    onTap: onSkip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md, vertical: AppSpace.sm),
                      child: Text('Skip',
                          style: AppText.label
                              .copyWith(color: AppColors.inkSecondary)),
                    ),
                  ),
                const SizedBox(width: AppSpace.xs),
                GlassPillButton(
                  label: primary,
                  prominent: true,
                  compact: true,
                  onTap: onPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
