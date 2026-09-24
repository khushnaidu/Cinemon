import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../../providers/explore/explore_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/liquid_glass.dart' show GlassLens;
import '../widgets/star_input.dart';
import 'explore_post_card.dart';
import 'subject_picker.dart';

/// Write a post for Explore.
///
/// [subject] pre-tags a title (posting from a filtered feed); [kind] picks
/// the starting style.
Future<ExplorePost?> showExploreComposer(
  BuildContext context, {
  ExploreSubject? subject,
  ExploreKind kind = ExploreKind.thought,
}) {
  return showGlassPanel<ExplorePost>(
    context,
    tall: true,
    dismissible: false,
    builder: (_) => ExploreComposer(subject: subject, initialKind: kind),
  );
}

/// Edit one of your own posts in the same composer, prefilled.
Future<ExplorePost?> showExploreEditor(BuildContext context, ExplorePost post) {
  return showGlassPanel<ExplorePost>(
    context,
    tall: true,
    dismissible: false,
    builder: (_) => ExploreComposer(
      editing: post,
      subject: post.subject,
      initialKind: post.kind,
    ),
  );
}

class ExploreComposer extends ConsumerStatefulWidget {
  const ExploreComposer({
    super.key,
    this.subject,
    this.initialKind = ExploreKind.thought,
    this.editing,
  });

  final ExploreSubject? subject;
  final ExploreKind initialKind;

  /// The post being edited, or null for a new one. Its kind is fixed: a hot
  /// take's votes mean nothing once it stops being one.
  final ExplorePost? editing;

  @override
  ConsumerState<ExploreComposer> createState() => _ExploreComposerState();
}

class _ExploreComposerState extends ConsumerState<ExploreComposer> {
  late ExploreKind _kind = widget.initialKind;
  late ExploreSubject? _subject = widget.subject;
  final _headline = TextEditingController();
  final _body = TextEditingController();
  double _rating = 0;
  bool _spoilers = false;
  bool _posting = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _headline.text = e.headline ?? '';
      _body.text = e.body;
      _rating = e.rating ?? 0;
      _spoilers = e.hasSpoilers;
    }
    _headline.addListener(_refresh);
    _body.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _headline.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _bodyText => _body.text.trim();
  String get _headlineText => _headline.text.trim();

  /// Why Post is disabled, or null when it isn't. Shown under the form so a
  /// greyed-out button never leaves someone guessing.
  String? get _blocker {
    if (_kind.needsSubject && _subject == null) {
      return 'Tag the film, show or episode you\'re reviewing.';
    }
    if (_kind.hasRating && _rating == 0) return 'Give it a rating.';
    if (_kind.needsHeadline && _headlineText.isEmpty) {
      return 'Give your critique a title.';
    }
    if (_bodyText.isEmpty) return null; // obvious; no nagging
    if (_bodyText.characters.length > _kind.maxLength) {
      return '${_kind.label}s are capped at ${_kind.maxLength} characters.';
    }
    return null;
  }

  bool get _canPost =>
      !_posting &&
      _bodyText.isNotEmpty &&
      _blocker == null &&
      (!_isEdit || _dirty);

  bool get _dirty {
    final e = widget.editing;
    if (e == null) {
      return _bodyText.isNotEmpty ||
          _headlineText.isNotEmpty ||
          _rating > 0 ||
          _subject != widget.subject;
    }
    return _bodyText != e.body ||
        _headlineText != (e.headline ?? '') ||
        _rating != (e.rating ?? 0) ||
        _spoilers != e.hasSpoilers ||
        _subject != e.subject;
  }

  void _setKind(ExploreKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() => _kind = kind);
  }

  Future<void> _pickSubject() async {
    FocusScope.of(context).unfocus();
    final picked = await showSubjectPicker(context);
    if (picked != null && mounted) setState(() => _subject = picked);
  }

  Future<void> _post() async {
    if (!_canPost) return;
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);

    final actions = ref.read(exploreActionsProvider);
    final headline = _kind.hasHeadline ? _headlineText : null;
    final rating = _kind.hasRating && _rating > 0 ? _rating : null;
    final editing = widget.editing;

    final post = editing == null
        ? await actions.createPost(
            kind: _kind,
            body: _bodyText,
            headline: headline,
            rating: rating,
            hasSpoilers: _spoilers,
            subject: _subject,
          )
        : await actions.updatePost(
            editing,
            body: _bodyText,
            headline: headline,
            rating: rating,
            hasSpoilers: _spoilers,
            subject: _subject,
          );

    if (!mounted) return;
    setState(() => _posting = false);

    if (post == null) {
      showGlassToast(
        context,
        _isEdit
            ? "Couldn't save those changes. Try again in a moment."
            : "Couldn't post that. Try again in a moment.",
        destructive: true,
      );
      return;
    }
    showGlassToast(context, _isEdit ? 'Post updated' : 'Posted to Explore');
    Navigator.of(context).pop(post);
  }

  Future<void> _cancel() async {
    if (_posting) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showGlassConfirm(
      context,
      title: _isEdit ? 'Discard changes?' : 'Discard post?',
      message: _isEdit
          ? 'Your edits to this post will be lost.'
          : 'What you\'ve written will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep writing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final blocker = _blocker;

    return Column(
      children: [
        GlassPanelHeader(
          title: _isEdit ? 'Edit post' : 'New post',
          leadingLabel: 'Cancel',
          onLeading: _cancel,
          trailingLabel: _isEdit ? 'Save' : 'Post',
          trailingEnabled: _canPost,
          trailingBusy: _posting,
          onTrailing: _post,
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(0, AppSpace.xs, 0, AppSpace.xl),
            children: [
              // Style: the five kinds as tiles. Fixed once posted.
              if (_isEdit)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                  child: Row(
                    children: [
                      Icon(_kind.icon, size: 14, color: AppColors.inkSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _kind.label,
                        style: AppText.label.copyWith(
                          fontSize: 14,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    itemCount: ExploreKind.values.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpace.sm),
                    itemBuilder: (_, i) {
                      final k = ExploreKind.values[i];
                      return _KindTile(
                        kind: k,
                        selected: k == _kind,
                        onTap: () => _setKind(k),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl, AppSpace.sm, AppSpace.xl, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _kind.description,
                      key: ValueKey(_kind),
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.lg),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // What it's about.
                    GlassSectionLabel(
                      _kind.needsSubject ? 'Reviewing' : 'About',
                      trailing: _kind.needsSubject
                          ? null
                          : Text(
                              'Optional',
                              style: AppText.footnote
                                  .copyWith(color: AppColors.inkTertiary),
                            ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    if (_subject == null)
                      _TagRow(onTap: _pickSubject)
                    else
                      SubjectChip(
                        subject: _subject!,
                        onTap: _pickSubject,
                        trailing: GestureDetector(
                          onTap: () => setState(() => _subject = null),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpace.xs),
                            child: Icon(CupertinoIcons.xmark_circle_fill,
                                size: 20, color: AppColors.inkTertiary),
                          ),
                        ),
                      ),

                    if (_kind.hasRating) ...[
                      const SizedBox(height: AppSpace.xl),
                      const GlassSectionLabel('Rating'),
                      const SizedBox(height: AppSpace.sm),
                      StarInput(
                        rating: _rating,
                        onChanged: (v) => setState(() => _rating = v),
                      ),
                    ],

                    const SizedBox(height: AppSpace.xl),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _kind.hasHeadline
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpace.sm),
                              child: GlassTextWell(
                                controller: _headline,
                                hint: 'Title',
                                maxLength: 120,
                                minLines: 1,
                                maxLines: 3,
                                style: exploreHeadlineStyle(),
                                textCapitalization: TextCapitalization.words,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    // The body, set in the kind's own type.
                    GlassTextWell(
                      controller: _body,
                      hint: _hint(_kind),
                      maxLength: _kind.maxLength,
                      minLines: _kind == ExploreKind.critique ? 10 : 4,
                      maxLines: _kind == ExploreKind.critique ? 40 : 12,
                      style: exploreBodyStyle(_kind),
                    ),

                    const SizedBox(height: AppSpace.lg),
                    _SpoilerRow(
                      value: _spoilers,
                      onChanged: (v) => setState(() => _spoilers = v),
                    ),

                    const SizedBox(height: AppSpace.lg),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        blocker ??
                            (_isEdit
                                ? 'Edited posts are marked as edited.'
                                : 'Posts publicly to Explore.'),
                        key: ValueKey(blocker),
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: AppColors.inkTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _hint(ExploreKind kind) => switch (kind) {
        ExploreKind.thought => 'What\'s on your mind?',
        ExploreKind.take => 'Say the thing everyone\'s afraid to say.',
        ExploreKind.review => 'What did you think?',
        ExploreKind.critique => 'Make your argument.',
        ExploreKind.discussion => 'Ask everyone something.',
      };
}

/// One kind in the style strip. Selected is the glass lens.
class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ExploreKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return GlassPressable(
      onTap: onTap,
      child: Container(
        width: 84,
        decoration: glassWellDecoration(radius: 18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0,
              child: GlassLens(radius: radius),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  kind.icon,
                  size: 22,
                  color: selected ? AppColors.ink : AppColors.inkSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  kind.label,
                  style: AppText.footnote.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.ink : AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tag a film, show or episode" — the empty state of the subject slot.
class _TagRow extends StatelessWidget {
  const _TagRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      child: Container(
        height: 61,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: glassWellDecoration(radius: AppRadius.md + 2),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
              child: const Icon(CupertinoIcons.plus,
                  size: 14, color: AppColors.inkSecondary),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                'Tag a film, show or episode',
                style: AppText.body.copyWith(color: AppColors.inkSecondary),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

class _SpoilerRow extends StatelessWidget {
  const _SpoilerRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
      decoration: glassWellDecoration(radius: AppRadius.md + 2),
      child: Row(
        children: [
          const Icon(CupertinoIcons.eye_slash,
              size: 18, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contains spoilers',
                  style: AppText.body.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 1),
                Text(
                  'Blurred until someone taps to reveal.',
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.white.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }
}
