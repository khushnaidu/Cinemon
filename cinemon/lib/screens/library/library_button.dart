import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/film_model.dart';
import '../../models/library_entry.dart';
import '../../providers/library/library_provider.dart';
import '../widgets/glass_panel.dart';

/// Watched: puts a title in your library without posting about it, beside
/// the watchlist button on a film's page.
class LibraryButton extends ConsumerStatefulWidget {
  const LibraryButton({super.key, required this.film});

  final FilmModel film;

  @override
  ConsumerState<LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends ConsumerState<LibraryButton> {
  /// Shown while the write is in flight, so the tap lands instantly.
  bool? _optimistic;

  Future<void> _toggle(bool current) async {
    HapticFeedback.lightImpact();
    setState(() => _optimistic = !current);
    final now = await ref
        .read(libraryActionsProvider)
        .toggle(widget.film, inLibrary: current);
    if (!mounted) return;
    setState(() => _optimistic = null);
    if (now == null) {
      showGlassToast(context, "Couldn't update your films.", destructive: true);
      return;
    }
    showGlassToast(
      context,
      now ? 'Added to your films' : 'Removed from your films',
      icon: now ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key =
        LibraryEntry.keyFor(widget.film.id, widget.film.isTv ? 'tv' : 'movie');
    final seen = _optimistic ??
        (ref.watch(myLibraryKeysProvider).valueOrNull?.contains(key) ?? false);
    return IconButton(
      tooltip: seen ? 'In your films' : 'Mark as watched',
      icon: Icon(
        seen ? CupertinoIcons.eye_fill : CupertinoIcons.eye,
        color: Colors.white,
      ),
      onPressed: () => _toggle(seen),
    );
  }
}
