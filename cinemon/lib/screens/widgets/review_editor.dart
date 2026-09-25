import '../../core/utils/content_refusal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../providers/feed/feed_provider.dart';
import 'glass_panel.dart';
import 'review_media_composer.dart';
import 'star_input.dart';

/// Open the editor for one of your own posts.
///
/// A tall glass panel on the root navigator, the same surface as the new-post
/// panel. It covers the shell's floating chrome (platform views draw above
/// every Flutter layer, so the shell unmounts them under any root route).
/// Not dismissible from the scrim: Cancel is guarded so a swipe or stray tap
/// can't bin a recording.
Future<void> showReviewEditor(BuildContext context, ActivityModel activity) {
  return showGlassPanel<void>(
    context,
    tall: true,
    dismissible: false,
    builder: (_) => ReviewEditor(activity: activity),
  );
}

class ReviewEditor extends ConsumerStatefulWidget {
  const ReviewEditor({super.key, required this.activity});

  final ActivityModel activity;

  @override
  ConsumerState<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<ReviewEditor> {
  late double _rating = widget.activity.rating ?? 0;
  late final TextEditingController _review =
      TextEditingController(text: widget.activity.reviewText ?? '');

  late ReviewMediaDraft _media = ReviewMediaDraft(
    keptVoiceNoteUrl: widget.activity.voiceNoteUrl,
    voiceNoteDurationMs: widget.activity.voiceNoteDurationMs,
    waveform: widget.activity.voiceNoteWaveform,
    keptPhotoUrls: widget.activity.photoUrls,
  );

  bool _saving = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  bool get _dirty {
    final a = widget.activity;
    if (_rating != (a.rating ?? 0)) return true;
    if (_review.text.trim() != (a.reviewText ?? '')) return true;
    if (_media.voiceNote != null) return true;
    if (_media.keptVoiceNoteUrl != a.voiceNoteUrl) return true;
    if (_media.photos.isNotEmpty) return true;
    if (_media.keptPhotoUrls.length != a.photoUrls.length) return true;
    return false;
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);

    final ok = await ref.read(createActivityProvider.notifier).updateActivity(
          activity: widget.activity,
          newRating: _rating > 0 ? _rating : null,
          newReviewText:
              _review.text.trim().isNotEmpty ? _review.text.trim() : null,
          media: ReviewMediaEdit(
            keptVoiceNoteUrl: _media.keptVoiceNoteUrl,
            newVoiceNote: _media.voiceNote,
            newVoiceNoteDurationMs: _media.voiceNoteDurationMs,
            newWaveform: _media.waveform,
            keptPhotoUrls: _media.keptPhotoUrls,
            newPhotos: _media.photos,
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // Toast before pop: it lives in the root overlay and outlives this
      // panel, but needs a live context to find it.
      showGlassToast(context, 'Post updated');
      Navigator.of(context).pop();
    } else {
      showGlassToast(
        context,
        refusalOr("Couldn't save those changes. Try again in a moment."),
        destructive: true,
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Delete post?',
      message: 'This removes your post for "${widget.activity.displayTitle}", '
          'along with anything you recorded or photographed for it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    await ref.read(createActivityProvider.notifier).deleteActivity(
          widget.activity.id,
          isReview: widget.activity.activityType == ActivityType.reviewed,
          filmId: widget.activity.filmId,
        );

    if (!mounted) return;
    showGlassToast(context, 'Post deleted', icon: CupertinoIcons.trash);
    Navigator.of(context).pop();
  }

  Future<void> _closeGuarded() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showGlassConfirm(
      context,
      title: 'Discard changes?',
      message: 'Your edits to this post will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final poster = ApiConstants.getPosterUrl(
      widget.activity.filmPosterPath,
      size: ApiConstants.posterSizeMedium,
    );

    return Column(
      children: [
        GlassPanelHeader(
          title: 'Edit post',
          leadingLabel: 'Cancel',
          onLeading: _closeGuarded,
          trailingLabel: 'Save',
          trailingEnabled: _dirty && !_saving,
          trailingBusy: _saving,
          onTrailing: _save,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xl),
            children: [
              _FilmHeader(activity: widget.activity, posterUrl: poster),
              const SizedBox(height: AppSpace.xl),
              const GlassSectionLabel('Rating'),
              const SizedBox(height: AppSpace.sm),
              StarInput(
                rating: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: AppSpace.xl),
              const GlassSectionLabel('Review'),
              const SizedBox(height: AppSpace.sm),
              GlassTextWell(
                controller: _review,
                hint: 'What did you think?',
                maxLength: 500,
                minLines: 5,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.xl),
              ReviewMediaComposer(
                initialVoiceNoteUrl: widget.activity.voiceNoteUrl,
                initialVoiceNoteDurationMs: widget.activity.voiceNoteDurationMs,
                initialWaveform: widget.activity.voiceNoteWaveform,
                initialPhotoUrls: widget.activity.photoUrls,
                onChanged: (draft) => setState(() => _media = draft),
              ),
              const SizedBox(height: AppSpace.xxl),
              GlassPillButton(
                label: 'Delete post',
                icon: CupertinoIcons.trash,
                destructive: true,
                expand: true,
                onTap: _saving ? null : _confirmDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilmHeader extends StatelessWidget {
  const _FilmHeader({required this.activity, required this.posterUrl});

  final ActivityModel activity;
  final String posterUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 84,
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
            child: posterUrl.isEmpty
                ? Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const Icon(
                      CupertinoIcons.film,
                      color: AppColors.inkTertiary,
                    ),
                  )
                : CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.displayTitle,
                style: AppText.title.copyWith(
                  color: AppColors.ink,
                  fontSize: 19,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (activity.isEpisode) activity.episodeCode,
                  if (activity.isEpisode) activity.filmTitle,
                  if (!activity.isEpisode) activity.filmYear,
                  activity.relativeTime,
                ].whereType<String>().join('  ·  '),
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
