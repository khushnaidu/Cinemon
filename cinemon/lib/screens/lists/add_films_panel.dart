import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../providers/lists/list_provider.dart';
import '../../providers/movie/movie_provider.dart';
import '../explore/subject_picker.dart' show MediaResultRow;
import '../widgets/app_search_field.dart';
import '../widgets/comments_sheet.dart' show GlassHint;
import '../widgets/glass_panel.dart';

/// Search and tick titles onto a playlist. Each tap adds or removes straight
/// away, so there's nothing to lose by closing it.
Future<void> showAddFilmsPanel(BuildContext context, FilmList list) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (_) => _AddFilms(list: list),
  );
}

class _AddFilms extends ConsumerStatefulWidget {
  const _AddFilms({required this.list});

  final FilmList list;

  @override
  ConsumerState<_AddFilms> createState() => _AddFilmsState();
}

class _AddFilmsState extends ConsumerState<_AddFilms> {
  final _query = TextEditingController();
  Timer? _debounce;
  MediaType _scope = MediaType.movie;
  String _term = '';
  final _pending = <String, bool>{};
  int _added = 0;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _term = value.trim());
    });
  }

  Future<void> _toggle(FilmModel film, bool on) async {
    HapticFeedback.selectionClick();
    final key = ListItem.titleKey(film.id, film.isTv ? 'tv' : 'movie');
    setState(() => _pending[key] = !on);
    final now = await ref
        .read(playlistActionsProvider)
        .toggle(widget.list.id, film, on: on);
    if (!mounted) return;
    setState(() {
      _pending.remove(key);
      if (now != null) _added += now ? 1 : -1;
    });
    if (now == null) {
      showGlassToast(context, "Couldn't update the playlist.",
          destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = _scope == MediaType.tv;
    final results = _term.isEmpty
        ? ref.watch(isTv ? trendingTvShowsProvider : trendingMoviesProvider)
        : ref.watch(isTv
            ? searchTvOnlyProvider(_term)
            : searchMoviesOnlyProvider(_term));
    final onList = {
      for (final i
          in ref.watch(listItemsProvider(widget.list.id)).valueOrNull ??
              const <ListItem>[])
        i.key,
    };

    return Column(
      children: [
        GlassPanelHeader(
          title: 'Add to ${widget.list.displayTitle}',
          subtitle: _added > 0 ? '$_added added' : null,
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: GlassSegmentedControl(
            labels: const ['Films', 'Shows'],
            index: isTv ? 1 : 0,
            onChanged: (i) => setState(
                () => _scope = i == 1 ? MediaType.tv : MediaType.movie),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: AppSearchField(
            controller: _query,
            onChanged: _onChanged,
            onGlass: true,
            placeholder: isTv ? 'Search shows' : 'Search films',
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Expanded(
          child: results.when(
            loading: () => const Center(
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
            error: (_, __) => const GlassHint(
              icon: CupertinoIcons.wifi_exclamationmark,
              title: 'Couldn\'t search',
              body: 'Check your connection and try again.',
            ),
            data: (films) => ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.md, AppSpace.lg),
              itemCount: films.length,
              itemBuilder: (_, i) {
                final film = films[i];
                final key =
                    ListItem.titleKey(film.id, film.isTv ? 'tv' : 'movie');
                final on = _pending[key] ?? onList.contains(key);
                return Row(
                  children: [
                    Expanded(
                      child: MediaResultRow(
                        film: film,
                        onTap: () => _toggle(film, on),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggle(film, on),
                      child: Icon(
                        on
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.plus_circle,
                        size: 26,
                        color: on ? AppColors.ink : AppColors.inkTertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
