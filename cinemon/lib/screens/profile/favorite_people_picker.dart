import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/person_model.dart';
import '../../providers/user/favorites_provider.dart';

/// Section displaying favorite actors or directors as horizontal scroll
class FavoritePeopleSection extends ConsumerWidget {
  final List<int> personIds;
  final bool isOwnProfile;
  final String title;
  final bool isActors; // true for actors, false for directors

  const FavoritePeopleSection({
    super.key,
    required this.personIds,
    required this.isOwnProfile,
    required this.title,
    required this.isActors,
  });

  // Get gradient colors based on type
  List<Color> get _gradientColors => isActors
      ? [const Color(0xFF22D3EE), const Color(0xFF3B82F6)]
      : [const Color(0xFFF97316), const Color(0xFFEF4444)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show section if empty and not own profile
    if (personIds.isEmpty && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    // Only watch provider if we have IDs to fetch
    final peopleAsync = personIds.isNotEmpty
        ? ref.watch(peopleByIdsProvider(personIds))
        : const AsyncValue<List<PersonModel>>.data([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stylized section header with edit button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: _gradientColors,
                ).createShader(bounds),
                child: Text(
                  isActors ? 'favorite actors' : 'favorite directors',
                  style: const TextStyle(
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
                  onTap: () => _showPeoplePicker(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      personIds.isEmpty ? 'add' : 'edit',
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
        // People horizontal scroll
        SizedBox(
          height: 140,
          child: peopleAsync.when(
            data: (people) => people.isEmpty
                ? _buildEmptyState()
                : _buildPeopleList(people),
            loading: () => _buildLoadingState(),
            error: (_, __) => _buildEmptyState(),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPeopleList(List<PersonModel> people) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: people.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _PersonCard(
            person: people[index],
            accentColor: _gradientColors[0],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _gradientColors[0].withOpacity(0.1),
              _gradientColors[1].withOpacity(0.05),
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
              Icons.person_outline,
              color: Colors.white.withOpacity(0.3),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? 'Add your favorite ${isActors ? 'actors' : 'directors'}'
                  : 'No favorites yet',
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
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPeoplePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FavoritePeoplePickerSheet(
        currentPersonIds: personIds,
        title: title,
        isActors: isActors,
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonModel person;
  final Color accentColor;

  const _PersonCard({
    required this.person,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular photo with colored border
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor,
                  accentColor.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0a0a14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: person.profilePath != null
                        ? CachedNetworkImage(
                            imageUrl: person.profileUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1a1a2e),
                            ),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Name
          Text(
            person.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1a1a2e),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white24, size: 36),
      ),
    );
  }
}

/// Bottom sheet for picking favorite people
class FavoritePeoplePickerSheet extends ConsumerStatefulWidget {
  final List<int> currentPersonIds;
  final String title;
  final bool isActors;

  const FavoritePeoplePickerSheet({
    super.key,
    required this.currentPersonIds,
    required this.title,
    required this.isActors,
  });

  @override
  ConsumerState<FavoritePeoplePickerSheet> createState() => _FavoritePeoplePickerSheetState();
}

class _FavoritePeoplePickerSheetState extends ConsumerState<FavoritePeoplePickerSheet> {
  final _searchController = TextEditingController();
  late List<int> _selectedPersonIds;

  List<Color> get _gradientColors => widget.isActors
      ? [const Color(0xFF22D3EE), const Color(0xFF3B82F6)]
      : [const Color(0xFFF97316), const Color(0xFFEF4444)];

  @override
  void initState() {
    super.initState();
    _selectedPersonIds = List.from(widget.currentPersonIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(personSearchNotifierProvider);

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
            shaderCallback: (bounds) => LinearGradient(
              colors: _gradientColors,
            ).createShader(bounds),
            child: Text(
              widget.isActors ? 'favorite actors' : 'favorite directors',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedPersonIds.length}/4 selected',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // Current selections (if any)
          if (_selectedPersonIds.isNotEmpty) ...[
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedPersonIds.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _SelectedPersonChip(
                      personId: _selectedPersonIds[index],
                      accentColor: _gradientColors[0],
                      onRemove: () => _removePerson(_selectedPersonIds[index]),
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
                hintText: widget.isActors ? 'Search actors...' : 'Search directors...',
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
                ref.read(personSearchNotifierProvider.notifier).search(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Search results
          Expanded(
            child: searchResults.when(
              data: (people) {
                // Filter by department
                final filtered = _searchController.text.isNotEmpty
                    ? people.where((p) {
                        if (widget.isActors) {
                          return p.knownForDepartment == 'Acting' || p.knownForDepartment == null;
                        } else {
                          return p.knownForDepartment == 'Directing' || p.knownForDepartment == null;
                        }
                      }).toList()
                    : people;

                if (filtered.isEmpty && _searchController.text.isNotEmpty) {
                  return Center(
                    child: Text(
                      widget.isActors ? 'No actors found' : 'No directors found',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      widget.isActors ? 'Search for an actor' : 'Search for a director',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    final isSelected = _selectedPersonIds.contains(person.id);
                    return _PersonSearchResult(
                      person: person,
                      isSelected: isSelected,
                      canSelect: _selectedPersonIds.length < 4,
                      accentColor: _gradientColors[0],
                      onTap: () => _togglePerson(person),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_gradientColors[0]),
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
                    backgroundColor: _gradientColors[0],
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

  void _togglePerson(PersonModel person) {
    setState(() {
      if (_selectedPersonIds.contains(person.id)) {
        _selectedPersonIds.remove(person.id);
      } else if (_selectedPersonIds.length < 4) {
        _selectedPersonIds.add(person.id);
      }
    });
  }

  void _removePerson(int personId) {
    setState(() {
      _selectedPersonIds.remove(personId);
    });
  }

  Future<void> _save() async {
    final controller = ref.read(favoritesControllerProvider.notifier);
    if (widget.isActors) {
      await controller.setFavoriteActors(_selectedPersonIds);
    } else {
      await controller.setFavoriteDirectors(_selectedPersonIds);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _SelectedPersonChip extends ConsumerWidget {
  final int personId;
  final Color accentColor;
  final VoidCallback onRemove;

  const _SelectedPersonChip({
    required this.personId,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(peopleByIdsProvider([personId]));

    return personAsync.when(
      data: (people) {
        if (people.isEmpty) return const SizedBox.shrink();
        final person = people.first;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(
                child: person.profilePath != null
                    ? CachedNetworkImage(
                        imageUrl: person.profileUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color(0xFF1a1a2e),
                        child: const Icon(Icons.person, color: Colors.white24, size: 30),
                      ),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
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
                  child: const Icon(Icons.close, color: Colors.white, size: 10),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      error: (_, __) => Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: const Icon(Icons.error, color: Colors.red, size: 16),
      ),
    );
  }
}

class _PersonSearchResult extends StatelessWidget {
  final PersonModel person;
  final bool isSelected;
  final bool canSelect;
  final Color accentColor;
  final VoidCallback onTap;

  const _PersonSearchResult({
    required this.person,
    required this.isSelected,
    required this.canSelect,
    required this.accentColor,
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
              ? accentColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: accentColor.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: accentColor, width: 2)
                    : null,
              ),
              child: ClipOval(
                child: person.profilePath != null
                    ? CachedNetworkImage(
                        imageUrl: person.profileUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color(0xFF1a1a2e),
                        child: const Icon(Icons.person, color: Colors.white24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
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
                    person.knownForDepartment ?? '',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor, size: 22)
            else if (canSelect)
              Icon(Icons.add_circle_outline, color: Colors.white.withOpacity(0.3), size: 22),
          ],
        ),
      ),
    );
  }
}
