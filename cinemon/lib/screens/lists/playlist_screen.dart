import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart' show ExploreListRef;
import '../../models/list_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart' show userProfileProvider;
import '../../providers/library/library_provider.dart'
    show myLibraryKeysProvider;
import '../../providers/lists/list_provider.dart';
import '../explore/explore_composer.dart'
    show confirmListRepost, showExploreComposer;
import '../widgets/glass_panel.dart';
import '../widgets/report_sheet.dart';
import '../widgets/verified_mark.dart';
import '../../share/share_sheet.dart';
import '../../share/share_subject.dart';
import 'add_films_panel.dart';
import 'playlist_cover.dart';
import 'playlist_editor.dart';
import 'watchlist_screen.dart';

/// `/lists/:listId`: a watchlist or a playlist, whichever the id is.
class ListScreen extends ConsumerWidget {
  const ListScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listProvider(listId));
    return list.maybeWhen(
      data: (l) => l != null && !l.isWatchlist
          ? PlaylistScreen(list: l)
          : WatchlistScreen(listId: listId),
      // Loading, errors and "not available" look the same for both.
      orElse: () => WatchlistScreen(listId: listId),
    );
  }
}

/// Leaves the screen, or goes home when it was opened from a link and
/// there's nothing underneath.
void leaveList(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/home');

/// The share link for a list. The website sends people without the app to
/// the App Store; with it, iOS opens the list here.
Uri listShareUrl(String listId) => Uri.parse('https://35mm.contact/l/$listId');

class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.list});

  final FilmList list;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  bool _reordering = false;

  /// The poster wall; off for the numbered list (and while reordering).
  bool _wall = true;

  /// While reordering, the order on screen; the server catches up per move.
  List<ListItem>? _order;

  FilmList get list => widget.list;

  Future<void> _edit(List<ListItem> items) async {
    final result = await showPlaylistEditor(
      context,
      editing: list,
      posters: [for (final i in items.take(6)) i.posterPath],
      items: items,
    );
    if (!mounted) return;
    if (result is PlaylistDeleted) {
      showGlassToast(context, 'Playlist deleted', icon: CupertinoIcons.trash);
      leaveList(context);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (list.visibility != ListVisibility.public) {
      final go = await showGlassConfirm(
        context,
        title: 'Only some people can open it',
        message: list.visibility == ListVisibility.private
            ? 'This playlist is private, so the link will only work for you. '
                'Make it public in Edit to share it.'
            : 'This playlist is for your followers, so the link will only '
                'work for people who follow you.',
        confirmLabel: 'Share anyway',
      );
      if (!go || !buttonContext.mounted) return;
    }
    // With films on it, the playlist goes out as a card (ADR 0003, L1); the
    // link rides along in More and in the link sticker.
    final items = ref.read(listItemsProvider(list.id)).valueOrNull ?? const [];
    if (items.isNotEmpty) {
      if (!mounted) return;
      final owner = ref.read(userProfileProvider(list.userId)).valueOrNull;
      await showShareSheet(
        context,
        PlaylistShare(
          list: list,
          items: items,
          ownerName: owner?.username ?? 'someone',
          ownerPhotoUrl: owner?.photoUrl,
        ),
      );
      return;
    }
    if (!buttonContext.mounted) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      uri: listShareUrl(list.id),
      subject: list.displayTitle,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  /// Share it on Explore, where friends see it on Home too. Only a public
  /// playlist can go there, so a private one is offered the switch first.
  Future<void> _postToExplore(List<ListItem> items) async {
    if (list.visibility != ListVisibility.public) {
      final go = await showGlassConfirm(
        context,
        title: 'Make it public?',
        message: 'Only public playlists can go on Explore. Anyone on 35mm '
            'will be able to see "${list.displayTitle}".',
        confirmLabel: 'Make public',
      );
      if (!go || !mounted) return;
      final ok = await ref.read(playlistActionsProvider).update(
            list,
            title: list.displayTitle,
            description: list.description,
            visibility: ListVisibility.public,
          );
      if (!mounted) return;
      if (!ok) {
        showGlassToast(context, "Couldn't change who can see it.",
            destructive: true);
        return;
      }
    }
    final shared = ExploreListRef(
      id: list.id,
      title: list.displayTitle,
      description: list.description,
      itemCount: items.length,
      posters: [for (final i in items.take(4)) i.posterPath],
    );
    if (!mounted || !await confirmListRepost(context, ref, shared)) return;
    if (!mounted) return;
    await showExploreComposer(context, list: shared);
  }

  Future<void> _toggleSaved(bool saved) async {
    HapticFeedback.lightImpact();
    final ok = await ref
        .read(playlistActionsProvider)
        .setSaved(list.id, saved: !saved);
    if (!mounted) return;
    showGlassToast(
      context,
      !ok
          ? "Couldn't update that."
          : saved
              ? 'Removed from your saved playlists'
              : 'Saved',
      destructive: !ok,
      icon: ok ? CupertinoIcons.bookmark_fill : null,
    );
  }

  Future<void> _remove(ListItem item) async {
    final ok = await ref.read(playlistActionsProvider).remove(item);
    if (!mounted) return;
    showGlassToast(
        context, ok ? 'Removed ${item.title}' : "Couldn't remove that.",
        destructive: !ok);
  }

  Future<void> _move(int from, int to) async {
    final items = _order!;
    // ReorderableListView reports the index before the removal.
    if (to > from) to -= 1;
    final optimistic = [...items];
    optimistic.insert(to, optimistic.removeAt(from));
    setState(() => _order = optimistic);
    final moved = await ref.read(playlistActionsProvider).move(items, from, to);
    if (!mounted) return;
    if (moved == null) {
      setState(() => _order = items);
      showGlassToast(context, "Couldn't save that order.", destructive: true);
    } else {
      // Carries the new positions, so the next move's midpoint is right.
      setState(() => _order = moved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.uid;
    final isOwner = list.userId == me;
    final itemsAsync = ref.watch(listItemsProvider(list.id));
    final items = itemsAsync.valueOrNull ?? const <ListItem>[];
    final owner = ref.watch(userProfileProvider(list.userId)).valueOrNull;
    final saved = isOwner
        ? false
        : (ref.watch(listSavedProvider(list.id)).valueOrNull ?? false);
    final posters = [for (final i in items.take(6)) i.posterPath];
    final shown = _reordering ? (_order ?? items) : items;
    final seenKeys = me == null
        ? const <String>{}
        : ref.watch(myLibraryKeysProvider).valueOrNull ?? const <String>{};
    final seen = items.where((i) => seenKeys.contains(i.key)).length;
    final wall = _wall && !_reordering;

    final header = _Header(
      list: list,
      ownerName: owner?.username,
      onOwnerTap: () => context.push('/profile/${list.userId}'),
    );

    final actions = Builder(
      builder: (buttonContext) => Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          if (isOwner) ...[
            GlassPillButton(
              label: 'Add',
              icon: CupertinoIcons.plus,
              prominent: true,
              compact: true,
              onTap: () => showAddFilmsPanel(context, list),
            ),
            GlassPillButton(
              label: 'Edit',
              icon: CupertinoIcons.pencil,
              compact: true,
              onTap: () => _edit(items),
            ),
            if (items.length > 1)
              GlassPillButton(
                label: _reordering ? 'Done' : 'Reorder',
                icon: _reordering
                    ? CupertinoIcons.checkmark_alt
                    : CupertinoIcons.arrow_up_arrow_down,
                compact: true,
                onTap: () => setState(() {
                  _reordering = !_reordering;
                  _order = _reordering ? [...items] : null;
                }),
              ),
          ] else
            GlassPillButton(
              label: saved ? 'Saved' : 'Save',
              icon: saved
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
              prominent: !saved,
              compact: true,
              onTap: () => _toggleSaved(saved),
            ),
          GlassPillButton(
            label: 'Share',
            icon: CupertinoIcons.share,
            compact: true,
            onTap: () => _share(buttonContext),
          ),
          // Nothing to show on Explore until it has films.
          if (isOwner && !_reordering && items.isNotEmpty)
            GlassPillButton(
              label: 'Post',
              icon: CupertinoIcons.globe,
              compact: true,
              onTap: () => _postToExplore(items),
            ),
          // Someone else's playlist: report it, or block its owner.
          if (!isOwner && me != null)
            GlassPillButton(
              label: 'More',
              icon: CupertinoIcons.ellipsis,
              compact: true,
              onTap: () => showContentMenu(
                context,
                ref,
                kind: ReportKind.list,
                targetId: list.id,
                authorId: list.userId,
                authorUsername: owner?.username ?? 'this person',
                onReported: () => leaveList(context),
              ),
            ),
          if (items.length > 1 && !_reordering)
            GlassPillButton(
              label: 'Pick for me',
              icon: Icons.casino_outlined,
              compact: true,
              onTap: () => showPickForMe(context, items),
            ),
        ],
      ),
    );

    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The cover the curator chose, across the top, fading to black.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _Banner.height,
            child: _Banner(list: list, posters: posters, width: width),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                floating: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => leaveList(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  // The title sits over the foot of the banner.
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      _Banner.height - kToolbarHeight - 150,
                      AppSpace.lg,
                      AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: AppSpace.lg),
                      actions,
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xl),
                        Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: GlassSegmentedControl(
                                labels: const ['Wall', 'List'],
                                index: wall ? 0 : 1,
                                onChanged: (i) => setState(() {
                                  _wall = i == 0;
                                  if (_wall) {
                                    _reordering = false;
                                    _order = null;
                                  }
                                }),
                              ),
                            ),
                            const Spacer(),
                            if (me != null && seen > 0)
                              Text(
                                seen == items.length
                                    ? 'You\'ve seen them all'
                                    : 'You\'ve seen $seen',
                                style: AppText.footnote
                                    .copyWith(color: AppColors.inkSecondary),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (itemsAsync.isLoading && items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: Text(
                        isOwner
                            ? 'Nothing here yet. Tap Add to find films and shows.'
                            : 'Nothing on this playlist yet.',
                        style: AppText.body
                            .copyWith(color: AppColors.inkSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (wall)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: AppSpace.lg,
                      // A 2:3 poster and its number underneath.
                      childAspectRatio: 0.58,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _WallTile(
                      item: items[i],
                      rank: i + 1,
                      seen: seenKeys.contains(items[i].key),
                    ),
                  ),
                )
              else if (_reordering)
                SliverReorderableList(
                  itemCount: shown.length,
                  onReorder: _move,
                  itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
                    key: ValueKey(shown[i].key),
                    index: i,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _Row(item: shown[i], index: i, dragHandle: true),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final row = _Row(item: shown[i], index: i);
                    if (!isOwner) return row;
                    return Dismissible(
                      key: ValueKey(shown[i].key),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _remove(shown[i]),
                      background: Container(
                        color: AppColors.destructive.withValues(alpha: 0.22),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(CupertinoIcons.trash,
                            color: AppColors.destructive),
                      ),
                      child: row,
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.list,
    required this.ownerName,
    required this.onOwnerTap,
  });

  final FilmList list;
  final String? ownerName;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    final count = list.itemCount;
    final kicker = [
      list.isSelect ? '35MM SELECTS' : 'PLAYLIST',
      '$count ${count == 1 ? 'TITLE' : 'TITLES'}',
    ].join(' · ');
    final meta = [
      if (list.saveCount > 0)
        '${list.saveCount} save${list.saveCount == 1 ? '' : 's'}',
      if (list.updatedAt != null) 'updated ${_ago(list.updatedAt!)}',
      if (list.visibility != ListVisibility.public) list.visibility.label,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: AppText.caption.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.9,
            color: AppColors.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          list.displayTitle,
          style: AppText.largeTitle.copyWith(
            fontSize: 36,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        if (list.tagline != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            list.tagline!,
            style: AppText.body
                .copyWith(fontSize: 16, color: AppColors.inkSecondary),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        if (ownerName != null)
          GestureDetector(
            onTap: onOwnerTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    ownerName!,
                    style: const TextStyle(
                      fontFamily: AppText.usernameFamily,
                      fontSize: 24,
                      height: 1.1,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                VerifiedMark(userId: list.userId, size: 14, gap: 6),
              ],
            ),
          ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(meta,
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary)),
          ),
        if (list.description != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            list.description!,
            style: AppText.body.copyWith(
                color: AppColors.inkSecondary, fontSize: 15, height: 1.45),
          ),
        ],
      ],
    );
  }
}

/// The list's cover as a banner behind the top of the page, fading into
/// the black below: the six-strip, the film, or our artwork.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.list,
    required this.posters,
    required this.width,
  });

  final FilmList list;
  final List<String?> posters;
  final double width;

  static const height = 330.0;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.35, 1],
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlaylistCover.of(list,
              posters: posters, size: width, height: height, radius: 0),
          // Enough shade for the back button and the title over its foot.
          ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

/// A title on the poster wall: the poster, its number, and a check if
/// you've seen it.
class _WallTile extends StatelessWidget {
  const _WallTile({
    required this.item,
    required this.rank,
    required this.seen,
  });

  final ListItem item;
  final int rank;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getPosterUrl(item.posterPath,
        size: ApiConstants.posterSizeMedium);
    return Semantics(
      button: true,
      label: '$rank. ${item.title}${seen ? ', seen' : ''}',
      child: GlassPressable(
        onTap: () => context.push('/film/${item.filmId}/${item.mediaType}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    url.isEmpty
                        ? Container(
                            color: AppColors.surfaceElevated,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(AppSpace.xs),
                            child: Text(
                              item.title,
                              style: AppText.footnote
                                  .copyWith(color: AppColors.inkSecondary),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ColoredBox(color: AppColors.surface),
                            errorWidget: (_, __, ___) =>
                                const ColoredBox(color: AppColors.surface),
                          ),
                    if (seen)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 0.5),
                          ),
                          child: const Icon(CupertinoIcons.checkmark_alt,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$rank',
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.inkTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.item, required this.index, this.dragHandle = false});

  final ListItem item;
  final int index;
  final bool dragHandle;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getPosterUrl(item.posterPath, size: '/w154');
    final meta = [
      if (item.year != null) item.year!,
      item.isTv ? 'Show' : 'Film',
    ].join(' · ');

    return GlassPressable(
      onTap: dragHandle
          ? null
          : () => context.push('/film/${item.filmId}/${item.mediaType}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${index + 1}',
                style: AppText.footnote.copyWith(
                  color: AppColors.inkTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 46,
                height: 69,
                child: url.isEmpty
                    ? const ColoredBox(color: AppColors.surface)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: AppColors.surface),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: AppColors.surface),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: AppText.body.copyWith(color: AppColors.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: AppText.footnote
                          .copyWith(color: AppColors.inkTertiary)),
                  if (item.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item.note!,
                          style: AppText.footnote.copyWith(
                              color: AppColors.inkSecondary,
                              fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
            if (dragHandle)
              const Padding(
                padding: EdgeInsets.only(left: AppSpace.sm),
                child: Icon(CupertinoIcons.line_horizontal_3,
                    color: AppColors.inkTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pick for me: posters flick past and slow to a stop on tonight's pick.
Future<void> showPickForMe(BuildContext context, List<ListItem> items) {
  return showGlassPanel<void>(
    context,
    builder: (_) => _PickForMe(items: items),
  );
}

class _PickForMe extends StatefulWidget {
  const _PickForMe({required this.items});

  final List<ListItem> items;

  @override
  State<_PickForMe> createState() => _PickForMeState();
}

class _PickForMeState extends State<_PickForMe> {
  final _random = Random();
  late ListItem _current = widget.items[_random.nextInt(widget.items.length)];
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _spin();
  }

  Future<void> _spin() async {
    setState(() => _spinning = true);
    // Ticks that stretch out, like a wheel coming to rest.
    for (var i = 0; i < 14; i++) {
      await Future<void>.delayed(Duration(milliseconds: 45 + i * i * 2));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        ListItem next;
        do {
          next = widget.items[_random.nextInt(widget.items.length)];
        } while (widget.items.length > 1 && next.key == _current.key);
        _current = next;
      });
    }
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _spinning = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _spinning ? 'Picking something to watch…' : "Tonight's pick",
            style: AppText.label.copyWith(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: AppSpace.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 90),
            child: ClipRRect(
              key: ValueKey(item.key),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 150,
                height: 225,
                child: CachedNetworkImage(
                  imageUrl: ApiConstants.getPosterUrl(item.posterPath,
                      size: ApiConstants.posterSizeMedium),
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppColors.surface),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.surface),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(item.title,
              style: AppText.title, textAlign: TextAlign.center, maxLines: 2),
          if (item.year != null)
            Text(item.year!,
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary)),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: GlassPillButton(
                  label: 'Pick again',
                  icon: Icons.casino_outlined,
                  expand: true,
                  onTap: _spinning ? null : _spin,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: GlassPillButton(
                  label: 'Open',
                  prominent: true,
                  expand: true,
                  onTap: _spinning
                      ? null
                      : () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.push('/film/${item.filmId}/${item.mediaType}');
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  if (d.inDays < 365) return '${d.inDays ~/ 7}w ago';
  return '${d.inDays ~/ 365}y ago';
}
