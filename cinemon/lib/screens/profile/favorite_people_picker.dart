import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/person_model.dart';
import '../../providers/user/favorites_provider.dart';
import '../widgets/app_search_field.dart';
import '../widgets/glass_panel.dart';

// =============================================================================
// PARALLAX STAR FIELD
// =============================================================================

/// A star in the parallax field
class _Star {
  final double x; // 0.0 - 1.0 relative position
  final double y; // 0.0 - 1.0 relative position
  final double size;
  final double opacity;
  final double parallaxFactor; // How much this star moves relative to scroll

  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.parallaxFactor,
  });
}

/// Generates a list of stars with consistent positions (seeded random)
List<_Star> _generateStars(int count, int seed) {
  final random = math.Random(seed);
  return List.generate(count, (index) {
    return _Star(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 0.5 + random.nextDouble() * 1.5, // 0.5 - 2.0
      opacity: 0.3 + random.nextDouble() * 0.5, // 0.3 - 0.8
      parallaxFactor: 0.1 + random.nextDouble() * 0.3, // 0.1 - 0.4
    );
  });
}

/// Custom painter for the star field
class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double scrollOffset;
  final Color starColor;

  _StarFieldPainter({
    required this.stars,
    required this.scrollOffset,
    this.starColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      // Calculate parallax offset based on scroll
      final parallaxY = (scrollOffset * star.parallaxFactor) % size.height;

      // Star position with parallax
      final x = star.x * size.width;
      var y = (star.y * size.height) - parallaxY;

      // Wrap around for continuous effect
      if (y < 0) y += size.height;
      if (y > size.height) y -= size.height;

      final paint = Paint()
        ..color = starColor.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset;
  }
}

/// Widget that displays a parallax star field background
class ParallaxStarField extends StatefulWidget {
  final Widget child;
  final int starCount;
  final int seed;
  final Color starColor;

  const ParallaxStarField({
    super.key,
    required this.child,
    this.starCount = 30,
    this.seed = 42,
    this.starColor = Colors.white,
  });

  @override
  State<ParallaxStarField> createState() => _ParallaxStarFieldState();
}

class _ParallaxStarFieldState extends State<ParallaxStarField> {
  late List<_Star> _stars;
  double _scrollOffset = 0;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _stars = _generateStars(widget.starCount, widget.seed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the scroll position from the nearest Scrollable ancestor
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _scrollPosition?.removeListener(_onScroll);
      _scrollPosition = scrollable.position;
      _scrollPosition?.addListener(_onScroll);
      _onScroll(); // Initial update
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollPosition != null && mounted) {
      setState(() {
        _scrollOffset = _scrollPosition!.pixels;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Star field background
        Positioned.fill(
          child: CustomPaint(
            painter: _StarFieldPainter(
              stars: _stars,
              scrollOffset: _scrollOffset,
              starColor: widget.starColor,
            ),
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}

// =============================================================================
// PROFILE SECTION
// =============================================================================

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

    final list = peopleAsync.when(
      data: (people) => people.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildPeopleList(people),
      loading: () => _buildLoadingState(),
      error: (_, __) => _buildEmptyState(context, ref),
    );

    final editButton = isOwnProfile
        ? Padding(
            padding:
                const EdgeInsets.only(right: AppSpace.xl, top: AppSpace.sm),
            child: Align(
              alignment: Alignment.centerRight,
              child: GlassPillButton(
                label: personIds.isEmpty ? 'Add' : 'Edit',
                icon: personIds.isEmpty
                    ? CupertinoIcons.plus
                    : CupertinoIcons.pencil,
                compact: true,
                onTap: () => _showPeoplePicker(context, ref),
              ),
            ),
          )
        : const SizedBox.shrink();

    // Different layouts for actors (with PNG title + overlap) vs directors
    if (isActors) {
      return ParallaxStarField(
        starCount: 45,
        seed: 123, // Different seed for actors
        child: Column(
          children: [
            // Stack layout for actors - cards overlap the title
            SizedBox(
              height: 430,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Title PNG
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/images/favoriteactors.png',
                      width: MediaQuery.of(context).size.width,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                  // Actor cards - slightly overlapping the title
                  Positioned(
                    top: 250,
                    left: 0,
                    right: 0,
                    height: 190,
                    child: list,
                  ),
                ],
              ),
            ),
            editButton,
          ],
        ),
      );
    }

    // Directors layout - same as actors with PNG title
    return ParallaxStarField(
      starCount: 45,
      seed: 456, // Different seed for directors
      child: Column(
        children: [
          // Stack layout for directors - cards overlap the title
          SizedBox(
            height: 250,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Title PNG
                Positioned(
                  top: -150,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/directors.png',
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
                // Director cards - slightly overlapping the title
                Positioned(
                  top: 75,
                  left: 0,
                  right: 0,
                  height: 190,
                  child: list,
                ),
              ],
            ),
          ),
          editButton,
          const SizedBox(height: AppSpace.xl),
        ],
      ),
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
          child: _PersonCard(person: people[index]),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: GestureDetector(
        onTap: isOwnProfile ? () => _showPeoplePicker(context, ref) : null,
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.person_2,
                color: AppColors.inkTertiary,
                size: 28,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                isOwnProfile
                    ? 'Add your favorite ${isActors ? 'actors' : 'directors'}'
                    : 'No favorites yet',
                style: AppText.caption.copyWith(color: AppColors.inkSecondary),
              ),
            ],
          ),
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
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(45),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
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
    showGlassPanel(
      context,
      tall: true,
      builder: (_) => FavoritePeoplePickerSheet(
        currentPersonIds: personIds,
        title: title,
        isActors: isActors,
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonModel person;

  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => context.push('/person/${person.id}'),
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill-shaped photo. Monochrome: the only colour is the face.
            Container(
              width: 90,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(45),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(45),
                child: person.profilePath != null
                    ? CachedNetworkImage(
                        imageUrl: person.profileUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                        ),
                        errorWidget: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            // Name
            Text(
              person.name,
              style: AppText.caption.copyWith(
                color: AppColors.ink,
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(CupertinoIcons.person_fill,
            color: AppColors.inkTertiary, size: 32),
      ),
    );
  }
}

// =============================================================================
// PICKER PANEL
// =============================================================================

/// Floating glass picker for favorite actors or directors.
///
/// Presented with [showGlassPanel]. Selections are ranked in the order they
/// were picked and shown as numbered pills across the top; the search list
/// below fills the rest of the pane.
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

  static const maxSelections = 4;

  @override
  ConsumerState<FavoritePeoplePickerSheet> createState() =>
      _FavoritePeoplePickerSheetState();
}

class _FavoritePeoplePickerSheetState
    extends ConsumerState<FavoritePeoplePickerSheet> {
  final _searchController = TextEditingController();
  late List<int> _selectedPersonIds;
  Timer? _debounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedPersonIds = List.from(widget.currentPersonIds);
    // Clear any previous search results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(personSearchNotifierProvider.notifier).clear();
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
      ref.read(personSearchNotifierProvider.notifier).search(value);
      setState(() {});
    });
  }

  bool get _dirty {
    if (_selectedPersonIds.length != widget.currentPersonIds.length) {
      return true;
    }
    for (var i = 0; i < _selectedPersonIds.length; i++) {
      if (_selectedPersonIds[i] != widget.currentPersonIds[i]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(personSearchNotifierProvider);
    final noun = widget.isActors ? 'actors' : 'directors';
    final canSelect =
        _selectedPersonIds.length < FavoritePeoplePickerSheet.maxSelections;

    return Column(
      children: [
        GlassPanelHeader(
          title: widget.isActors ? 'Favorite Actors' : 'Favorite Directors',
          subtitle:
              '${_selectedPersonIds.length} of ${FavoritePeoplePickerSheet.maxSelections}  ·  in order',
          leadingLabel: 'Cancel',
          onLeading: () => Navigator.of(context).pop(),
          trailingLabel: _saving ? 'Saving…' : 'Done',
          trailingEnabled: _dirty && !_saving,
          onTrailing: _save,
        ),

        // Current selections, ranked.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _selectedPersonIds.isEmpty
              ? const SizedBox(width: double.infinity, height: AppSpace.sm)
              : SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
                    itemCount: _selectedPersonIds.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpace.lg),
                    itemBuilder: (context, index) => _SelectedPersonPill(
                      key: ValueKey(_selectedPersonIds[index]),
                      personId: _selectedPersonIds[index],
                      rank: index + 1,
                      onRemove: () => _removePerson(_selectedPersonIds[index]),
                    ),
                  ),
                ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
          child: AppSearchField(
            controller: _searchController,
            placeholder: 'Search $noun',
            autofocus: true,
            onGlass: true,
            onChanged: _onSearchChanged,
          ),
        ),

        // Results
        Expanded(
          child: searchResults.when(
            data: (people) {
              // Filter by department - be lenient, exclude opposite department
              final filtered = _searchController.text.isNotEmpty
                  ? people.where((p) {
                      if (widget.isActors) {
                        return p.knownForDepartment != 'Directing';
                      } else {
                        return p.knownForDepartment != 'Acting';
                      }
                    }).toList()
                  : people;

              if (filtered.isEmpty) {
                return _Hint(
                  icon: _searchController.text.isNotEmpty
                      ? CupertinoIcons.search
                      : CupertinoIcons.person_2,
                  text: _searchController.text.isNotEmpty
                      ? 'No $noun found'
                      : 'Search for ${widget.isActors ? 'an actor' : 'a director'}',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(left: 72),
                  child: Divider(),
                ),
                itemBuilder: (context, index) {
                  final person = filtered[index];
                  final isSelected = _selectedPersonIds.contains(person.id);
                  return _PersonSearchResult(
                    person: person,
                    isSelected: isSelected,
                    canSelect: canSelect,
                    rank: isSelected
                        ? _selectedPersonIds.indexOf(person.id) + 1
                        : null,
                    onTap: () => _togglePerson(person),
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

  void _togglePerson(PersonModel person) {
    setState(() {
      if (_selectedPersonIds.contains(person.id)) {
        _selectedPersonIds.remove(person.id);
      } else if (_selectedPersonIds.length <
          FavoritePeoplePickerSheet.maxSelections) {
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
    setState(() => _saving = true);
    final controller = ref.read(favoritesControllerProvider.notifier);
    if (widget.isActors) {
      await controller.setFavoriteActors(_selectedPersonIds);
    } else {
      await controller.setFavoriteDirectors(_selectedPersonIds);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
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

class _SelectedPersonPill extends ConsumerWidget {
  final int personId;
  final int rank;
  final VoidCallback onRemove;

  const _SelectedPersonPill({
    super.key,
    required this.personId,
    required this.rank,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personByIdProvider(personId));
    final person = personAsync.valueOrNull;

    return SizedBox(
      width: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: PillPortrait(
              imageUrl: person?.profileUrl,
              width: 56,
              height: 80,
            ),
          ),
          Positioned(left: -2, top: -2, child: RankBadge(rank: rank)),
          Positioned(
            right: -2,
            top: -2,
            child: RemoveBadge(onTap: onRemove),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 88,
            child: Text(
              person?.name.split(' ').last ?? '',
              style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSearchResult extends StatelessWidget {
  final PersonModel person;
  final bool isSelected;
  final bool canSelect;
  final int? rank;
  final VoidCallback onTap;

  const _PersonSearchResult({
    required this.person,
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
            PillPortrait(
              imageUrl: person.profileUrl,
              width: 44,
              height: 62,
              dim: dim,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: AppText.body.copyWith(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: dim ? AppColors.inkTertiary : AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (person.knownForDepartment != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      person.knownForDepartment!,
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
