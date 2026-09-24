import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart' show CommentModel;
import 'comments_sheet.dart' show CommentRow;

/// A flat, oldest-first comment list grouped into one-level threads.
///
/// A reply whose parent isn't in the list (deleted, or past the page) is
/// shown as a top-level comment rather than dropped.
class CommentThreads {
  CommentThreads._(this.roots, this.replies);

  factory CommentThreads.of(List<CommentModel> all) {
    final ids = {for (final c in all) c.id};
    final roots = <CommentModel>[];
    final replies = <String, List<CommentModel>>{};
    for (final c in all) {
      final parent = c.parentId;
      if (parent == null || !ids.contains(parent)) {
        roots.add(c);
      } else {
        (replies[parent] ??= []).add(c);
      }
    }
    return CommentThreads._(roots, replies);
  }

  final List<CommentModel> roots;
  final Map<String, List<CommentModel>> replies;

  bool get isEmpty => roots.isEmpty;
}

/// The thread list as a sliver. Replies start hidden behind
/// "View N replies"; which threads are open is held by the caller, so it can
/// open one itself after the user replies into it.
class SliverCommentThreads extends StatelessWidget {
  const SliverCommentThreads({
    super.key,
    required this.threads,
    required this.expanded,
    required this.onToggle,
    required this.onReply,
    required this.isAuthor,
    required this.onMenu,
  });

  final CommentThreads threads;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final ValueChanged<CommentModel> onReply;
  final bool Function(CommentModel) isAuthor;

  /// The comment's ••• and long-press: delete, or report and block.
  final ValueChanged<CommentModel> onMenu;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: threads.roots.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(left: 44),
        child: Divider(),
      ),
      itemBuilder: (_, i) {
        final root = threads.roots[i];
        final replies = threads.replies[root.id] ?? const <CommentModel>[];
        final open = expanded.contains(root.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(root),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: open
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final r in replies) _row(r, compact: true),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    _RepliesToggle(
                      count: replies.length,
                      open: open,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onToggle(root.id);
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(CommentModel c, {bool compact = false}) => CommentRow(
        comment: c,
        isAuthor: isAuthor(c),
        compact: compact,
        onMenu: () => onMenu(c),
        onReply: () => onReply(c),
      );
}

/// "—— View 3 replies", Instagram's quiet rule-and-label.
class _RepliesToggle extends StatelessWidget {
  const _RepliesToggle({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = open
        ? 'Hide replies'
        : 'View $count ${count == 1 ? 'reply' : 'replies'}';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md, top: 2),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 0.8,
              color: AppColors.inkTertiary,
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: AppColors.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sits above the composer while replying: who to, and a way out.
class ReplyingToBar extends StatelessWidget {
  const ReplyingToBar({
    super.key,
    required this.username,
    required this.onCancel,
  });

  final String username;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg + AppSpace.xs, AppSpace.sm, AppSpace.md, 0),
      child: Row(
        children: [
          const Icon(CupertinoIcons.arrowshape_turn_up_left,
              size: 13, color: AppColors.inkTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Replying to ',
                children: [
                  TextSpan(
                    text: '@$username',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: AppText.caption.copyWith(color: AppColors.inkSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(AppSpace.xs),
              child: Icon(CupertinoIcons.xmark_circle_fill,
                  size: 18, color: AppColors.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
