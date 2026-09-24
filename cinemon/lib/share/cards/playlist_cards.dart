import 'package:flutter/material.dart';

import '../../models/list_model.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

TextStyle _helv(double size, FontWeight w,
        {double height = 1.2, double? spacing, double alpha = 1}) =>
    TextStyle(
      fontFamily: kHelvetica,
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: spacing,
      color: Colors.white.withValues(alpha: alpha),
    );

/// L1: a playlist the way Spotify shares one. The app's 2×2 poster cover,
/// the title, who made it, the description, then the first three films.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist});

  final PlaylistShare playlist;

  @override
  Widget build(BuildContext context) {
    final list = playlist.list;
    final items = playlist.items;
    final count = items.length;
    final description = (list.description ?? '').trim();
    final first = items.isEmpty ? '' : playlist.posterOf(items.first);

    return StoryCanvas(
      children: [
        if (first.isNotEmpty)
          Opacity(opacity: 0.8, child: StoryBlur(first, dim: 0)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0, 0.45, 0.75],
            ),
          ),
        ),
        const StoryGrain(),
        Positioned(
          left: 26.u,
          top: 20.u,
          width: 48.u,
          height: 48.u,
          child: _Cover(playlist: playlist),
        ),
        Positioned(
          left: 8.u,
          right: 8.u,
          top: 73.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                list.displayTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    _helv(7.u, FontWeight.w700, height: 1.05, spacing: -0.25.u),
              ),
              SizedBox(height: 2.2.u),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 5.4.u,
                    height: 5.4.u,
                    child: ClipOval(
                      child: (playlist.ownerPhotoUrl ?? '').isEmpty
                          ? const ColoredBox(color: Colors.white24)
                          : StoryImage(playlist.ownerPhotoUrl!),
                    ),
                  ),
                  SizedBox(width: 1.8.u),
                  Text(
                    '@${playlist.ownerName}  ·  $count ${count == 1 ? 'title' : 'titles'}',
                    style: _helv(3.2.u, FontWeight.w500, alpha: 0.72),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                SizedBox(height: 2.4.u),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      _helv(3.5.u, FontWeight.w400, height: 1.35, alpha: 0.62),
                ),
              ],
              SizedBox(height: 5.u),
              for (final item in items.take(3))
                Padding(
                  padding: EdgeInsets.only(bottom: 2.2.u),
                  child: _Row(item: item, playlist: playlist),
                ),
            ],
          ),
        ),
        Positioned(
          left: 8.u,
          right: 8.u,
          bottom: 17.u,
          child: Row(
            children: [
              if (count > 3)
                Text('+ ${count - 3} more',
                    style: _helv(3.2.u, FontWeight.w500, alpha: 0.6)),
              const Spacer(),
              const StoryBrand(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.playlist});

  final ListItem item;
  final PlaylistShare playlist;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if ((item.year ?? '').isNotEmpty) item.year,
      item.isTv ? 'Series' : 'Film',
    ].join(' · ');
    return Row(
      children: [
        StoryPoster(
          url: playlist.posterOf(item),
          width: 7.u,
          radius: 0.9.u,
          shadow: false,
        ),
        SizedBox(width: 3.2.u),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _helv(3.8.u, FontWeight.w600,
                      height: 1.15, spacing: -0.04.u)),
              SizedBox(height: 0.8.u),
              Text(meta, style: _helv(3.u, FontWeight.w400, alpha: 0.58)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cover the app draws for playlists (`playlist_cover.dart`): a 2×2
/// grid from four posters, or the first poster over a blur of itself.
class _Cover extends StatelessWidget {
  const _Cover({required this.playlist});

  final PlaylistShare playlist;

  @override
  Widget build(BuildContext context) {
    final urls = [
      for (final i in playlist.items)
        if ((i.posterPath ?? '').isNotEmpty) playlist.posterOf(i),
    ];
    final r = BorderRadius.circular(5.u);
    final Widget content;
    if (urls.length >= 4) {
      content = GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final u in urls.take(4)) StoryImage(u)],
      );
    } else if (urls.isNotEmpty) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          StoryBlur(urls.first, sigma: 14, dim: 0.25),
          Center(child: StoryPoster(url: urls.first, width: 24.u)),
        ],
      );
    } else {
      content = const ColoredBox(color: Colors.white12);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 12.u,
            offset: Offset(0, 4.u),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.14), width: 0.25.u),
      ),
      child: ClipRRect(borderRadius: r, child: content),
    );
  }
}
