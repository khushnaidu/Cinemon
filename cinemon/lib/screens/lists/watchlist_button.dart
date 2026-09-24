import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';
import 'add_to_list_sheet.dart';

/// The bookmark on a film page: one tap puts it on your watchlist, another
/// takes it off. Lit while it's there and unwatched. A long press opens
/// Add to…, for playlists.
class WatchlistButton extends ConsumerStatefulWidget {
  const WatchlistButton({super.key, required this.film});

  final FilmModel film;

  @override
  ConsumerState<WatchlistButton> createState() => _WatchlistButtonState();
}

/// Add to… as its own button beside the bookmark, so playlists don't hide
/// behind a long press.
class AddToListButton extends StatelessWidget {
  const AddToListButton({super.key, required this.film});

  final FilmModel film;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Add to a playlist',
      icon: const Icon(CupertinoIcons.text_badge_plus, color: Colors.white),
      onPressed: () => showAddToListSheet(context, film),
    );
  }
}

class _WatchlistButtonState extends ConsumerState<WatchlistButton> {
  /// Shown while the write is in flight, so the tap lands instantly.
  bool? _optimistic;

  Future<void> _toggle(bool current) async {
    HapticFeedback.lightImpact();
    setState(() => _optimistic = !current);
    final now = await ref.read(watchlistActionsProvider).toggle(widget.film);
    if (!mounted) return;
    setState(() => _optimistic = null);
    if (now == null) {
      showGlassToast(context, "Couldn't update your watchlist.",
          destructive: true);
      return;
    }
    showGlassToast(
      context,
      now ? 'Added to your watchlist' : 'Removed from your watchlist',
      icon: now ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = ListItem.titleKey(
        widget.film.id, widget.film.isTv ? 'tv' : 'movie');
    final saved = _optimistic ??
        (ref.watch(myWatchlistKeysProvider).valueOrNull?.contains(key) ??
            false);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showAddToListSheet(context, widget.film);
      },
      child: IconButton(
        tooltip: saved ? 'On your watchlist' : 'Add to watchlist',
        icon: Icon(
          saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
          color: Colors.white,
        ),
        onPressed: () => _toggle(saved),
      ),
    );
  }
}
