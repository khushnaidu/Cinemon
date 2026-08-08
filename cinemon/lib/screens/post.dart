import 'dart:async';
import '../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'widgets/app_search_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../models/film_model.dart';
import '../providers/movie/movie_provider.dart';

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
      if (query.isNotEmpty) {
        ref.read(searchNotifierProvider.notifier).search(query);
      } else {
        ref.read(searchNotifierProvider.notifier).clear();
      }
    });
  }

  void _onFilmSelected(FilmModel film) {
    final mediaType = film.isMovie ? 'movie' : 'tv';
    context.push('/film/${film.id}/$mediaType');
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchNotifierProvider);
    final trendingMovies = ref.watch(trendingMoviesProvider);

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
              // Header
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Search Films',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  placeholder: 'Movies & TV shows',
                ),
              ),

              const SizedBox(height: 20),

              // Section title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _isSearching ? 'Search Results' : 'Trending This Week',
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
                child: _isSearching
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
              onPressed: () => ref.refresh(trendingMoviesProvider),
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

  Widget _buildLoadingGrid() {
    return GridView.builder(
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

