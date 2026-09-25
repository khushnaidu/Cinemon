import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/library_entry.dart';
import '../../../providers/library/library_provider.dart';
import '../../library/add_to_library_panel.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/comments_sheet.dart' show GlassHint;
import '../../widgets/glass_panel.dart';

enum _Sort {
  recent('Recent'),
  title('A–Z'),
  year('Year');

  const _Sort(this.label);
  final String label;
}

enum _Kind { all, movies, shows }

/// A profile's Films tab: everything they've seen, posted about or not
/// (migration 024), as a wall of posters. On your own, Add films opens a
/// search to add many at once, and a long press takes one off.
class FilmsTab extends ConsumerStatefulWidget {
  const FilmsTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  ConsumerState<FilmsTab> createState() => _FilmsTabState();
}

class _FilmsTabState extends ConsumerState<FilmsTab> {
  _Sort _sort = _Sort.recent;
  _Kind _kind = _Kind.all;
  final _search = TextEditingController();
  String _query = '';

  /// A search box only once there's enough to search.
  static const _searchFrom = 24;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LibraryEntry> _shown(List<LibraryEntry> all) {
    final q = _query.toLowerCase();
    final list = [
      for (final e in all)
        if ((_kind == _Kind.all || (_kind == _Kind.shows) == e.isTv) &&
            (q.isEmpty || e.title.toLowerCase().contains(q)))
          e,
    ];
    switch (_sort) {
      case _Sort.recent:
        break; // Already newest first.
      case _Sort.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.year:
        list.sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
    }
    return list;
  }

  Future<void> _remove(LibraryEntry e) async {
    HapticFeedback.mediumImpact();
    final ok = await showGlassConfirm(
      context,
      title: 'Remove ${e.title}?',
      message: 'It comes out of your films. Anything you posted about it '
          'stays.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await ref.read(libraryActionsProvider).remove(e);
    if (!mounted) return;
    showGlassToast(
        context, done ? 'Removed ${e.title}' : "Couldn't remove that.",
        destructive: !done);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider(widget.userId));
    final all = library.valueOrNull ?? const <LibraryEntry>[];
    final shown = _shown(all);
    final shows = all.where((e) => e.isTv).length;

    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpace.lg, 20, AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  all.isEmpty
                      ? ''
                      : '${all.length} title${all.length == 1 ? '' : 's'}',
                  style:
                      AppText.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ),
              if (widget.isOwnProfile)
                GlassPillButton(
                  label: 'Add films',
                  icon: CupertinoIcons.plus,
                  compact: true,
                  onTap: () => showAddToLibraryPanel(context),
                ),
            ],
          ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in _Sort.values) ...[
                    GlassChip(
                      label: s.label,
                      selected: _sort == s,
                      onTap: () => setState(() => _sort = s),
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  // Films and Shows only when there's a mix.
                  if (shows > 0 && shows < all.length) ...[
                    const SizedBox(width: AppSpace.sm),
                    for (final k in _Kind.values) ...[
                      GlassChip(
                        label: switch (k) {
                          _Kind.all => 'All',
                          _Kind.movies => 'Films',
                          _Kind.shows => 'Shows',
                        },
                        selected: _kind == k,
                        onTap: () => setState(() => _kind = k),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                  ],
                ],
              ),
            ),
          ],
          if (all.length >= _searchFrom) ...[
            const SizedBox(height: AppSpace.md),
            AppSearchField(
              controller: _search,
              placeholder: widget.isOwnProfile
                  ? 'Search your films'
                  : 'Search their films',
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ],
        ],
      ),
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: controls),
        if (library.isLoading && all.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.xl),
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
          )
        else if (all.isEmpty)
          SliverToBoxAdapter(
            child: GlassHint(
              icon: CupertinoIcons.film,
              title:
                  widget.isOwnProfile ? 'Your films live here' : 'No films yet',
              body: widget.isOwnProfile
                  ? 'Add what you\'ve already seen with Add films, or tap the '
                      'eye on any film. Nothing gets posted.'
                  : 'Nothing they\'ve added yet.',
            ),
          )
        else if (shown.isEmpty)
          const SliverToBoxAdapter(
            child: GlassHint(
              icon: CupertinoIcons.search,
              title: 'No matches',
              body: '',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, AppSpace.sm, 20, 0),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSpace.sm,
                crossAxisSpacing: AppSpace.sm,
                childAspectRatio: 2 / 3,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final e = shown[i];
                return _Poster(
                  entry: e,
                  onTap: () => context
                      .push('/film/${e.filmId}/${e.isTv ? 'tv' : 'movie'}'),
                  onLongPress: widget.isOwnProfile ? () => _remove(e) : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.entry, required this.onTap, this.onLongPress});

  final LibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getPosterUrl(entry.posterPath,
        size: ApiConstants.posterSizeSmall);
    final fallback = Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpace.xs),
      child: Text(
        entry.title,
        style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Semantics(
      button: true,
      label: entry.title,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: GlassPressable(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: url.isEmpty
                ? fallback
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: AppColors.surfaceElevated),
                    errorWidget: (_, __, ___) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}
