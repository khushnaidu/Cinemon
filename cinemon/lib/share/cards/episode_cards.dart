import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

/// E1: the front of the in-app episode card, lifted out onto the still's own
/// colour: the still with its "S2 E6" tag, the show, then the episode.
class EpisodeCardStory extends StatelessWidget {
  const EpisodeCardStory(
      {super.key, required this.episode, required this.look});

  final EpisodeShare episode;
  final ShareLook look;

  @override
  Widget build(BuildContext context) {
    final tint = look.tint;
    final text = (episode.text ?? '').trim();
    final title = (episode.episodeTitle ?? '').isNotEmpty
        ? episode.episodeTitle!
        : 'Episode ${episode.episodeNumber}';

    return StoryCanvas(
      children: [
        StoryBlur(episode.paletteUrl, dim: 0.45),
        if (tint != null) ColoredBox(color: tint.withValues(alpha: 0.35)),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          top: 21.u,
          child: StoryAuthor(
            username: episode.username,
            photoUrl: episode.userPhotoUrl,
            caption: 'reviewed an episode',
          ),
        ),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 33.u,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(5.u),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 0.25.u),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 14.u,
                  offset: Offset(0, 5.u),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5.u),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StoryImage(episode.stillUrl.isNotEmpty
                            ? episode.stillUrl
                            : episode.posterUrl),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                AppColors.surface.withValues(alpha: 0.95),
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 3.4.u,
                          top: 3.4.u,
                          child: _Tag(episode.code),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(5.u, 1.u, 5.u, 5.4.u),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StoryPoster(
                              url: episode.posterUrl,
                              width: 9.6.u,
                              radius: 1.2.u,
                              shadow: false,
                            ),
                            SizedBox(width: 3.4.u),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    episode.showTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 4.4.u,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1),
                                  ),
                                  SizedBox(height: 0.6.u),
                                  Text(
                                    'Season ${episode.seasonNumber}  ·  Episode ${episode.episodeNumber}',
                                    style: TextStyle(
                                      fontSize: 3.u,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.18.u,
                                      color: AppColors.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5.u),
                        Text(
                          'EPISODE',
                          style: TextStyle(
                            fontSize: 2.9.u,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.46.u,
                            color: AppColors.inkTertiary,
                          ),
                        ),
                        SizedBox(height: 1.4.u),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.u,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.27.u,
                            height: 1,
                          ),
                        ),
                        if (episode.rating != null) ...[
                          SizedBox(height: 3.u),
                          StoryStars(rating: episode.rating!, size: 4.6.u),
                        ],
                        if (text.isNotEmpty) ...[
                          SizedBox(height: 3.u),
                          Text(
                            text,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 3.9.u,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17.u,
          child: const Center(child: StoryBrand()),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.6.u, vertical: 1.4.u),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5.u),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3), width: 0.25.u),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 3.u,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.18.u,
          height: 1,
        ),
      ),
    );
  }
}

/// E2: the still fills the story, and the show and episode are set straight
/// on it in plain Helvetica, with no bands behind the type.
class FullBleedEpisodeCard extends StatelessWidget {
  const FullBleedEpisodeCard({super.key, required this.episode});

  final EpisodeShare episode;

  @override
  Widget build(BuildContext context) {
    final text = (episode.text ?? '').trim();
    final still = episode.stillUrlFull.isNotEmpty
        ? episode.stillUrlFull
        : episode.posterUrl;
    final sub = [
      episode.code,
      if ((episode.episodeTitle ?? '').isNotEmpty) episode.episodeTitle,
    ].join('  ·  ');
    TextStyle helv(double size, FontWeight w,
            {double height = 1.2, double? spacing, double alpha = 1}) =>
        TextStyle(
          fontFamily: kHelvetica,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: Colors.white.withValues(alpha: alpha),
        );

    return StoryCanvas(
      children: [
        StoryImage(still, alignment: const Alignment(0.24, 0)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.92),
              ],
              stops: const [0, 0.3, 0.42, 0.72],
            ),
          ),
        ),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          top: 21.u,
          child: Text('Episode review',
              style: helv(3.2.u, FontWeight.w500, alpha: 0.85)),
        ),
        Positioned(
          left: 7.u,
          right: 7.u,
          bottom: 16.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode.showTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    helv(13.u, FontWeight.w700, height: 0.95, spacing: -0.58.u),
              ),
              SizedBox(height: 2.2.u),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: helv(4.6.u, FontWeight.w400,
                      spacing: -0.05.u, alpha: 0.72)),
              if (episode.rating != null) ...[
                SizedBox(height: 3.4.u),
                StoryStars(rating: episode.rating!, size: 5.4.u),
              ],
              if (text.isNotEmpty) ...[
                SizedBox(height: 3.4.u),
                Text(
                  text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style:
                      helv(4.4.u, FontWeight.w400, height: 1.35, alpha: 0.92),
                ),
              ],
              SizedBox(height: 3.4.u),
              Row(
                children: [
                  StoryAuthor(
                    username: episode.username,
                    photoUrl: episode.userPhotoUrl,
                  ),
                  const Spacer(),
                  const StoryBrand(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
