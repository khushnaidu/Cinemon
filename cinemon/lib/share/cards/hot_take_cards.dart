import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

/// Type size for a take: a one-liner gets the headline, a paragraph still
/// fits the card.
double _takeSize(String text, {required double large}) {
  final n = text.length;
  if (n <= 90) return large;
  if (n <= 160) return large * 0.8;
  return large * 0.64;
}

String _subjectLine(ExplorePost post) {
  final s = post.subject;
  if (s == null) return 'hot take';
  return 'on ${s.title}';
}

/// H1: the in-app hot take card at full screen. The take over the film's
/// blurred poster, the vote split, and the film it's about.
class HeadlineTakeCard extends StatelessWidget {
  const HeadlineTakeCard({super.key, required this.post, required this.look});

  final ExplorePost post;
  final ShareLook look;

  @override
  Widget build(BuildContext context) {
    final s = post.subject;
    final poster = ApiConstants.getPosterUrl(s?.posterPath,
        size: ApiConstants.posterSizeLarge);
    final tint = look.tint;

    return StoryCanvas(
      background: look.bottom,
      children: [
        if (poster.isNotEmpty)
          StoryBlur(poster)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [look.top, look.bottom],
              ),
            ),
          ),
        if (tint != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withValues(alpha: 0.55),
                  tint.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 21.u,
          bottom: 16.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryAuthor(
                username: post.username,
                photoUrl: post.userPhotoUrl,
                caption: _subjectLine(post),
              ),
              const Spacer(),
              const TakeKicker(),
              SizedBox(height: 3.u),
              Text(
                post.body,
                style: TextStyle(
                  fontSize: _takeSize(post.body, large: 8.8.u),
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.26.u,
                ),
              ),
              SizedBox(height: 6.u),
              TakeSplit(post: post),
              if (s != null) ...[
                SizedBox(height: 6.u),
                _SubjectChip(post: post),
              ],
              const Spacer(),
              const Center(child: StoryBrand()),
            ],
          ),
        ),
      ],
    );
  }
}

/// The flame and "HOT TAKE".
class TakeKicker extends StatelessWidget {
  const TakeKicker({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.flame_fill, size: 3.8.u, color: color),
        SizedBox(width: 1.4.u),
        Text(
          'HOT TAKE',
          style: TextStyle(
            fontSize: 3.2.u,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.45.u,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// The agree / disagree split as a meter, or an invitation to vote when
/// nobody has yet.
class TakeSplit extends StatelessWidget {
  const TakeSplit({super.key, required this.post});

  final ExplorePost post;

  @override
  Widget build(BuildContext context) {
    final share = post.agreeShare;
    final dim = Colors.white.withValues(alpha: 0.55);
    if (share == null) {
      return Text(
        'Agree or disagree? Vote on 35mm.',
        style: TextStyle(fontSize: 4.u, fontWeight: FontWeight.w700),
      );
    }
    final agree = (share * 100).round();
    final votes = NumberFormat.decimalPattern().format(post.totalVotes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 1.4.u,
          child: Row(
            children: [
              Expanded(
                flex: agree.clamp(1, 99),
                child: _bar(Colors.white),
              ),
              SizedBox(width: 0.8.u),
              Expanded(
                flex: (100 - agree).clamp(1, 99),
                child: _bar(Colors.white.withValues(alpha: 0.22)),
              ),
            ],
          ),
        ),
        SizedBox(height: 2.4.u),
        Row(
          children: [
            Text('$agree% agree',
                style: TextStyle(fontSize: 4.u, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${100 - agree}% disagree',
                style: TextStyle(
                    fontSize: 4.u, fontWeight: FontWeight.w700, color: dim)),
          ],
        ),
        SizedBox(height: 1.8.u),
        Text(
          '$votes ${post.totalVotes == 1 ? 'vote' : 'votes'} · vote on 35mm',
          style: TextStyle(
              fontSize: 3.1.u,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _bar(Color c) => Container(
        height: 1.4.u,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(1.u)),
      );
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.post});

  final ExplorePost post;

  @override
  Widget build(BuildContext context) {
    final s = post.subject!;
    return Container(
      padding: EdgeInsets.fromLTRB(2.2.u, 2.2.u, 4.u, 2.2.u),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3.4.u),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.14), width: 0.25.u),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StoryPoster(
            url: s.posterUrl,
            width: 9.u,
            radius: 1.u,
            shadow: false,
          ),
          SizedBox(width: 3.u),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 58.u),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 4.u, fontWeight: FontWeight.w700)),
                SizedBox(height: 0.6.u),
                Text(s.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 3.u,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// H3: the take as a sticker. Only the card itself; the sheet puts it on
/// the gradient, and Instagram lets people move and resize it.
class StickerTakeCard extends StatelessWidget {
  const StickerTakeCard({super.key, required this.post});

  final ExplorePost post;

  @override
  Widget build(BuildContext context) {
    final s = post.subject;
    final poster = ApiConstants.getPosterUrl(s?.posterPath,
        size: ApiConstants.posterSizeLarge);
    final share = post.agreeShare;
    final agree = share == null ? null : (share * 100).round();
    final r = BorderRadius.circular(6.u);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: AppText.body.copyWith(color: Colors.white, height: 1.2),
        child: Container(
          width: 84.u,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.16), width: 0.3.u),
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF121030)),
                ),
                if (poster.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.85,
                      child: StoryBlur(poster, sigma: 30, dim: 0.3),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(5.u),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoryAuthor(
                        username: post.username,
                        photoUrl: post.userPhotoUrl,
                        caption: s == null
                            ? null
                            : [s.title, if ((s.year ?? '').isNotEmpty) s.year]
                                .join(' · '),
                      ),
                      SizedBox(height: 5.u),
                      const TakeKicker(),
                      SizedBox(height: 3.u),
                      Text(
                        post.body,
                        style: TextStyle(
                          fontSize: _takeSize(post.body, large: 6.6.u),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.16.u,
                        ),
                      ),
                      SizedBox(height: 5.u),
                      Row(
                        children: [
                          Expanded(
                            child: _Pill(
                              label: 'Agree',
                              percent: agree,
                              on: true,
                            ),
                          ),
                          SizedBox(width: 2.u),
                          Expanded(
                            child: _Pill(
                              label: 'Disagree',
                              percent: agree == null ? null : 100 - agree,
                              on: false,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.percent, required this.on});

  final String label;
  final int? percent;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9.u,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: on ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(5.u),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.14), width: 0.25.u),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: label),
          if (percent != null)
            TextSpan(
              text: '  $percent%',
              style: TextStyle(
                  fontSize: 3.1.u, color: Colors.white.withValues(alpha: 0.55)),
            ),
        ]),
        style: TextStyle(fontSize: 3.5.u, fontWeight: FontWeight.w600),
      ),
    );
  }
}
