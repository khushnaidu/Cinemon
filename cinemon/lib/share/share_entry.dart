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

/// This month, on your own profile: the month's posters and count, opening
/// the full Month in film card (ADR 0003 §6).
class MonthInFilmTile extends ConsumerWidget {
  const MonthInFilmTile({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final m = ref
        .watch(monthInFilmProvider(
            (userId: userId, year: now.year, month: now.month)))
        .valueOrNull;
    if (m == null || m.isEmpty) return const SizedBox.shrink();

    final count = m.films > 0
        ? '${m.films} ${m.films == 1 ? 'film' : 'films'}'
        : '${m.episodes} ${m.episodes == 1 ? 'episode' : 'episodes'}';
    final hours = m.hours >= 1 ? '  ·  ${m.hours.round()} h' : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: GlassPressable(
        onTap: () => _open(context, ref, m),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.09), width: 0.6),
          ),
          child: Row(
            children: [
              _PosterFan(paths: m.posterPaths.take(3).toList()),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('MMMM').format(m.month)} in film',
                      style: AppText.headline.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count$hours',
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
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

  void _open(BuildContext context, WidgetRef ref, MonthInFilm m) {
    showGlassPanel<void>(
      context,
      tall: true,
      builder: (panel) => Consumer(
        builder: (panel, ref, _) {
          final me = ref.watch(currentUserProfileProvider).valueOrNull;
          if (me == null) return const SizedBox.shrink();
          return Column(
            children: [
              GlassPanelHeader(
                title: '${DateFormat('MMMM').format(m.month)} in film',
                subtitle: m.isCurrent ? 'So far this month' : null,
                trailingLabel: 'Done',
                onTrailing: () => Navigator.of(panel).pop(),
              ),
              Expanded(
                child: Padding(
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
                            month: m,
                            look:
                                const ShareLook(palette: PosterPalette.neutral),
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
                    Navigator.of(panel).pop();
                    shareMyProfile(context, ref, initialCode: 'P2');
                  },
                ),
              ),
            ],
          );
        },
      ),
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
