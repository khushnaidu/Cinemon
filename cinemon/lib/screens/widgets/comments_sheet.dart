import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart';
import 'comment_thread.dart';
import 'glass_panel.dart';
import 'liquid_glass.dart' show GlassLens;

/// Open the comments for a post as a tall glass panel.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String activityId,
  required String filmTitle,
  String? activityOwnerId,
  String? filmPosterPath,
}) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (_) => CommentsSheet(
      activityId: activityId,
      filmTitle: filmTitle,
      activityOwnerId: activityOwnerId,
      filmPosterPath: filmPosterPath,
    ),
  );
}

/// Comments on a post: the thread, and a composer pinned to the foot of the
/// pane. The pane itself follows the keyboard, so the composer is never
/// covered and the thread simply gets shorter while you type.
class CommentsSheet extends ConsumerStatefulWidget {
  final String activityId;
  final String filmTitle;
  final String? activityOwnerId;
  final String? filmPosterPath;

  const CommentsSheet({
    super.key,
    required this.activityId,
    required this.filmTitle,
    this.activityOwnerId,
    this.filmPosterPath,
  });

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _submitting = false;

  /// The comment being replied to, if any.
  CommentModel? _replyTo;

  /// Threads whose replies are showing.
  final Set<String> _expanded = {};

  void _startReply(CommentModel c) {
    setState(() => _replyTo = c);
    // Replying inside a thread names who you're answering, since the reply
    // lands in the same flat thread as everyone else's.
    if (c.parentId != null) {
      _controller.text = '@${c.username} ';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
    _focus.requestFocus();
  }

  void _cancelReply() {
    final prefix = _replyTo == null ? null : '@${_replyTo!.username} ';
    setState(() => _replyTo = null);
    if (prefix != null && _controller.text == prefix) _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    final replyTo = _replyTo;
    final root = replyTo == null ? null : (replyTo.parentId ?? replyTo.id);
    final result = await ref.read(commentNotifierProvider.notifier).addComment(
          activityId: widget.activityId,
          content: content,
          parentId: root,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == null) {
      showGlassToast(
        context,
        "Couldn't post that comment. Try again.",
        destructive: true,
      );
      return;
    }

    _controller.clear();
    if (root != null) {
      // A reply lands mid-list: open its thread instead of scrolling away.
      setState(() {
        _expanded.add(root);
        _replyTo = null;
      });
      return;
    }
    // Keep the keyboard up — replying to several people in a row is the
    // common case — but bring the new comment into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _delete(CommentModel comment) async {
    final confirmed = await showGlassConfirm(
      context,
      title: 'Delete comment?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(commentNotifierProvider.notifier).deleteComment(
          activityId: widget.activityId,
          commentId: comment.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync =
        ref.watch(activityCommentsProvider(widget.activityId));
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      children: [
        GlassPanelHeader(
          title: 'Comments',
          subtitle: widget.filmTitle,
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),

        Expanded(
          child: commentsAsync.when(
            loading: () => const Center(
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
            error: (_, __) => const GlassHint(
              icon: CupertinoIcons.wifi_exclamationmark,
              title: 'Couldn\'t load comments',
              body: 'Check your connection and pull to try again.',
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return const GlassHint(
                  icon: CupertinoIcons.chat_bubble,
                  title: 'No comments yet',
                  body: 'Say something about this one.',
                );
              }
              return CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
                    sliver: SliverCommentThreads(
                      threads: CommentThreads.of(comments),
                      expanded: _expanded,
                      onToggle: (id) => setState(() {
                        if (!_expanded.remove(id)) _expanded.add(id);
                      }),
                      onReply: _startReply,
                      canDelete: (c) => currentUser?.uid == c.userId,
                      isAuthor: (c) => widget.activityOwnerId == c.userId,
                      onDelete: _delete,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Composer, set into the foot of the pane.
        if (_replyTo != null)
          ReplyingToBar(username: _replyTo!.username, onCancel: _cancelReply),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: glassWellDecoration(radius: 22),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: 2),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    cursorColor: AppColors.ink,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) => setState(() {}),
                    style: AppText.body
                        .copyWith(fontSize: 16, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText:
                          _replyTo == null ? 'Add a comment' : 'Add a reply',
                      hintStyle: AppText.body
                          .copyWith(fontSize: 16, color: AppColors.inkTertiary),
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: AppSpace.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              CommentSendButton(
                enabled: _controller.text.trim().isNotEmpty && !_submitting,
                busy: _submitting,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The send control: a glass lens disc that lights up once there's text.
class CommentSendButton extends StatelessWidget {
  const CommentSendButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled || busy ? 1 : 0.45,
        child: SizedBox(
          width: size,
          height: size,
          child: GlassLens(
            radius: BorderRadius.circular(size / 2),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.arrow_up,
                      size: 18, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class CommentRow extends StatelessWidget {
  const CommentRow({
    super.key,
    required this.comment,
    required this.isOwn,
    required this.isAuthor,
    required this.onDelete,
    this.onReply,
    this.compact = false,
  });

  final CommentModel comment;
  final bool isOwn;

  /// Shows a "Reply" action under the text.
  final VoidCallback? onReply;

  /// A reply inside a thread: smaller avatar, tighter spacing.
  final bool compact;

  /// Wrote the post being commented on. Gets a small mark, the way threads
  /// flag the original poster.
  final bool isAuthor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isOwn
          ? () {
              HapticFeedback.mediumImpact();
              onDelete();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding:
            EdgeInsets.symmetric(vertical: compact ? AppSpace.sm : AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommentAvatar(
              photoUrl: comment.userPhotoUrl,
              username: comment.username,
              size: compact ? 24 : 32,
            ),
            SizedBox(width: compact ? AppSpace.sm + 2 : AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.username,
                          style: AppText.label.copyWith(
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAuthor) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'author',
                            style: AppText.footnote.copyWith(
                              fontSize: 10,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        comment.relativeTime,
                        style: AppText.caption
                            .copyWith(color: AppColors.inkTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.content,
                    style: AppText.body.copyWith(
                      fontSize: compact ? 14 : 15,
                      color: AppColors.ink.withValues(alpha: 0.92),
                    ),
                  ),
                  if (onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpace.xs + 2,
                            bottom: 2,
                            right: AppSpace.lg),
                        child: Text(
                          'Reply',
                          style: AppText.caption.copyWith(
                            color: AppColors.inkSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isOwn) ...[
              const SizedBox(width: AppSpace.sm),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpace.xs),
                  child: Icon(
                    CupertinoIcons.ellipsis,
                    size: 16,
                    color: AppColors.inkTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CommentAvatar extends StatelessWidget {
  const CommentAvatar({
    super.key,
    required this.photoUrl,
    required this.username,
    this.size = 32,
  });

  final String? photoUrl;
  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final initial = Container(
      color: Colors.white.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style:
            AppText.label.copyWith(fontSize: size * 0.4, color: AppColors.ink),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.6,
        ),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? initial
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => initial,
              ),
      ),
    );
  }
}

class GlassHint extends StatelessWidget {
  const GlassHint(
      {super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.inkTertiary, size: 32),
            const SizedBox(height: AppSpace.md),
            Text(title, style: AppText.headline, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs),
            Text(
              body,
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
