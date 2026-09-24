import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/film_model.dart';
import '../../providers/movie/movie_provider.dart';
import '../../providers/user/favorites_provider.dart';
import '../../repositories/movie_repository.dart';
import '../widgets/app_search_field.dart';
import '../widgets/glass_panel.dart';

/// Search scoped to one media type, so the films picker never offers a show
/// and the shows picker never offers a film. Keyed by type so the two panels
/// don't share (and clobber) each other's results.
class _ScopedSearchNotifier extends StateNotifier<AsyncValue<List<FilmModel>>> {
  _ScopedSearchNotifier(this._repository, this._type)
      : super(const AsyncValue.data([]));

  final MovieRepository _repository;
  final MediaType _type;
  String _lastQuery = '';

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _lastQuery = '';
      state = const AsyncValue.data([]);
      return;
    }
    if (query == _lastQuery) return;
    _lastQuery = query;
    state = const AsyncValue.loading();
    try {
      final results = _type == MediaType.tv
          ? await _repository.searchTvShows(query)
          : await _repository.searchMovies(query);
      if (query == _lastQuery) state = AsyncValue.data(results);
    } catch (e, st) {
      if (query == _lastQuery) state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }
}

final _scopedSearchProvider = StateNotifierProvider.family<
    _ScopedSearchNotifier, AsyncValue<List<FilmModel>>, MediaType>(
  (ref, type) =>
      _ScopedSearchNotifier(ref.watch(movieRepositoryProvider), type),
);

/// Floating glass picker for the top 3 films — or, with
/// [mediaType] set to [MediaType.tv], the top 3 shows.
///
/// Presented with [showGlassPanel]. Picks are ranked in the order they were
/// made and shown as numbered posters across the top.
class FavoriteFilmsPickerSheet extends ConsumerStatefulWidget {
  final List<int> currentFilmIds;
  final MediaType mediaType;

  const FavoriteFilmsPickerSheet({
    super.key,
    required this.currentFilmIds,
    this.mediaType = MediaType.movie,
  });

  static const maxSelections = 3;

  @override
  ConsumerState<FavoriteFilmsPickerSheet> createState() =>
      _FavoriteFilmsPickerSheetState();
}

class _FavoriteFilmsPickerSheetState
    extends ConsumerState<FavoriteFilmsPickerSheet> {
  final _searchController = TextEditingController();
  late List<int> _selectedIds;
  Timer? _debounce;
  bool _saving = false;

  bool get _isTv => widget.mediaType == MediaType.tv;
  String get _noun => _isTv ? 'shows' : 'films';

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentFilmIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_scopedSearchProvider(widget.mediaType).notifier).clear();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(_scopedSearchProvider(widget.mediaType).notifier).search(value);
      setState(() {});
    });
  }

  bool get _dirty {
    if (_selectedIds.length != widget.currentFilmIds.length) return true;
    for (var i = 0; i < _selectedIds.length; i++) {
      if (_selectedIds[i] != widget.currentFilmIds[i]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(_scopedSearchProvider(widget.mediaType));
    final canSelect =
        _selectedIds.length < FavoriteFilmsPickerSheet.maxSelections;

    return Column(
      children: [
        GlassPanelHeader(
          title: _isTv ? 'Top 3 Shows' : 'Top 3 Films',
          subtitle:
              '${_selectedIds.length} of ${FavoriteFilmsPickerSheet.maxSelections}  ·  1st, 2nd, 3rd',
          leadingLabel: 'Cancel',
          onLeading: () => Navigator.of(context).pop(),
          trailingLabel: _saving ? 'Saving…' : 'Done',
          trailingEnabled: _dirty && !_saving,
          onTrailing: _save,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _selectedIds.isEmpty
              ? const SizedBox(width: double.infinity, height: AppSpace.sm)
              : SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                    itemCount: _selectedIds.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpace.lg),
                    itemBuilder: (context, index) => _SelectedPoster(
                      key: ValueKey(_selectedIds[index]),
                      filmId: _selectedIds[index],
                      mediaType: widget.mediaType,
                      rank: index + 1,
                      onRemove: () => _remove(_selectedIds[index]),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
          child: AppSearchField(
            controller: _searchController,
            placeholder: 'Search $_noun',
            autofocus: true,
            onGlass: true,
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: searchResults.when(
            data: (films) {
              if (films.isEmpty) {
                return _Hint(
                  icon: _searchController.text.isNotEmpty
                      ? CupertinoIcons.search
                      : (_isTv ? CupertinoIcons.tv : CupertinoIcons.film),
                  text: _searchController.text.isNotEmpty
                      ? 'No $_noun found'
                      : 'Search for a ${_isTv ? 'show' : 'film'} to add',
                );
              }
              return ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                itemCount: films.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(left: 72),
                  child: Divider(),
                ),
                itemBuilder: (context, index) {
                  final film = films[index];
                  final isSelected = _selectedIds.contains(film.id);
                  return _FilmSearchResult(
                    film: film,
                    isSelected: isSelected,
                    canSelect: canSelect,
                    rank: isSelected ? _selectedIds.indexOf(film.id) + 1 : null,
                    onTap: () => _toggle(film),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CupertinoActivityIndicator(color: AppColors.ink),
            ),
            error: (_, __) => const _Hint(
              icon: CupertinoIcons.wifi_exclamationmark,
              text: 'Couldn\'t reach the movie database',
            ),
          ),
        ),
      ],
    );
  }

  void _toggle(FilmModel film) {
    setState(() {
      if (_selectedIds.contains(film.id)) {
        _selectedIds.remove(film.id);
      } else if (_selectedIds.length < FavoriteFilmsPickerSheet.maxSelections) {
        _selectedIds.add(film.id);
      }
    });
  }

  void _remove(int id) => setState(() => _selectedIds.remove(id));

  Future<void> _save() async {
    setState(() => _saving = true);
    final controller = ref.read(favoritesControllerProvider.notifier);
    if (_isTv) {
      await controller.setFavoriteShows(_selectedIds);
    } else {
      await controller.setFavoriteFilms(_selectedIds);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.inkTertiary, size: 30),
          const SizedBox(height: AppSpace.md),
          Text(
            text,
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A poster with rounded corners. Posters are artwork with their own
/// composition, so they keep their rectangle; only people get the capsule.
class _Poster extends StatelessWidget {
  const _Poster({
    required this.posterPath,
    this.width = 56,
    this.height = 84,
    this.dim = false,
  });

  final String? posterPath;
  final double width;
  final double height;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.sm + 2);
    final placeholder = Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.film,
          color: AppColors.inkTertiary, size: 20),
    );
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: posterPath == null
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: 'https://image.tmdb.org/t/p/w185$posterPath',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _SelectedPoster extends ConsumerWidget {
  final int filmId;
  final MediaType mediaType;
  final int rank;
  final VoidCallback onRemove;

  const _SelectedPoster({
    super.key,
    required this.filmId,
    required this.mediaType,
    required this.rank,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filmAsync = mediaType == MediaType.tv
        ? ref.watch(tvDetailsProvider(filmId))
        : ref.watch(movieDetailsProvider(filmId));
    final film = filmAsync.valueOrNull;

    return SizedBox(
      width: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: _Poster(posterPath: film?.posterPath),
          ),
          Positioned(left: -2, top: -2, child: RankBadge(rank: rank)),
          Positioned(right: -2, top: -2, child: RemoveBadge(onTap: onRemove)),
          Positioned(
            left: 0,
            right: 0,
            top: 92,
            child: Text(
              film?.year ?? '',
              style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilmSearchResult extends StatelessWidget {
  final FilmModel film;
  final bool isSelected;
  final bool canSelect;
  final int? rank;
  final VoidCallback onTap;

  const _FilmSearchResult({
    required this.film,
    required this.isSelected,
    required this.canSelect,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canSelect || isSelected;
    final dim = !enabled;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      highlightColor: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm, vertical: AppSpace.sm),
        child: Row(
          children: [
            _Poster(
                posterPath: film.posterPath, width: 44, height: 64, dim: dim),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.displayTitle,
                    style: AppText.body.copyWith(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: dim ? AppColors.inkTertiary : AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (film.year != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      film.year!,
                      style: AppText.caption.copyWith(
                        color: dim
                            ? AppColors.inkQuaternary
                            : AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            if (isSelected)
              RankBadge(rank: rank ?? 0)
            else
              Icon(
                CupertinoIcons.plus_circle,
                color: dim ? AppColors.inkQuaternary : AppColors.inkSecondary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
