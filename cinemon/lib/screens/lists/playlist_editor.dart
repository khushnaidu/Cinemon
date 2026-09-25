import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart' show ExploreKind;
import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../providers/explore/explore_provider.dart';
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';
import 'playlist_cover.dart';

/// What the editor did, so the caller can follow up (open the new list,
/// leave a deleted one).
sealed class PlaylistEditResult {
  const PlaylistEditResult();
}

class PlaylistSaved extends PlaylistEditResult {
  const PlaylistSaved(this.list);
  final FilmList list;
}

class PlaylistDeleted extends PlaylistEditResult {
  const PlaylistDeleted();
}

/// Create a playlist, or edit one when [editing] is given.
///
/// [first] is a title to put on a new playlist straight away (from Add to…);
/// [posters] are an existing list's first posters, for the preview.
Future<PlaylistEditResult?> showPlaylistEditor(
  BuildContext context, {
  FilmList? editing,
  List<String?> posters = const [],
  FilmModel? first,
}) {
  return showGlassPanel<PlaylistEditResult>(
    context,
    tall: true,
    dismissible: false,
    builder: (_) => _PlaylistEditor(
      editing: editing,
      posters: [
        if (first != null) first.posterPath,
        ...posters,
      ],
      first: first,
    ),
  );
}

class _PlaylistEditor extends ConsumerStatefulWidget {
  const _PlaylistEditor({
    required this.editing,
    required this.posters,
    required this.first,
  });

  final FilmList? editing;
  final List<String?> posters;
  final FilmModel? first;

  @override
  ConsumerState<_PlaylistEditor> createState() => _PlaylistEditorState();
}

class _PlaylistEditorState extends ConsumerState<_PlaylistEditor> {
  late final _title = TextEditingController(text: widget.editing?.title);
  late final _description =
      TextEditingController(text: widget.editing?.description);
  late ListVisibility _visibility =
      widget.editing?.visibility ?? ListVisibility.public;
  bool _busy = false;

  /// New public playlists go on Explore unless this is switched off. The
  /// card's cover follows the list, so it fills in as films are added.
  bool _shareToExplore = true;

  bool get _isNew => widget.editing == null;
  String get _titleText => _title.text.trim();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleText.isEmpty) return;
    setState(() => _busy = true);
    final actions = ref.read(playlistActionsProvider);
    final description =
        _description.text.trim().isEmpty ? null : _description.text.trim();

    final FilmList? saved;
    if (_isNew) {
      saved = await actions.create(
        title: _titleText,
        description: description,
        visibility: _visibility,
        first: widget.first,
      );
    } else {
      final ok = await actions.update(
        widget.editing!,
        title: _titleText,
        description: description,
        visibility: _visibility,
      );
      saved = ok ? widget.editing : null;
    }
    if (!mounted) return;
    if (saved == null) {
      setState(() => _busy = false);
      showGlassToast(context, "Couldn't save your playlist.",
          destructive: true);
      return;
    }
    if (_isNew && _shareToExplore && _visibility == ListVisibility.public) {
      // Best effort: the playlist exists either way, and it can be posted
      // from its own screen later.
      await ref.read(exploreActionsProvider).createPost(
            kind: ExploreKind.list,
            body: '',
            listId: saved.id,
          );
      if (!mounted) return;
    }
    Navigator.of(context).pop(PlaylistSaved(saved));
  }

  Future<void> _delete() async {
    final ok = await showGlassConfirm(
      context,
      title: 'Delete playlist?',
      message: '"${widget.editing!.displayTitle}" will be gone for everyone '
          'who saved it. The films themselves stay in your logs.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done =
        await ref.read(playlistActionsProvider).delete(widget.editing!);
    if (!mounted) return;
    if (!done) {
      setState(() => _busy = false);
      showGlassToast(context, "Couldn't delete it.", destructive: true);
      return;
    }
    Navigator.of(context).pop(const PlaylistDeleted());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListenableBuilder(
          listenable: _title,
          builder: (_, __) => GlassPanelHeader(
            title: _isNew ? 'New playlist' : 'Edit playlist',
            leadingLabel: 'Cancel',
            onLeading: _busy ? null : () => Navigator.of(context).pop(),
            trailingLabel: _isNew ? 'Create' : 'Save',
            onTrailing: _save,
            trailingEnabled: !_busy && _titleText.isNotEmpty,
            trailingBusy: _busy,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // The live preview: the fun moment.
              Center(
                child: PlaylistCover(posters: widget.posters, size: 150),
              ),
              const SizedBox(height: AppSpace.md),
              ListenableBuilder(
                listenable: _title,
                builder: (_, __) => Text(
                  _titleText.isEmpty ? 'Untitled' : _titleText,
                  style: AppText.title.copyWith(
                    color: _titleText.isEmpty
                        ? AppColors.inkTertiary
                        : AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.first != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Starting with ${widget.first!.displayTitle}',
                  style:
                      AppText.footnote.copyWith(color: AppColors.inkSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              const GlassSectionLabel('Title'),
              const SizedBox(height: AppSpace.sm),
              GlassTextWell(
                controller: _title,
                hint: 'Films to watch on a rainy day',
                minLines: 1,
                maxLines: 2,
                maxLength: 80,
                autofocus: _isNew,
              ),
              const SizedBox(height: AppSpace.lg),
              const GlassSectionLabel('Description'),
              const SizedBox(height: AppSpace.sm),
              GlassTextWell(
                controller: _description,
                hint: 'Optional',
                minLines: 2,
                maxLines: 6,
                maxLength: 500,
              ),
              const SizedBox(height: AppSpace.lg),
              const GlassSectionLabel('Who can see it'),
              const SizedBox(height: AppSpace.sm),
              GlassSegmentedControl(
                labels: [for (final v in ListVisibility.values) v.label],
                index: _visibility.index,
                onChanged: (i) =>
                    setState(() => _visibility = ListVisibility.values[i]),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                _visibility.detail,
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
                textAlign: TextAlign.center,
              ),
              if (_isNew && _visibility == ListVisibility.public) ...[
                const SizedBox(height: AppSpace.lg),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
                  decoration: glassWellDecoration(radius: AppRadius.md + 2),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.globe,
                          size: 18, color: AppColors.inkSecondary),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Share to Explore',
                                style: AppText.body
                                    .copyWith(color: AppColors.ink)),
                            const SizedBox(height: 1),
                            Text(
                              'Your followers see it on Home too.',
                              style: AppText.caption.copyWith(
                                  fontSize: 12, color: AppColors.inkTertiary),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _shareToExplore,
                        onChanged: (v) => setState(() => _shareToExplore = v),
                        activeTrackColor: Colors.white.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_isNew) ...[
                const SizedBox(height: AppSpace.xxl),
                GlassPillButton(
                  label: 'Delete playlist',
                  icon: CupertinoIcons.trash,
                  destructive: true,
                  expand: true,
                  onTap: _busy ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
