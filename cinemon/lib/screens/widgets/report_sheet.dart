import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart' show CommentModel;
import '../../providers/auth/auth_provider.dart';
import '../../repositories/report_repository.dart';
import 'block_user.dart';
import 'glass_panel.dart';

export '../../repositories/report_repository.dart' show ReportKind;

final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => ReportRepository());

/// The reasons offered for each kind. Spoilers only make sense for writing
/// about a film; impersonation and age only for an account.
List<(IconData, String)> _reasonsFor(ReportKind kind) => [
      if (kind != ReportKind.profile && kind != ReportKind.list)
        (CupertinoIcons.eye_slash, 'Unmarked spoilers'),
      (CupertinoIcons.exclamationmark_bubble, 'Harassment or hate'),
      (CupertinoIcons.nosign, 'Sexual or violent content'),
      (CupertinoIcons.tray_arrow_down, 'Spam'),
      if (kind == ReportKind.profile) ...[
        (
          CupertinoIcons.person_crop_circle_badge_exclam,
          'Pretending to be someone'
        ),
        (CupertinoIcons.person_badge_minus, 'Under 13'),
      ],
      (CupertinoIcons.ellipsis_circle, 'Something else'),
    ];

/// Report anything (ADR 0004 D1): pick a reason, send it, say thanks.
///
/// Resolves true once the report is saved. The server then hides the thing
/// from the reporter on every read; [onReported] is for taking it off the
/// screen straight away. An account isn't hidden when reported, so the sheet
/// offers to block it instead.
Future<bool> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required String targetId,
  String? username,
  VoidCallback? onReported,
}) async {
  final reasons = _reasonsFor(kind);
  final reason = await showGlassPanel<String>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassPanelHeader(
          title: kind == ReportKind.profile && username != null
              ? 'Report @$username'
              : 'Report ${kind.noun}',
          subtitle: kind == ReportKind.profile
              ? 'What\'s wrong with this account?'
              : 'What\'s wrong with it?',
        ),
        for (var i = 0; i < reasons.length; i++) ...[
          if (i > 0) const GlassMenuDivider(),
          GlassMenuRow(
            icon: reasons[i].$1,
            title: reasons[i].$2,
            onTap: () => Navigator.of(panelContext).pop(reasons[i].$2),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
      ],
    ),
  );
  if (reason == null || !context.mounted) return false;

  final me = ref.read(currentUserProvider)?.uid;
  var ok = me != null;
  if (ok) {
    try {
      await ref.read(reportRepositoryProvider).report(
            kind: kind,
            targetId: targetId,
            reporterId: me,
            reason: reason,
          );
    } catch (_) {
      ok = false;
    }
  }
  if (!context.mounted) return ok;
  if (!ok) {
    showGlassToast(context, "Couldn't send that report. Try again.",
        destructive: true);
    return false;
  }

  onReported?.call();
  if (kind == ReportKind.profile && username != null) {
    final block = await showGlassConfirm(
      context,
      title: 'Thanks. We\'ll take a look.',
      message: 'Do you also want to block @$username? You won\'t see each '
          'other on 35mm.',
      confirmLabel: 'Block',
      cancelLabel: 'Not now',
      destructive: true,
    );
    if (block && context.mounted) {
      await confirmAndBlock(context, ref, userId: targetId, username: username);
    }
  } else {
    showGlassToast(context, 'Thanks. We\'ll take a look.',
        icon: CupertinoIcons.flag_fill);
  }
  return true;
}

/// The ••• menu for someone else's content: Report, and Block the author.
/// Used by review cards, comments and anywhere else without a menu of its
/// own.
Future<void> showContentMenu(
  BuildContext context,
  WidgetRef ref, {
  required ReportKind kind,
  required String targetId,
  required String authorId,
  required String authorUsername,
  VoidCallback? onReported,
}) {
  return showGlassPanel<void>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.sm),
        GlassMenuRow(
          icon: CupertinoIcons.flag,
          title: 'Report ${kind.noun}',
          destructive: true,
          onTap: () {
            Navigator.of(panelContext).pop();
            showReportSheet(context, ref,
                kind: kind, targetId: targetId, onReported: onReported);
          },
        ),
        const GlassMenuDivider(),
        GlassMenuRow(
          icon: CupertinoIcons.hand_raised,
          title: 'Block @$authorUsername',
          destructive: true,
          onTap: () {
            Navigator.of(panelContext).pop();
            confirmAndBlock(context, ref,
                userId: authorId, username: authorUsername);
          },
        ),
        const SizedBox(height: AppSpace.sm),
      ],
    ),
  );
}

/// A comment's menu. Yours: Delete. Someone else's: Report and Block, plus
/// Delete when it's on your post.
Future<void> showCommentMenu(
  BuildContext context,
  WidgetRef ref, {
  required CommentModel comment,
  required ReportKind kind,
  required bool canDelete,
  required VoidCallback onDelete,
  VoidCallback? onReported,
}) {
  final mine = ref.read(currentUserProvider)?.uid == comment.userId;
  if (mine) {
    onDelete();
    return Future.value();
  }
  return showGlassPanel<void>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.sm),
        GlassMenuRow(
          icon: CupertinoIcons.flag,
          title: 'Report ${kind.noun}',
          destructive: true,
          onTap: () {
            Navigator.of(panelContext).pop();
            showReportSheet(context, ref,
                kind: kind, targetId: comment.id, onReported: onReported);
          },
        ),
        const GlassMenuDivider(),
        GlassMenuRow(
          icon: CupertinoIcons.hand_raised,
          title: 'Block @${comment.username}',
          destructive: true,
          onTap: () {
            Navigator.of(panelContext).pop();
            confirmAndBlock(context, ref,
                userId: comment.userId, username: comment.username);
          },
        ),
        if (canDelete) ...[
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: CupertinoIcons.trash,
            title: 'Delete ${kind.noun}',
            destructive: true,
            onTap: () {
              Navigator.of(panelContext).pop();
              onDelete();
            },
          ),
        ],
        const SizedBox(height: AppSpace.sm),
      ],
    ),
  );
}
