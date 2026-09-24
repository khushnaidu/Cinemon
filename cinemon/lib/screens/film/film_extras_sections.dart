import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/film_extras.dart';
import '../../models/film_model.dart';
import '../../providers/movie/movie_provider.dart';
import '../widgets/glass_panel.dart';

typedef FilmKey = ({int id, MediaType mediaType});

/// Extras load with the page's details (one request), so by the time the
/// page is on screen these are ready. Until then, and on any failure, each
/// section takes no space rather than showing a spinner of its own.
FilmExtras? _extras(WidgetRef ref, FilmKey key) =>
    ref.watch(filmExtrasProvider(key)).valueOrNull;

// ─────────────────────────────────────────────────────────────
// Where to watch
// ─────────────────────────────────────────────────────────────

/// "In theaters" and the services it's on, under the title block. Tapping
/// opens every option, grouped, with the JustWatch credit.
class WhereToWatchRow extends ConsumerWidget {
  const WhereToWatchRow({super.key, required this.filmKey});

  final FilmKey filmKey;

  static const _maxLogos = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = _extras(ref, filmKey);
    if (extras == null) return const SizedBox.shrink();

    final region = ref.watch(regionProvider);
    final theatrical = extras.theatrical;
    final watch = extras.watch;
    final included = watch?.included ?? const <WatchProvider>[];
    final paid = watch?.paid ?? const <WatchProvider>[];
    // Services you already pay for lead; rent/buy only fills in when there
    // are none, and says so.
    final logos = (included.isNotEmpty ? included : paid).take(_maxLogos);

    final children = <Widget>[
      if (theatrical.phase == TheatricalPhase.inTheaters)
        const GlassTag('IN THEATERS'),
      if (theatrical.phase == TheatricalPhase.comingSoon &&
          theatrical.date != null)
        GlassTag('IN THEATERS ${_shortDate(theatrical.date!)}'),
      for (final p in logos) _ProviderLogo(provider: p),
    ];

    final String? note;
    if (children.isEmpty) {
      note = 'Not streaming in ${_regionName(region)} right now';
    } else if (included.isEmpty && paid.isNotEmpty) {
      note = 'Rent or buy';
    } else {
      note = null;
    }

    final hasDetail = watch != null && !watch.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl),
      child: GlassPressable(
        onTap: hasDetail
            ? () => _showWatchPanel(context, watch, region: region)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassSectionLabel(
              'Where to watch',
              trailing: hasDetail
                  ? const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: AppColors.inkTertiary)
                  : null,
            ),
            const SizedBox(height: AppSpace.sm),
            if (children.isNotEmpty)
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...children,
                  if (note != null)
                    Text(note,
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkTertiary)),
                ],
              )
            else
              Text(note!,
                  style:
                      AppText.footnote.copyWith(color: AppColors.inkTertiary)),
          ],
        ),
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider, this.size = 30});

  final WatchProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getProfileUrl(provider.logoPath, size: '/w92');
    return Tooltip(
      message: provider.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: url.isEmpty
            ? Container(
                width: size,
                height: size,
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: Text(
                  provider.name.characters.first,
                  style: AppText.label.copyWith(color: AppColors.ink),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    width: size,
                    height: size,
                    color: AppColors.surfaceElevated),
                errorWidget: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    color: AppColors.surfaceElevated),
              ),
      ),
    );
  }
}

void _showWatchPanel(
  BuildContext context,
  WatchProviders watch, {
  required String region,
}) {
  final groups = [
    ('Stream', watch.stream),
    ('Free', watch.free),
    ('Rent', watch.rent),
    ('Buy', watch.buy),
  ].where((g) => g.$2.isNotEmpty);

  showGlassPanel<void>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanelHeader(
          title: 'Where to watch',
          subtitle: 'In ${_regionName(region)}',
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(panelContext).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, providers) in groups) ...[
                  GlassSectionLabel(label),
                  const SizedBox(height: AppSpace.sm),
                  for (final p in providers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: Row(
                        children: [
                          _ProviderLogo(provider: p, size: 36),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(p.name,
                                style: AppText.body
                                    .copyWith(color: AppColors.ink)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpace.md),
                ],
              ],
            ),
          ),
        ),
        if (watch.link != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: GlassPillButton(
              label: 'See prices and links',
              icon: CupertinoIcons.arrow_up_right,
              expand: true,
              onTap: () => launchUrl(
                Uri.parse(watch.link!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
          // Required by the data licence wherever provider data appears.
          child: Text(
            'Streaming data from JustWatch',
            style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Trailer and videos
// ─────────────────────────────────────────────────────────────

/// The best trailer as a 16:9 card, then any other videos in a rail.
class FilmVideosSection extends ConsumerWidget {
  const FilmVideosSection({super.key, required this.filmKey});

  final FilmKey filmKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = _extras(ref, filmKey);
    final trailer = extras?.trailer;
    if (extras == null || trailer == null) return const SizedBox.shrink();

    final others = extras.videos.where((v) => v.key != trailer.key).toList()
      ..sort((a, b) => (b.publishedAt ?? DateTime(0))
          .compareTo(a.publishedAt ?? DateTime(0)));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Trailer'),
          const SizedBox(height: AppSpace.md),
          _VideoThumb(video: trailer, width: double.infinity, large: true),
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xl),
            const _SectionTitle('Videos'),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 90 + AppSpace.sm + 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: others.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
                itemBuilder: (_, i) => SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VideoThumb(video: others[i], width: 160),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        others[i].name,
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({
    required this.video,
    required this.width,
    this.large = false,
  });

  final FilmVideo video;
  final double width;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(large ? 16 : 10);
    final glyph = large ? 56.0 : 34.0;
    return GlassPressable(
      onTap: () => showTrailerPlayer(context, video),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: AppColors.surface),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: AppColors.surface),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: glyph,
                    height: glyph,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 0.8),
                    ),
                    child: Icon(CupertinoIcons.play_fill,
                        color: Colors.white, size: glyph * 0.42),
                  ),
                ),
                if (large)
                  Positioned(
                    left: AppSpace.md,
                    right: AppSpace.md,
                    bottom: AppSpace.sm + 2,
                    child: Text(
                      video.name,
                      style: AppText.label.copyWith(color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A trailer in a full-screen black room. One player at a time: the web view
/// is created here and torn down when the room closes (ADR 0001, D5).
Future<void> showTrailerPlayer(BuildContext context, FilmVideo video) {
  HapticFeedback.lightImpact();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _TrailerRoom(video: video),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _TrailerRoom extends StatefulWidget {
  const _TrailerRoom({required this.video});

  final FilmVideo video;

  @override
  State<_TrailerRoom> createState() => _TrailerRoomState();
}

class _TrailerRoomState extends State<_TrailerRoom> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
    videoId: widget.video.key,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showFullscreenButton: true,
      playsInline: true,
      strictRelatedVideos: true,
    ),
  );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Swipe down anywhere off the player to leave.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300)
                    Navigator.of(context).pop();
                },
              ),
            ),
            Center(
              child: YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
                backgroundColor: Colors.black,
              ),
            ),
            Positioned(
              top: AppSpace.sm,
              left: AppSpace.lg,
              right: AppSpace.lg,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.video.name,
                      style: AppText.label.copyWith(color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  GlassPillButton(
                    label: 'Done',
                    compact: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cast
// ─────────────────────────────────────────────────────────────

/// Directors or creators, then the cast, as a rail of faces that each open
/// a person page.
class CastSection extends ConsumerWidget {
  const CastSection({super.key, required this.filmKey});

  final FilmKey filmKey;

  static const _maxCast = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = _extras(ref, filmKey);
    if (extras == null) return const SizedBox.shrink();
    final directors = extras.directors;
    // Directors (or creators) lead the rail, then the cast in billing order.
    final people = [
      for (final d in directors)
        CastMember(
            id: d.id,
            name: d.name,
            character: d.job,
            profilePath: d.profilePath),
      ...extras.cast.take(_maxCast),
    ];
    if (people.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Cast & crew'),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 64 + AppSpace.sm + 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
              itemBuilder: (_, i) => _CastTile(member: people[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastTile extends StatelessWidget {
  const _CastTile({required this.member});

  final CastMember member;

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.getProfileUrl(member.profilePath);
    return GlassPressable(
      onTap: () => context.push('/person/${member.id}'),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: url.isEmpty
                    ? const ColoredBox(
                        color: AppColors.surfaceElevated,
                        child: Icon(CupertinoIcons.person_fill,
                            color: AppColors.inkTertiary),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: AppColors.surfaceElevated),
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: AppColors.surfaceElevated),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              member.name,
              style: AppText.footnote.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (member.character != null)
              Text(
                member.character!,
                style: AppText.footnote
                    .copyWith(color: AppColors.inkTertiary, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────

/// Matches the page's existing "Overview" heading.
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

String _shortDate(DateTime d) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

/// "the US", "the UK", else the code. Enough for an empty-state sentence.
String _regionName(String code) => switch (code) {
      'US' => 'the US',
      'GB' => 'the UK',
      'CA' => 'Canada',
      'AU' => 'Australia',
      'IN' => 'India',
      'IE' => 'Ireland',
      'NZ' => 'New Zealand',
      'DE' => 'Germany',
      'FR' => 'France',
      _ => code,
    };
