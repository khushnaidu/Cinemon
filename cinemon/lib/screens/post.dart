import 'dart:async';
import '../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'widgets/app_search_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../models/film_model.dart';
import '../models/person_model.dart';
import '../providers/movie/movie_provider.dart';
import '../repositories/movie_repository.dart';
import 'widgets/glass_panel.dart';

/// Search scoped to films, shows or people. The tab's toggle picks which,
/// and each scope keeps its own results so flipping back doesn't refetch.
class _SearchScopeNotifier extends StateNotifier<AsyncValue<List<FilmModel>>> {
  _SearchScopeNotifier(this._repository, this._type)
      : super(const AsyncValue.data([]));

  final MovieRepository _repository;
  final MediaType _type;
  String _lastQuery = '';

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clear();
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

final _searchScopeProvider = StateNotifierProvider.family<_SearchScopeNotifier,
    AsyncValue<List<FilmModel>>, MediaType>(
  (ref, type) => _SearchScopeNotifier(ref.watch(movieRepositoryProvider), type),
);

/// The People scope: the same debounced, last-query-wins search.
class _PeopleSearchNotifier
    extends StateNotifier<AsyncValue<List<PersonModel>>> {
  _PeopleSearchNotifier(this._repository) : super(const AsyncValue.data([]));

  final MovieRepository _repository;
  String _lastQuery = '';

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clear();
      return;
    }
    if (query == _lastQuery) return;
    _lastQuery = query;
    state = const AsyncValue.loading();
    try {
      final results = await _repository.searchPeople(query);
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

final _peopleSearchProvider = StateNotifierProvider<_PeopleSearchNotifier,
    AsyncValue<List<PersonModel>>>(
  (ref) => _PeopleSearchNotifier(ref.watch(movieRepositoryProvider)),
);

enum _Scope { films, shows, people }

/// Movie search/lookup page - search for films and navigate to their detail page
class MovieSearchPage extends ConsumerStatefulWidget {
  const MovieSearchPage({super.key});

  @override
  ConsumerState<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends ConsumerState<MovieSearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  _Scope _scope = _Scope.films;

  bool get _isTv => _scope == _Scope.shows;
  bool get _isPeople => _scope == _Scope.people;
  MediaType get _mediaType => _isTv ? MediaType.tv : MediaType.movie;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _isSearching = query.isNotEmpty;
      });
      _runSearch(query);
    });
  }

  void _runSearch(String query) {
    if (_isPeople) {
      final notifier = ref.read(_peopleSearchProvider.notifier);
      query.isNotEmpty ? notifier.search(query) : notifier.clear();
      return;
    }
    final notifier = ref.read(_searchScopeProvider(_mediaType).notifier);
    if (query.isNotEmpty) {
      notifier.search(query);
    } else {
      notifier.clear();
    }
  }

  void _setScope(int index) {
    setState(() => _scope = _Scope.values[index]);
    // Re-run the live query in the new scope so the list matches the toggle.
    _runSearch(_searchController.text);
  }

  void _onFilmSelected(FilmModel film) {
    final mediaType = film.isMovie ? 'movie' : 'tv';
    context.push('/film/${film.id}/$mediaType');
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(_searchScopeProvider(_mediaType));
    final trendingMovies =
        ref.watch(_isTv ? trendingTvShowsProvider : trendingMoviesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              AppColors.canvas,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with the films / shows toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Text('Search', style: AppText.title),
                    const Spacer(),
                    SizedBox(
                      width: 216,
                      child: GlassSegmentedControl(
                        labels: const ['Films', 'Shows', 'People'],
                        index: _scope.index,
                        onChanged: _setScope,
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  placeholder: switch (_scope) {
                    _Scope.films => 'Search films',
                    _Scope.shows => 'Search shows',
                    _Scope.people => 'Search actors, directors…',
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Section title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _isSearching
                      ? 'Results'
                      : switch (_scope) {
                          _Scope.films => 'Trending Films',
                          _Scope.shows => 'Trending Shows',
                          _Scope.people => 'Trending People',
                        },
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Results grid
              Expanded(
                child: _isPeople
                    ? _buildPeople(_isSearching
                        ? ref.watch(_peopleSearchProvider)
                        : ref.watch(trendingPeopleProvider))
                    : _isSearching
                        ? _buildSearchResults(searchResults)
                        : _buildTrendingMovies(trendingMovies),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<FilmModel>> searchResults) {
    return searchResults.when(
      loading: () => _buildLoadingGrid(),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
      data: (films) {
        if (films.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          );
        }
        return _buildFilmGrid(films);
      },
    );
  }

  Widget _buildTrendingMovies(AsyncValue<List<FilmModel>> trendingMovies) {
    return trendingMovies.when(
      loading: () => _buildLoadingGrid(),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Failed to load movies',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.refresh(
                  _isTv ? trendingTvShowsProvider : trendingMoviesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (films) => _buildFilmGrid(films),
    );
  }

  Widget _buildFilmGrid(List<FilmModel> films) {
    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: films.length,
      itemBuilder: (context, index) {
        final film = films[index];
        return _FilmPosterCard(
          film: film,
          onTap: () => _onFilmSelected(film),
        );
      },
    );
  }

  Widget _buildPeople(AsyncValue<List<PersonModel>> people) {
    return people.when(
      loading: () => _buildLoadingGrid(),
      error: (_, __) => Center(
        child: Text(
          "Couldn't load people.",
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No one found',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          );
        }
        return GridView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.56,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) => _PersonCard(person: list[i]),
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}

/// A person in the People grid: pill portrait, name, what they're known for.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final PersonModel person;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => context.push('/person/${person.id}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Column(
            children: [
              PillPortrait(
                imageUrl: person.profileUrlLarge,
                width: w * 0.86,
                height: w * 0.86 * 1.42,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                person.name,
                style: AppText.footnote.copyWith(color: AppColors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (person.knownForDepartment != null)
                Text(
                  person.knownForDepartment == 'Production'
                      ? 'Producing'
                      : person.knownForDepartment!,
                  style: AppText.footnote.copyWith(
                      color: AppColors.inkTertiary, fontSize: 11),
                  maxLines: 1,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Film poster card widget
class _FilmPosterCard extends StatelessWidget {
  final FilmModel film;
  final VoidCallback onTap;

  const _FilmPosterCard({required this.film, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: film.posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: film.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie, color: Colors.grey[700], size: 32),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              film.displayTitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
