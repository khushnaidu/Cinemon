import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/person_page.dart';
import '../../providers/feed/feed_provider.dart'
    show currentUserProfileProvider, personHistoryProvider;
import '../../providers/movie/movie_provider.dart';
import '../../providers/person/person_follow_provider.dart';
import '../../providers/user/favorites_provider.dart'
    show favoritesControllerProvider;
import '../widgets/glass_panel.dart';

/// `/person/:personId`: who someone is, what they're known for, everything
/// they've made, and how much of it you've logged (ADR 0001, Phase 2).
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(personPageProvider(personId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: page.when(
        loading: () => const _Frame(
          child: SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, __) => _Frame(
          child: SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Couldn't load this person.",
                      style:
                          AppText.body.copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: AppSpace.md),
                  GlassPillButton(
                    label: 'Try again',
                    compact: true,
                    onTap: () => ref.invalidate(personPageProvider(personId)),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (person) => _PersonContent(person: person),
      ),
    );
  }
}

/// The scroll view and back button, shared by every state.
class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.slivers = const []});

  final Widget child;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          floating: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            // Opened from a link, there's nothing underneath.
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        child,
        ...slivers,
      ],
    );
  }
}

class _PersonContent extends ConsumerStatefulWidget {
  const _PersonContent({required this.person});

  final PersonPage person;

  @override
  ConsumerState<_PersonContent> createState() => _PersonContentState();
}

class _PersonContentState extends ConsumerState<_PersonContent> {
  late String? _department = widget.person.defaultDepartment;

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final departments = person.availableDepartments;
    final knownFor = person.knownFor;
    final filmography =
        _department == null ? null : person.filmography(_department!);

    return _Frame(
      child: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(person: person),
              const SizedBox(height: AppSpace.lg),
              _FollowRow(person: person),
              _HistoryCard(personId: person.id),
              if (person.biography != null) ...[
                const SizedBox(height: AppSpace.xl),
                _Biography(text: person.biography!),
              ],
              if (knownFor.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                const _SectionTitle('Known for'),
                const SizedBox(height: AppSpace.md),
                _KnownForRail(credits: knownFor),
              ],
              if (departments.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                const _SectionTitle('Filmography'),
                const SizedBox(height: AppSpace.md),
                if (departments.length > 1) ...[
                  GlassSegmentedControl(
                    labels:
                        departments.map(PersonPage.departmentLabel).toList(),
                    index: departments.indexOf(_department!),
                    onChanged: (i) =>
                        setState(() => _department = departments[i]),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
              ],
            ],
          ),
        ),
      ),
      slivers: [
        if (filmography != null) ..._filmographySlivers(filmography),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  /// Lazily built: a prolific actor has a few hundred rows.
  List<Widget> _filmographySlivers(Filmography f) {
    final groups = [
      if (f.upcoming.isNotEmpty) (label: 'Upcoming', credits: f.upcoming),
      for (final y in f.years) (label: '${y.year}', credits: y.credits),
    ];
    return [
      for (final g in groups) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(20, AppSpace.lg, 20, AppSpace.sm),
            child: GlassSectionLabel(g.label),
          ),
        ),
        SliverList.builder(
          itemCount: g.credits.length,
          itemBuilder: (_, i) => _CreditRow(credit: g.credits[i]),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.person});

  final PersonPage person;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (person.knownForDepartment != null)
        PersonPage.departmentLabel(person.knownForDepartment!),
      if (person.birthday != null)
        person.deathday == null
            ? 'Born ${_date(person.birthday!)} (${_age(person.birthday!, DateTime.now())})'
            : '${_date(person.birthday!)} – ${_date(person.deathday!)}'
                ' (${_age(person.birthday!, person.deathday!)})',
    ];

    return Center(
      child: Column(
        children: [
          PillPortrait(
            imageUrl:
                ApiConstants.getProfileUrl(person.profilePath, size: '/h632'),
            width: 120,
            height: 170,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            person.name,
            style: AppText.title.copyWith(fontSize: 26),
            textAlign: TextAlign.center,
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              facts.join(' · '),
              style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (person.placeOfBirth != null) ...[
            const SizedBox(height: 2),
            Text(
              person.placeOfBirth!,
              style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Follow, how many others do, and the favorites menu (ADR 0001, 4.3).
///
/// Following is a subscription: new work shows up in your notifications.
/// A favorite is the ranked showcase on your profile. Both live here, the
/// favorite one step back behind "…".
class _FollowRow extends ConsumerWidget {
  const _FollowRow({required this.person});

  final PersonPage person;

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, bool following) async {
    HapticFeedback.lightImpact();
    final now = await ref
        .read(personFollowActionsProvider)
        .toggle(person, following: following);
    if (!context.mounted) return;
    showGlassToast(
      context,
      now == null
          ? "Couldn't update that."
          : now
              ? "Following ${person.name}. You'll hear about new work."
              : 'Unfollowed ${person.name}',
      destructive: now == null,
      icon: now == true ? CupertinoIcons.bell_fill : null,
    );
  }

  void _menu(BuildContext context, WidgetRef ref) {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    final isActor = profile.favoriteActorIds.contains(person.id);
    final isDirector = profile.favoriteDirectorIds.contains(person.id);
    final favorites = ref.read(favoritesControllerProvider.notifier);

    Future<void> run(Future<Object?> Function() action, String done) async {
      final result = await action();
      if (!context.mounted) return;
      final failed = result == false;
      showGlassToast(
        context,
        failed ? 'Your favorites are full. Remove one first.' : done,
        destructive: failed,
      );
    }

    showGlassPanel<void>(
      context,
      builder: (panelContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpace.sm),
          GlassMenuRow(
            icon: isActor ? CupertinoIcons.star_slash : CupertinoIcons.star,
            title: isActor
                ? 'Remove from favorite actors'
                : 'Add to favorite actors',
            onTap: () {
              Navigator.of(panelContext).pop();
              run(
                () => isActor
                    ? favorites.removeFavoriteActor(person.id).then((_) => true)
                    : favorites.addFavoriteActor(person.id),
                isActor
                    ? 'Removed from favorite actors'
                    : 'Added to favorite actors',
              );
            },
          ),
          const GlassMenuDivider(),
          GlassMenuRow(
            icon: isDirector ? CupertinoIcons.star_slash : CupertinoIcons.star,
            title: isDirector
                ? 'Remove from favorite directors'
                : 'Add to favorite directors',
            onTap: () {
              Navigator.of(panelContext).pop();
              run(
                () => isDirector
                    ? favorites
                        .removeFavoriteDirector(person.id)
                        .then((_) => true)
                    : favorites.addFavoriteDirector(person.id),
                isDirector
                    ? 'Removed from favorite directors'
                    : 'Added to favorite directors',
              );
            },
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(myFollowedPersonIdsProvider);
    final following = followed.valueOrNull?.contains(person.id) ?? false;
    final others =
        ref.watch(personFollowerCountProvider(person.id)).valueOrNull;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassPillButton(
              label: following ? 'Following' : 'Follow',
              icon: following ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
              prominent: !following,
              compact: true,
              onTap: followed.hasValue
                  ? () => _toggle(context, ref, following)
                  : null,
            ),
            const SizedBox(width: AppSpace.sm),
            GlassPillButton(
              label: 'More',
              icon: CupertinoIcons.ellipsis,
              compact: true,
              onTap: () => _menu(context, ref),
            ),
          ],
        ),
        if (others != null && others > 0) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            others == 1
                ? '1 person on 35mm follows them'
                : '$others people on 35mm follow them',
            style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
          ),
        ],
      ],
    );
  }
}

/// "You've logged 7 of their titles · you average ★3.8". Hidden until
/// there's something to say.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(personHistoryProvider(personId)).valueOrNull;
    if (history == null || history.logged == 0) return const SizedBox.shrink();

    final what = history.logged == 1 ? 'title' : 'titles';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        decoration: glassWellDecoration(),
        child: Row(
          children: [
            const Icon(CupertinoIcons.film,
                size: 18, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                "You've logged ${history.logged} of their $what",
                style: AppText.body.copyWith(color: AppColors.ink),
              ),
            ),
            if (history.averageRating != null) ...[
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 3),
              Text(
                history.averageRating!.toStringAsFixed(1),
                style: AppText.label.copyWith(color: AppColors.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Biography extends StatefulWidget {
  const _Biography({required this.text});

  final String text;

  @override
  State<_Biography> createState() => _BiographyState();
}

class _BiographyState extends State<_Biography> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = AppText.body
        .copyWith(color: AppColors.inkSecondary, fontSize: 14, height: 1.5);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: 4,
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  widget.text,
                  style: style,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
              ),
              if (overflows) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  _expanded ? 'Less' : 'More',
                  style: AppText.label.copyWith(color: AppColors.ink),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _KnownForRail extends StatelessWidget {
  const _KnownForRail({required this.credits});

  final List<PersonCredit> credits;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150 + AppSpace.sm + 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: credits.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (_, i) {
          final c = credits[i];
          return GlassPressable(
            onTap: () => _openCredit(context, c),
            child: SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Poster(path: c.posterPath, width: 100, height: 150),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    c.title,
                    style: AppText.footnote.copyWith(color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.roleLabel != null)
                    Text(
                      c.roleLabel!,
                      style: AppText.footnote
                          .copyWith(color: AppColors.inkTertiary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final PersonCredit credit;

  @override
  Widget build(BuildContext context) {
    final c = credit;
    final detail = [
      if (c.roleLabel != null) c.roleLabel!,
      if (c.isTv && c.episodeCount != null)
        '${c.episodeCount} episode${c.episodeCount == 1 ? '' : 's'}',
    ].join(' · ');

    return GlassPressable(
      onTap: () => _openCredit(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            _Poster(path: c.posterPath, width: 40, height: 60, radius: 6),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.title,
                          style: AppText.body.copyWith(color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.isTv) ...[
                        const SizedBox(width: AppSpace.xs),
                        const Icon(CupertinoIcons.tv,
                            size: 13, color: AppColors.inkTertiary),
                      ],
                    ],
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: AppText.footnote
                          .copyWith(color: AppColors.inkSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.inkQuaternary),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.path,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final String? path;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getPosterUrl(path,
        size: width > 60 ? ApiConstants.posterSizeSmall : '/w92');
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.film,
          size: width * 0.35, color: AppColors.inkQuaternary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

void _openCredit(BuildContext context, PersonCredit c) =>
    context.push('/film/${c.filmId}/${c.mediaType}');

String _date(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

int _age(DateTime born, DateTime at) {
  var years = at.year - born.year;
  if (at.month < born.month || (at.month == born.month && at.day < born.day)) {
    years--;
  }
  return years;
}
