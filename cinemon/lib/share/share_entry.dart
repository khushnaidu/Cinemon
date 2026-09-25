import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/poster_palette.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/user/favorites_provider.dart';
import '../screens/widgets/glass_panel.dart';
import 'cards/profile_cards.dart';
import 'month_stats.dart';
import 'share_sheet.dart';
import 'share_subject.dart';
import 'story_canvas.dart';

/// Your profile and this month, ready for the share sheet (ADR 0003, P1
/// and P2).
Future<ProfileShare?> _myProfileShare(WidgetRef ref) async {
  final me = await ref.read(currentUserProfileProvider.future);
  if (me == null) return null;
  final ids = me.favoriteFilmIds.take(3).toList();
  final showIds = me.favoriteShowIds.take(3).toList();
  final top3 = ids.isEmpty
      ? const <Never>[]
      : await ref
          .read(favoriteFilmsDataProvider(favoriteFilmsKey(ids)).future)
          .catchError((_) => const <Never>[]);
  final top3Shows = showIds.isEmpty
      ? const <Never>[]
      : await ref
          .read(favoriteShowsDataProvider(favoriteFilmsKey(showIds)).future)
          .catchError((_) => const <Never>[]);
  final logged = await ref
      .read(feedRepositoryProvider)
      .countUserActivities(me.uid)
      .catchError((_) => 0);
  final now = DateTime.now();
  return ProfileShare(
    user: me,
    top3: top3,
    top3Shows: top3Shows,
    logged: logged,
    month: DateTime(now.year, now.month),
  );
}

/// Opens the share sheet on your profile card, or on P2 with
/// [initialCode] "P2".
Future<void> shareMyProfile(
  BuildContext context,
  WidgetRef ref, {
  String? initialCode,
}) async {
  try {
    final subject = await _myProfileShare(ref);
    if (subject == null || !context.mounted) return;
    await showShareSheet(context, subject, initialCode: initialCode);
  } catch (_) {
    if (context.mounted) {
      showGlassToast(context, "Couldn't load your profile. Try again.",
          destructive: true);
    }
  }
}

/// This month, on your own profile: one thin row, "September in review",
/// opening the Month in film cards (ADR 0003 §6). Films and TV are
/// separate cards in the panel, swiped between.
class MonthInFilmTile extends ConsumerWidget {
  const MonthInFilmTile({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final stats = ref
        .watch(monthInFilmProvider(
            (userId: userId, year: now.year, month: now.month)))
        .valueOrNull;
    if (stats == null || stats.isEmpty) return const SizedBox.shrink();
    final f = stats.films;
    final t = stats.shows;
    final summary = [
      if (!f.isEmpty) '${f.titles} ${f.titles == 1 ? 'film' : 'films'}',
      if (t.episodes > 0)
        '${t.episodes} ${t.episodes == 1 ? 'episode' : 'episodes'}'
      else if (!t.isEmpty)
        '${t.titles} ${t.titles == 1 ? 'show' : 'shows'}',
    ].join('  ·  ');
    final posters = [
      ...f.posterPaths.take(2),
      ...t.posterPaths.take(2),
      ...f.posterPaths.skip(2),
      ...t.posterPaths.skip(2),
    ].take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: GlassPressable(
        onTap: () => _open(context, ref, stats),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.09), width: 0.6),
          ),
          child: Row(
            children: [
              _PosterFan(paths: posters),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text:
                          '${DateFormat('MMMM').format(stats.month)} in review',
                      style: AppText.label.copyWith(
                          color: AppColors.ink, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '\n$summary',
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(CupertinoIcons.chevron_right,
                  size: 15, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, MonthStats stats) {
    showGlassPanel<void>(
      context,
      tall: true,
      // Shared from the profile, which outlives the panel.
      builder: (panel) => _MonthPanel(
        stats: stats,
        onShare: (code) => shareMyProfile(context, ref, initialCode: code),
      ),
    );
  }
}

/// The month's cards, films then TV, one page each.
class _MonthPanel extends ConsumerStatefulWidget {
  const _MonthPanel({required this.stats, required this.onShare});

  final MonthStats stats;

  /// Opens the share sheet on "P2" or "P2S", after the panel has closed.
  final void Function(String code) onShare;

  @override
  ConsumerState<_MonthPanel> createState() => _MonthPanelState();
}

class _MonthPanelState extends ConsumerState<_MonthPanel> {
  late final List<MonthInFilm> _sides = [
    widget.stats.films,
    widget.stats.shows,
  ];

  // Opens on whichever side has something, films first.
  late final PageController _pages =
      PageController(initialPage: widget.stats.films.isEmpty ? 1 : 0);
  late int _page = _pages.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProfileProvider).valueOrNull;
    if (me == null) return const SizedBox.shrink();
    final stats = widget.stats;
    return Column(
      children: [
        GlassPanelHeader(
          title: '${DateFormat('MMMM').format(stats.month)} in review',
          subtitle: stats.isCurrent ? 'So far this month' : null,
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassChip(label: 'Film', selected: _page == 0, onTap: () => _go(0)),
            const SizedBox(width: AppSpace.sm),
            GlassChip(label: 'TV', selected: _page == 1, onTap: () => _go(1)),
          ],
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _sides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xl, vertical: AppSpace.md),
              child: Center(
                child: AspectRatio(
                  aspectRatio: kStoryWidth / kStoryHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FittedBox(
                      child: MonthInFilmCard(
                        user: me,
                        month: _sides[i],
                        tv: _sides[i].isTv,
                        look: const ShareLook(palette: PosterPalette.neutral),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
          child: GlassPillButton(
            label: 'Share',
            icon: CupertinoIcons.square_arrow_up,
            prominent: true,
            expand: true,
            onTap: () {
              final code = _page == 1 ? 'P2S' : 'P2';
              Navigator.of(context).pop();
              widget.onShare(code);
            },
          ),
        ),
      ],
    );
  }
}

class _PosterFan extends StatelessWidget {
  const _PosterFan({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 54,
      child: Stack(
        children: [
          for (var i = paths.length - 1; i >= 0; i--)
            Positioned(
              left: i * 14.0,
              top: 0,
              child: Container(
                width: 36,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.6), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: StoryImage(monthPosterUrl(paths[i])),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
