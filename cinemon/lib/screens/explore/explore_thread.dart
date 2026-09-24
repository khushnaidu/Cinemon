import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart' show CommentModel;
import '../../models/explore_post_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/explore/explore_provider.dart';
import '../widgets/comment_thread.dart';
import '../widgets/comments_sheet.dart' show CommentSendButton, GlassHint;
import '../widgets/block_user.dart';
import '../widgets/glass_panel.dart';
import 'explore_composer.dart' show showExploreEditor;
import 'explore_post_card.dart';

/// A post in full with its thread under it, as one tall glass pane.
///
/// Reads the post back out of the feed by id, so a vote cast here moves the
/// card underneath too; falls back to [post] if it has left the feed.
Future<void> showExploreThread(
  BuildContext context,
  ExplorePost post, {
  ValueChanged<ExploreSubject>? onSubjectTap,
  bool focusComposer = false,
}) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (_) => ExploreThread(
      post: post,
      onSubjectTap: onSubjectTap,
      focusComposer: focusComposer,
    ),
  );
}

class ExploreThread extends ConsumerStatefulWidget {
  const ExploreThread({
    super.key,
    required this.post,
    this.onSubjectTap,
    this.focusComposer = false,
  });

  final ExplorePost post;
  final ValueChanged<ExploreSubject>? onSubjectTap;
  final bool focusComposer;

  @override
  ConsumerState<ExploreThread> createState() => _ExploreThreadState();
}

class _ExploreThreadState extends ConsumerState<ExploreThread> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _sending = false;

  /// The comment being replied to, if any.
  CommentModel? _replyTo;

  /// Threads whose replies are showing.
  final Set<String> _expanded = {};

  void _startReply(CommentModel c) {
    setState(() => _replyTo = c);
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
  void initState() {
    super.initState();
    if (widget.focusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String postId) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();

    final replyTo = _replyTo;
    final root = replyTo == null ? null : (replyTo.parentId ?? replyTo.id);
    final c = await ref
        .read(exploreActionsProvider)
        .addComment(postId, text, parentId: root);
    if (!mounted) return;
    setState(() => _sending = false);

    if (c == null) {
      showGlassToast(context, "Couldn't post that reply. Try again.",
          destructive: true);
      return;
    }
    _controller.clear();
    if (root != null) {
      setState(() {
        _expanded.add(root);
        _replyTo = null;
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _deleteComment(String postId, CommentModel c) async {
    final ok = await showGlassConfirm(
      context,
      title: 'Delete reply?',
      message: 'This can\'t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done =
        await ref.read(exploreActionsProvider).deleteComment(postId, c.id);
    if (!done && mounted) {
      showGlassToast(context, "Couldn't delete that reply.", destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(exploreFeedProvider.select((s) {
      for (final p in s.posts) {
        if (p.id == widget.post.id) return p;
      }
      return null;
    }));
    final post = live ?? widget.post;
    final open = post.kind.allowsComments;
    final comments = open ? ref.watch(exploreCommentsProvider(post.id)) : null;
    final me = ref.watch(currentUserProvider)?.id;
    final isDiscussion = post.kind == ExploreKind.discussion;

    return Column(
      children: [
        GlassPanelHeader(
          title: post.kind.label,
          subtitle: post.subject?.title ?? '@${post.username}',
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.lg),
                sliver: SliverToBoxAdapter(
                  child: ExplorePostCard(
                    post: post,
                    expanded: true,
                    onMenu: () => showExplorePostMenu(context, post,
                        onSubjectTap: widget.onSubjectTap, fromThread: true),
                    onSubjectTap: widget.onSubjectTap == null
                        ? null
                        : (s) {
                            Navigator.of(context).pop();
                            widget.onSubjectTap!(s);
                          },
                  ),
                ),
              ),
              if (!open)
                const SliverToBoxAdapter(child: _ClosedNote())
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                  sliver: SliverToBoxAdapter(
                    child: GlassSectionLabel(
                        isDiscussion ? 'Replies' : 'Comments'),
                  ),
                ),
                ...comments!.when(
                  loading: () => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpace.xl),
                        child: CupertinoActivityIndicator(
                            color: AppColors.inkSecondary),
                      ),
                    ),
                  ],
                  error: (_, __) => [
                    const SliverToBoxAdapter(
                      child: GlassHint(
                        icon: CupertinoIcons.wifi_exclamationmark,
                        title: 'Couldn\'t load the thread',
                        body: 'Check your connection and try again.',
                      ),
                    ),
                  ],
                  data: (list) => list.isEmpty
                      ? [
                          SliverToBoxAdapter(
                            child: GlassHint(
                              icon: isDiscussion
                                  ? CupertinoIcons.chat_bubble_2
                                  : CupertinoIcons.chat_bubble,
                              title: isDiscussion
                                  ? 'No replies yet'
                                  : 'No comments yet',
                              body: isDiscussion
                                  ? 'Be the first to answer.'
                                  : 'Start the conversation.',
                            ),
                          ),
                        ]
                      : [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
                            sliver: SliverCommentThreads(
                              threads: CommentThreads.of(list),
                              expanded: _expanded,
                              onToggle: (id) => setState(() {
                                if (!_expanded.remove(id)) _expanded.add(id);
                              }),
                              onReply: _startReply,
                              // Your own reply, or anything on your post.
                              canDelete: (c) =>
                                  c.userId == me || post.userId == me,
                              isAuthor: (c) => c.userId == post.userId,
                              onDelete: (c) => _deleteComment(post.id, c),
                            ),
                          ),
                        ],
                ),
              ],
            ],
          ),
        ),
        if (open && _replyTo != null)
          ReplyingToBar(username: _replyTo!.username, onCancel: _cancelReply),
        if (open)
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
                      onSubmitted: (_) => _send(post.id),
                      onChanged: (_) => setState(() {}),
                      style: AppText.body
                          .copyWith(fontSize: 16, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: isDiscussion || _replyTo != null
                            ? 'Add a reply'
                            : 'Add a comment',
                        hintStyle: AppText.body.copyWith(
                            fontSize: 16, color: AppColors.inkTertiary),
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
                  enabled: _controller.text.trim().isNotEmpty && !_sending,
                  busy: _sending,
                  onTap: () => _send(post.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The "…" menu on a post.
Future<void> showExplorePostMenu(
  BuildContext context,
  ExplorePost post, {
  ValueChanged<ExploreSubject>? onSubjectTap,
  bool fromThread = false,
}) {
  return showGlassPanel<void>(
    context,
    builder: (panelContext) => Consumer(
      builder: (context, ref, _) {
        final me = ref.watch(currentUserProvider)?.id;
        final own = me == post.userId;
        final subject = post.subject;

        void close() => Navigator.of(panelContext).pop();

        // Closing the thread too when the action leaves it behind.
        void closeAll() {
          close();
          if (fromThread) Navigator.of(context).pop();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpace.sm),
            if (subject != null && onSubjectTap != null) ...[
              GlassMenuRow(
                icon: CupertinoIcons.line_horizontal_3_decrease,
                title: 'Posts about ${subject.title}',
                onTap: () {
                  closeAll();
                  onSubjectTap(subject.titleOnly);
                },
              ),
              const GlassMenuDivider(),
            ],
            if (subject != null) ...[
              GlassMenuRow(
                icon: subject.isTv ? CupertinoIcons.tv : CupertinoIcons.film,
                title: 'Open ${subject.title}',
                chevron: true,
                onTap: () {
                  closeAll();
                  context.push('/film/${subject.filmId}/${subject.mediaType}');
                },
              ),
              const GlassMenuDivider(),
            ],
            if (!own) ...[
              GlassMenuRow(
                icon: CupertinoIcons.person,
                title: 'View @${post.username}',
                chevron: true,
                onTap: () {
                  closeAll();
                  context.push('/profile/${post.userId}');
                },
              ),
              const GlassMenuDivider(),
              GlassMenuRow(
                icon: CupertinoIcons.flag,
                title: 'Report post',
                destructive: true,
                onTap: () async {
                  close();
                  await _report(context, ref, post, fromThread: fromThread);
                },
              ),
              const GlassMenuDivider(),
              GlassMenuRow(
                icon: CupertinoIcons.hand_raised,
                title: 'Block @${post.username}',
                destructive: true,
                onTap: () async {
                  close();
                  final blocked = await confirmAndBlock(
                    context,
                    ref,
                    userId: post.userId,
                    username: post.username,
                  );
                  if (blocked && fromThread && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ] else ...[
              GlassMenuRow(
                icon: CupertinoIcons.pencil,
                title: 'Edit post',
                onTap: () {
                  close();
                  showExploreEditor(context, post);
                },
              ),
              const GlassMenuDivider(),
              GlassMenuRow(
                icon: CupertinoIcons.trash,
                title: 'Delete post',
                destructive: true,
                onTap: () async {
                  close();
                  final ok = await showGlassConfirm(
                    context,
                    title: 'Delete post?',
                    message: 'It will be removed from Explore for everyone, '
                        'along with its replies.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  final done =
                      await ref.read(exploreActionsProvider).deletePost(post);
                  if (!context.mounted) return;
                  if (done) {
                    showGlassToast(context, 'Post deleted',
                        icon: CupertinoIcons.trash);
                    if (fromThread) Navigator.of(context).pop();
                  } else {
                    showGlassToast(context, "Couldn't delete that post.",
                        destructive: true);
                  }
                },
              ),
            ],
            const SizedBox(height: AppSpace.sm),
          ],
        );
      },
    ),
  );
}

const _reportReasons = [
  (CupertinoIcons.eye_slash, 'Unmarked spoilers'),
  (CupertinoIcons.exclamationmark_bubble, 'Harassment or hate'),
  (CupertinoIcons.nosign, 'Sexual or violent content'),
  (CupertinoIcons.tray_arrow_down, 'Spam'),
  (CupertinoIcons.ellipsis_circle, 'Something else'),
];

Future<void> _report(
  BuildContext context,
  WidgetRef ref,
  ExplorePost post, {
  required bool fromThread,
}) async {
  final reason = await showGlassPanel<String>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassPanelHeader(
          title: 'Report post',
          subtitle: 'What\'s wrong with it?',
        ),
        for (var i = 0; i < _reportReasons.length; i++) ...[
          if (i > 0) const GlassMenuDivider(),
          GlassMenuRow(
            icon: _reportReasons[i].$1,
            title: _reportReasons[i].$2,
            onTap: () => Navigator.of(panelContext).pop(_reportReasons[i].$2),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
      ],
    ),
  );
  if (reason == null || !context.mounted) return;

  final ok = await ref.read(exploreActionsProvider).report(post.id, reason);
  if (!context.mounted) return;
  if (ok) {
    // Out of your feed straight away; the report is reviewed separately.
    ref.read(exploreFeedProvider.notifier).remove(post.id);
    showGlassToast(context, 'Thanks. We\'ll take a look.',
        icon: CupertinoIcons.flag_fill);
    if (fromThread) Navigator.of(context).pop();
  } else {
    showGlassToast(context, "Couldn't send that report. Try again.",
        destructive: true);
  }
}

/// In place of a thread on takes, reviews and critiques.
class _ClosedNote extends StatelessWidget {
  const _ClosedNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.xs, AppSpace.xl, AppSpace.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.chat_bubble,
              size: 13, color: AppColors.inkTertiary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Comments are off for this kind of post.',
              style: AppText.caption.copyWith(color: AppColors.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
