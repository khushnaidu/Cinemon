import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../month_stats.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

/// Small posters for the month grid.
String monthPosterUrl(String path) =>
    ApiConstants.getPosterUrl(path, size: ApiConstants.posterSizeSmall);

String _compact(int n) => n >= 1000
    ? NumberFormat.compact().format(n).toLowerCase()
    : NumberFormat.decimalPattern().format(n);

TextStyle _helv(double size, FontWeight w,
        {double height = 1.2, double? spacing, Color color = Colors.white}) =>
    TextStyle(
      fontFamily: kHelvetica,
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: spacing,
      color: color,
    );

/// P1: your profile header as it looks in the app. The arch photo with its
/// gold glow, the Siberian username, 3D Isometric counts, and your Top 3
/// large underneath, on a plain dark ground.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.profile});

  final ProfileShare profile;

  @override
  Widget build(BuildContext context) {
    final user = profile.user;
    final top = profile.top3;
    final bio = (user.bio ?? '').trim();

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: 'Isometric3D',
                      fontSize: 8.u,
                      height: 1,
                      color: Colors.white)),
              SizedBox(height: 2.4.u),
              Text(label,
                  style: _helv(3.u, FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.54))),
            ],
          ),
        );

    Widget ranked(int rank) {
      final f = top[rank - 1];
      final w = rank == 1 ? 26.u : 22.u;
      return Padding(
        padding: EdgeInsets.only(top: rank == 1 ? 0 : 3.u),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            StoryPoster(url: profile.posterOf(f), width: w, radius: 2.4.u),
            Positioned(
              bottom: -5.u,
              child: Image.asset('assets/share/top3_rank$rank.png',
                  width: 11.u, height: 11.u, fit: BoxFit.contain),
            ),
          ],
        ),
      );
    }

    return StoryCanvas(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.56),
              radius: 0.9,
              colors: [Color(0xFF141733), Colors.black],
              stops: [0, 0.7],
            ),
          ),
        ),
        const StoryGrain(),
        Positioned(
          left: 32.u,
          width: 36.u,
          top: 20.u,
          height: 46.u,
          child: _Arch(photoUrl: user.photoUrl, username: user.username),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 59.u,
          child: Text(
            '@${user.username}',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Siberian',
              fontSize: 11.u,
              height: 1,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: Offset(0, 0.8.u),
                  blurRadius: 3.u,
                ),
              ],
            ),
          ),
        ),
        if (bio.isNotEmpty)
          Positioned(
            left: 10.u,
            right: 10.u,
            top: 73.u,
            child: Text(
              bio,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _helv(3.7.u, FontWeight.w400,
                  height: 1.35, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        Positioned(
          left: 10.u,
          right: 10.u,
          top: 82.u,
          child: Row(
            children: [
              stat(_compact(profile.logged), 'Logged'),
              stat(_compact(user.reviewCount), 'Reviews'),
              stat(_compact(user.followerCount), 'Followers'),
            ],
          ),
        ),
        if (top.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 101.u,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (top.length > 1) ...[ranked(2), SizedBox(width: 4.u)],
                ranked(1),
                if (top.length > 2) ...[SizedBox(width: 4.u), ranked(3)],
              ],
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17.u,
          child: Center(
            child: Container(
              padding: EdgeInsets.fromLTRB(2.6.u, 2.2.u, 5.u, 2.2.u),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.u),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/share/mark.png', width: 7.u, height: 7.u),
                  SizedBox(width: 1.4.u),
                  Text('Follow me on 35mm',
                      style: _helv(3.8.u, FontWeight.w700,
                          height: 1, spacing: -0.04.u, color: Colors.black)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The profile photo in the app's arch, with its gold glow
/// (`arch_profile_frame.dart`).
class _Arch extends StatelessWidget {
  const _Arch({required this.photoUrl, required this.username});

  final String? photoUrl;
  final String username;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.vertical(top: Radius.circular(18.u));
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.42),
            blurRadius: 8.u,
          ),
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
            blurRadius: 1.6.u,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: (photoUrl ?? '').isEmpty
            ? ColoredBox(
                color: AppColors.surfaceElevated,
                child: Center(
                  child: Text(
                    username.isEmpty ? '?' : username[0].toUpperCase(),
                    style: _helv(14.u, FontWeight.w700),
                  ),
                ),
              )
            : StoryImage(photoUrl!, alignment: const Alignment(0, -0.4)),
      ),
    );
  }
}

/// P2 as a story: the month card for [profile]'s month, once it's counted.
class MonthInFilmStory extends ConsumerWidget {
  const MonthInFilmStory(
      {super.key, required this.profile, required this.look});

  final ProfileShare profile;
  final ShareLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(monthInFilmProvider(profile.monthKey)).valueOrNull;
    return MonthInFilmCard(user: profile.user, month: month, look: look);
  }
}

/// P2: one big number, the month's posters, and four facts separated by
/// hairlines. The same card sits on your profile. [month] is null while
/// it's still being counted.
class MonthInFilmCard extends StatelessWidget {
  const MonthInFilmCard({
    super.key,
    required this.user,
    required this.month,
    required this.look,
  });

  final UserModel user;
  final MonthInFilm? month;
  final ShareLook look;

  @override
  Widget build(BuildContext context) {
    final m = month;
    final monthName = m == null
        ? ''
        : '${DateFormat('MMMM yyyy').format(m.month)}${m.isCurrent ? ' so far' : ''}';
    final films = m?.films ?? 0;
    final lead = m == null
        ? '–'
        : films > 0
            ? '$films'
            : '${m.episodes}';
    final leadLabel = m == null
        ? ''
        : films > 0
            ? (films == 1 ? 'film' : 'films')
            : (m.episodes == 1 ? 'episode' : 'episodes');
    final hours = m == null ? '' : _hours(m);

    final rows = <(String, Widget)>[
      if (m?.topGenre != null)
        (
          'Top genre',
          _value('${m!.topGenre}, ${(m.topGenreShare * 100).round()}%')
        ),
      if (m?.mostWatched != null)
        ('Most watched', _value('${m!.mostWatched} ×${m.mostWatchedCount}')),
      if (m?.highestRated != null)
        (
          'Highest rated',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _value(m!.highestRated!)),
              SizedBox(width: 1.4.u),
              StoryStars(rating: m.highestRating ?? 0, size: 3.4.u),
            ],
          )
        ),
      if (m?.hottestTakeAgree != null)
        ('Hottest take', _value('${m!.hottestTakeAgree}% agreed')),
    ];

    final a = look.tint ?? look.palette.primary;
    final b = look.palette.secondary;

    return StoryCanvas(
      children: [
        Positioned(
          left: -20.u,
          top: 60.u,
          width: 80.u,
          height: 80.u,
          child: _Glow(color: a),
        ),
        Positioned(
          right: -20.u,
          top: 70.u,
          width: 80.u,
          height: 80.u,
          child: _Glow(color: b),
        ),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 20.u,
          bottom: 16.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$monthName · @${user.username}'.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _helv(3.u, FontWeight.w600,
                    spacing: 0.48.u,
                    color: Colors.white.withValues(alpha: 0.6)),
              ),
              SizedBox(height: 1.6.u),
              Text('My month in film',
                  style: _helv(8.6.u, FontWeight.w700,
                      height: 1, spacing: -0.3.u)),
              SizedBox(height: 4.u),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(lead,
                      style: _helv(27.u, FontWeight.w700,
                          height: 0.78, spacing: -1.6.u)),
                  SizedBox(width: 4.u),
                  Padding(
                    padding: EdgeInsets.only(bottom: 0.4.u),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: leadLabel,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        if (hours.isNotEmpty) TextSpan(text: '\n$hours'),
                      ]),
                      style: _helv(4.u, FontWeight.w500,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.u),
              if (m != null && m.isEmpty)
                Text(
                  'Nothing logged yet. Log a film and it lands here.',
                  style: _helv(4.u, FontWeight.w400,
                      height: 1.35, color: Colors.white.withValues(alpha: 0.6)),
                )
              else
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 1.6.u,
                  crossAxisSpacing: 1.6.u,
                  childAspectRatio: 2 / 3,
                  children: [
                    for (final p in (m?.posterPaths ?? const <String>[]))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1.u),
                        child: StoryImage(monthPosterUrl(p)),
                      ),
                  ],
                ),
              SizedBox(height: 5.u),
              for (final (label, value) in rows)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 2.3.u),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 0.2.u),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(label,
                          style: _helv(3.5.u, FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.55))),
                      SizedBox(width: 3.u),
                      Expanded(
                        child: Align(
                            alignment: Alignment.centerRight, child: value),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              const Center(child: StoryBrand()),
            ],
          ),
        ),
      ],
    );
  }

  static String _hours(MonthInFilm m) {
    final h = m.hours;
    if (h < 1) return '${m.minutes} minutes watched';
    final text = h >= 10 || h == h.roundToDouble()
        ? h.round().toString()
        : h.toStringAsFixed(1);
    return '$text ${text == '1' ? 'hour' : 'hours'} watched';
  }

  static Widget _value(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: _helv(3.5.u, FontWeight.w600),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
