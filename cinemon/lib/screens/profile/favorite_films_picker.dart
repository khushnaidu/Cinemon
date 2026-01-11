import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/film_model.dart';
import '../../providers/movie/movie_provider.dart';
import '../../providers/user/favorites_provider.dart';

/// Section displaying favorite films as horizontal scroll
class FavoriteFilmsSection extends ConsumerWidget {
  final List<int> filmIds;
  final bool isOwnProfile;

  const FavoriteFilmsSection({
    super.key,
    required this.filmIds,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filmsAsync = ref.watch(favoriteFilmsDataProvider(filmIds));

    // Don't show section if empty and not own profile
    if (filmIds.isEmpty && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stylized section header with edit button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF9B8BF4), Color(0xFFE879F9)],
                ).createShader(bounds),
                child: const Text(
                  'favorite films',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (isOwnProfile)
                GestureDetector(
                  onTap: () => _showFilmPicker(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      filmIds.isEmpty ? 'add' : 'edit',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Films horizontal scroll
        SizedBox(
          height: 180,
          child: filmsAsync.when(
            data: (films) => films.isEmpty
                ? _buildEmptyState()
                : _buildFilmsList(context, films),
            loading: () => _buildLoadingState(),
            error: (_, __) => _buildEmptyState(),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildFilmsList(BuildContext context, List<FilmModel> films) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: films.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _FilmCard(film: films[index]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF9B8BF4).withOpacity(0.1),
              const Color(0xFFE879F9).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile ? 'Add your favorite films' : 'No favorites yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  void _showFilmPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FavoriteFilmsPickerSheet(currentFilmIds: filmIds),
    );
  }
}

class _FilmCard extends StatelessWidget {
  final FilmModel film;

  const _FilmCard({required this.film});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final mediaType = film.isMovie ? 'movie' : 'tv';
        context.push('/film/${film.id}/$mediaType');
      },
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Poster with gradient border effect
            Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B8BF4).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: film.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w300${film.posterPath}',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1a1a2e),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1a1a2e),
                              child: const Icon(Icons.movie, color: Colors.white24),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1a1a2e),
                            child: const Icon(Icons.movie, color: Colors.white24),
                          ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Film title
            Text(
              film.displayTitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking favorite films
class FavoriteFilmsPickerSheet extends ConsumerStatefulWidget {
  final List<int> currentFilmIds;

  const FavoriteFilmsPickerSheet({
    super.key,
    required this.currentFilmIds,
  });

  @override
  ConsumerState<FavoriteFilmsPickerSheet> createState() => _FavoriteFilmsPickerSheetState();
}

class _FavoriteFilmsPickerSheetState extends ConsumerState<FavoriteFilmsPickerSheet> {
  final _searchController = TextEditingController();
  late List<int> _selectedFilmIds;

  @override
  void initState() {
    super.initState();
    _selectedFilmIds = List.from(widget.currentFilmIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchNotifierProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0a0a14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF9B8BF4), Color(0xFFE879F9)],
            ).createShader(bounds),
            child: const Text(
              'favorite films',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedFilmIds.length}/4 selected',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // Current selections (if any)
          if (_selectedFilmIds.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedFilmIds.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _SelectedFilmChip(
                      filmId: _selectedFilmIds[index],
                      onRemove: () => _removeFilm(_selectedFilmIds[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search films...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                ref.read(searchNotifierProvider.notifier).search(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Search results
          Expanded(
            child: searchResults.when(
              data: (films) {
                if (films.isEmpty && _searchController.text.isNotEmpty) {
                  return const Center(
                    child: Text(
                      'No films found',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                if (films.isEmpty) {
                  return const Center(
                    child: Text(
                      'Search for a film to add',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: films.length,
                  itemBuilder: (context, index) {
                    final film = films[index];
                    final isSelected = _selectedFilmIds.contains(film.id);
                    return _FilmSearchResult(
                      film: film,
                      isSelected: isSelected,
                      canSelect: _selectedFilmIds.length < 4,
                      onTap: () => _toggleFilm(film),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B8BF4)),
                ),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Error searching',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B8BF4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilm(FilmModel film) {
    setState(() {
      if (_selectedFilmIds.contains(film.id)) {
        _selectedFilmIds.remove(film.id);
      } else if (_selectedFilmIds.length < 4) {
        _selectedFilmIds.add(film.id);
      }
    });
  }

  void _removeFilm(int filmId) {
    setState(() {
      _selectedFilmIds.remove(filmId);
    });
  }

  Future<void> _save() async {
    await ref.read(favoritesControllerProvider.notifier).setFavoriteFilms(_selectedFilmIds);
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _SelectedFilmChip extends ConsumerWidget {
  final int filmId;
  final VoidCallback onRemove;

  const _SelectedFilmChip({
    required this.filmId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filmAsync = ref.watch(movieDetailsProvider(filmId));

    return filmAsync.when(
      data: (film) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 65,
            height: 95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B8BF4).withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w185${film.posterPath}',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
      loading: () => Container(
        width: 65,
        height: 95,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      error: (_, __) => Container(
        width: 65,
        height: 95,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.error, color: Colors.red, size: 16),
      ),
    );
  }
}

class _FilmSearchResult extends StatelessWidget {
  final FilmModel film;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  const _FilmSearchResult({
    required this.film,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (canSelect || isSelected) ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9B8BF4).withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF9B8BF4).withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: film.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w92${film.posterPath}',
                      width: 45,
                      height: 65,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 45,
                      height: 65,
                      color: const Color(0xFF1a1a2e),
                      child: const Icon(Icons.movie, color: Colors.white24, size: 20),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.displayTitle,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (canSelect ? Colors.white : Colors.white38),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    film.year ?? '',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF9B8BF4), size: 22)
            else if (canSelect)
              Icon(Icons.add_circle_outline, color: Colors.white.withOpacity(0.3), size: 22),
          ],
        ),
      ),
    );
  }
}
