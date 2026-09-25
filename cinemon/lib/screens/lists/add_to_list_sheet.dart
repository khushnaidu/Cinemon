import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/film_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';
import 'playlist_cover.dart';
import 'playlist_editor.dart';

/// Add to…: the watchlist first, then your playlists, then a new one. Each
/// row toggles the title on or off that list in place.
Future<void> showAddToListSheet(BuildContext context, FilmModel film) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (_) => _AddToList(film: film),
  );
}

class _AddToList extends ConsumerStatefulWidget {
  const _AddToList({required this.film});

  final FilmModel film;

  @override
  ConsumerState<_AddToList> createState() => _AddToListState();
}

class _AddToListState extends ConsumerState<_AddToList> {
  /// Taps in flight, drawn as their new state before the reload.
  final _pending = <String, bool>{};

  ({int filmId, String mediaType}) get _title =>
      (filmId: widget.film.id, mediaType: widget.film.isTv ? 'tv' : 'movie');

  /// On a list means on it, watched or not, so this is a plain add/remove
  /// for the watchlist too (unlike the bookmark, which re-adds a watched
  /// title to watch again).
  Future<void> _toggle(String listId, bool on) async {
    HapticFeedback.selectionClick();
    setState(() => _pending[listId] = !on);
    final now = await ref
        .read(playlistActionsProvider)
        .toggle(listId, widget.film, on: on);
    if (!mounted) return;
    setState(() => _pending.remove(listId));
    if (now == null) {
      showGlassToast(context, "Couldn't update that list.", destructive: true);
    }
  }

  Future<void> _newPlaylist() async {
    final result = await showPlaylistEditor(context, first: widget.film);
    if (!mounted || result is! PlaylistSaved) return;
    showGlassToast(context, 'Added to ${result.list.displayTitle}',
        icon: CupertinoIcons.square_stack_fill);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.uid;
    final watchlist = ref.watch(myWatchlistProvider).valueOrNull;
    final playlists = me == null
        ? const AsyncValue<List<PlaylistSummary>>.data([])
        : ref.watch(playlistsProvider(me));
    final containing = ref.watch(listsContainingProvider(_title)).valueOrNull;

    bool isOn(String listId) =>
        _pending[listId] ?? (containing?.contains(listId) ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanelHeader(
          title: 'Add to…',
          subtitle: widget.film.displayTitle,
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            children: [
              if (watchlist != null)
                _ListRow(
                  leading: const _IconTile(CupertinoIcons.bookmark_fill),
                  title: 'Watchlist',
                  on: isOn(watchlist.id),
                  loading: containing == null,
                  onTap: () => _toggle(watchlist.id, isOn(watchlist.id)),
                ),
              const GlassMenuDivider(),
              ...playlists.when(
                loading: () => [
                  const Padding(
                    padding: EdgeInsets.all(AppSpace.xl),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                ],
                error: (_, __) => [
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.xl),
                    child: Text("Couldn't load your playlists.",
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkSecondary),
                        textAlign: TextAlign.center),
                  ),
                ],
                data: (lists) => [
                  for (final p in lists) ...[
                    _ListRow(
                      leading: PlaylistCover.of(p.list,
                          posters: p.posters, size: 44, radius: 8),
                      title: p.list.displayTitle,
                      subtitle:
                          '${p.list.itemCount} title${p.list.itemCount == 1 ? '' : 's'}',
                      on: isOn(p.list.id),
                      loading: containing == null,
                      onTap: () => _toggle(p.list.id, isOn(p.list.id)),
                    ),
                    const GlassMenuDivider(),
                  ],
                ],
              ),
              _ListRow(
                leading: const _IconTile(CupertinoIcons.plus),
                title: 'New playlist',
                onTap: _newPlaylist,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.on,
    this.loading = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Null for an action row (New playlist): no check.
  final bool? on;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.sm),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.body.copyWith(color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkTertiary)),
                ],
              ),
            ),
            if (on != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  on!
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  key: ValueKey(on),
                  size: 24,
                  color: on! ? AppColors.ink : AppColors.inkTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: glassWellDecoration(radius: 8),
      child: Icon(icon, size: 20, color: AppColors.ink),
    );
  }
}
