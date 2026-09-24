import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/list_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart' show userProfileProvider;
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';
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

  /// While reordering, the order on screen; the server catches up per move.
  List<ListItem>? _order;

  FilmList get list => widget.list;

  Future<void> _edit(List<ListItem> items) async {
    final result = await showPlaylistEditor(
      context,
      editing: list,
      posters: [for (final i in items.take(4)) i.posterPath],
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
            : 'This playlist is friends only, so the link will only work for '
                'people you follow each other with.',
        confirmLabel: 'Share anyway',
      );
      if (!go || !mounted) return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      uri: listShareUrl(list.id),
      subject: list.displayTitle,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
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
    final posters = [for (final i in items.take(4)) i.posterPath];
    final shown = _reordering ? (_order ?? items) : items;

    final header = _Header(
      list: list,
      posters: posters,
      ownerName: owner?.username,
      onOwnerTap: () => context.push('/profile/${list.userId}'),
    );

    final actions = Builder(
      builder: (buttonContext) => Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        alignment: WrapAlignment.center,
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child:
                _Ambient(posterPath: posters.whereType<String>().firstOrNull),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpace.lg),
                  child: Column(
                    children: [
                      header,
                      const SizedBox(height: AppSpace.lg),
                      actions,
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
    required this.posters,
    required this.ownerName,
    required this.onOwnerTap,
  });

  final FilmList list;
  final List<String?> posters;
  final String? ownerName;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    final count = list.itemCount;
    final meta = [
      '$count title${count == 1 ? '' : 's'}',
      if (list.updatedAt != null) 'updated ${_ago(list.updatedAt!)}',
      if (list.visibility != ListVisibility.public) list.visibility.label,
    ].join(' · ');

    return Column(
      children: [
        PlaylistCover(posters: posters, size: 190),
        const SizedBox(height: AppSpace.lg),
        Text(
          list.displayTitle,
          style: AppText.title.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        if (ownerName != null)
          GestureDetector(
            onTap: onOwnerTap,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('by @$ownerName',
                  style: AppText.label.copyWith(color: AppColors.inkSecondary)),
            ),
          ),
        const SizedBox(height: AppSpace.xs),
        Text(meta,
            style: AppText.footnote.copyWith(color: AppColors.inkTertiary)),
        if (list.description != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            list.description!,
            style: AppText.body
                .copyWith(color: AppColors.inkSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
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

/// The cover's first poster, blurred behind the header.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    if (posterPath == null) return const SizedBox.shrink();
    // Clipped: the poster is scaled up so the blur reaches the edges, and
    // without a clip that overflow painted past the fade as a hard strip.
    return ClipRect(
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaX: 40, sigmaY: 40, tileMode: TileMode.mirror),
              child: Transform.scale(
                scale: 1.3,
                child: CachedNetworkImage(
                  imageUrl: ApiConstants.getPosterUrl(posterPath,
                      size: ApiConstants.posterSizeSmall),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
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
    builder: (_) => _Shuffle(items: items),
  );
}

class _Shuffle extends StatefulWidget {
  const _Shuffle({required this.items});

  final List<ListItem> items;

  @override
  State<_Shuffle> createState() => _PickForMeState();
}

class _PickForMeState extends State<_Shuffle> {
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
