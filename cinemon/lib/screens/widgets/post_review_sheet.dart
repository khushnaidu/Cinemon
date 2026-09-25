import '../../core/utils/content_refusal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/badge_model.dart';
import '../../models/episode_model.dart';
import '../../models/film_model.dart';
import '../../providers/feed/feed_provider.dart';
import 'episodes_section.dart' show EpisodeStill;
import 'glass_panel.dart';
import 'review_media_composer.dart';
import 'star_input.dart';

/// Open the new-post panel for a film, or for one [episode] of a show.
///
/// A tall glass panel, not a bottom sheet, so it matches the editor and every
/// other surface. Not dismissible by tapping the scrim: a half-written review
/// or a fresh recording shouldn't vanish on a stray touch — Cancel asks.
Future<void> showPostReviewSheet(
  BuildContext context,
  FilmModel film, {
  EpisodeModel? episode,
}) {
  return showGlassPanel<void>(
    context,
    tall: true,
    dismissible: false,
    builder: (_) => PostReviewSheet(film: film, episode: episode),
  );
}

class PostReviewSheet extends ConsumerStatefulWidget {
  final FilmModel film;

  /// When set, the post is about this one episode of [film] (a show).
  final EpisodeModel? episode;

  const PostReviewSheet({super.key, required this.film, this.episode});

  @override
  ConsumerState<PostReviewSheet> createState() => _PostReviewSheetState();
}

class _PostReviewSheetState extends ConsumerState<PostReviewSheet> {
  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isPosting = false;
  ReviewMediaDraft _media = const ReviewMediaDraft();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _rating > 0 ||
      _reviewController.text.trim().isNotEmpty ||
      !_media.isEmpty;

  String get _subject => widget.episode == null
      ? widget.film.displayTitle
      : '${widget.episode!.code} of ${widget.film.displayTitle}';

  Future<void> _close() async {
    if (_isPosting) return;
    if (!_hasContent) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showGlassConfirm(
      context,
      title: 'Discard this post?',
      message: 'Your rating, review and anything you recorded will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep writing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<void> _post() async {
    if (_isPosting) return;
    setState(() => _isPosting = true);

    final notifier = ref.read(createActivityProvider.notifier);
    final text = _reviewController.text.trim();

    // Media makes it a review even with no stars and no text: a spoken take is
    // a review, and posting it as a bare "watched" would throw the recording
    // away.
    final created = _hasContent
        ? await notifier.postReview(
            film: widget.film,
            episode: widget.episode,
            rating: _rating,
            reviewText: text.isNotEmpty ? text : null,
            voiceNote: _media.voiceNote,
            voiceNoteDurationMs: _media.voiceNoteDurationMs,
            voiceNoteWaveform: _media.waveform,
            photos: _media.photos,
          )
        : await notifier.postWatched(
            film: widget.film,
            episode: widget.episode,
          );

    if (!mounted) return;

    if (created == null) {
      setState(() => _isPosting = false);
      showGlassToast(
        context,
        refusalOr("Couldn't post that. Check your connection and try again."),
        destructive: true,
      );
      return;
    }

    // Toast first, then pop: the toast lives in the root overlay and survives
    // this panel going away, but it needs a live context to find it.
    // Badges are awarded by the database as the post lands; the notifier
    // read back which ones this one earned.
    final earned = [
      for (final id in notifier.getAndClearUnlockedBadges())
        if (BadgeRegistry.getBadgeById(id) case final b?) b,
    ];
    showGlassToast(
      context,
      earned.isEmpty
          ? 'Posted $_subject'
          : 'Posted $_subject, and earned ${earned.map((b) => '${b.emoji} ${b.name}').join(', ')}',
      icon: earned.isEmpty ? null : CupertinoIcons.rosette,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;

    return Column(
      children: [
        GlassPanelHeader(
          title: 'New post',
          leadingLabel: 'Cancel',
          onLeading: _close,
          trailingLabel: 'Post',
          trailingEnabled: !_isPosting,
          trailingBusy: _isPosting,
          onTrailing: _post,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xl),
            children: [
              if (episode != null)
                _EpisodeHeader(film: widget.film, episode: episode)
              else
                _FilmHeader(film: widget.film),
              const SizedBox(height: AppSpace.xl),
              const GlassSectionLabel('Rating'),
              const SizedBox(height: AppSpace.sm),
              StarInput(
                rating: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: AppSpace.xl),
              const GlassSectionLabel('Review'),
              const SizedBox(height: AppSpace.sm),
              GlassTextWell(
                controller: _reviewController,
                hint: 'What did you think?',
                maxLength: 500,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.xl),
              ReviewMediaComposer(
                onChanged: (draft) => setState(() => _media = draft),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                _hasContent
                    ? 'Posts as a review.'
                    : 'Posts as watched. Add stars, words, a voice note or a photo to make it a review.',
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilmHeader extends StatelessWidget {
  const _FilmHeader({required this.film});

  final FilmModel film;

  @override
  Widget build(BuildContext context) {
    final meta = [
      film.year,
      film.isMovie ? 'Film' : 'Show',
      film.formattedRuntime,
    ].whereType<String>().join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            child: film.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: film.posterUrl, fit: BoxFit.cover)
                : Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const Icon(CupertinoIcons.film,
                        color: AppColors.inkTertiary),
                  ),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                film.displayTitle,
                style: AppText.title.copyWith(fontSize: 20),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style:
                      AppText.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ],
              if (film.overview != null && film.overview!.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  film.overview!,
                  style: AppText.caption.copyWith(color: AppColors.inkTertiary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeHeader extends StatelessWidget {
  const _EpisodeHeader({required this.film, required this.episode});

  final FilmModel film;
  final EpisodeModel episode;

  @override
  Widget build(BuildContext context) {
    final meta = [
      episode.formattedAirDate,
      episode.formattedRuntime,
    ].whereType<String>().join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            EpisodeStill(path: episode.stillPath, large: true),
            Positioned(
              left: AppSpace.md,
              bottom: AppSpace.md,
              child: GlassTag(episode.code),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          film.displayTitle,
          style: AppText.caption.copyWith(
            color: AppColors.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(episode.displayName, style: AppText.title.copyWith(fontSize: 20)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: AppText.caption.copyWith(color: AppColors.inkSecondary),
          ),
        ],
      ],
    );
  }
}
