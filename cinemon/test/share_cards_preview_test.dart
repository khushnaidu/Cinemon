// Renders every share card to PNG for a visual check, using local artwork
// and the Mac's system fonts. Run with:
//   SHARE_PREVIEW_ART=<dir of jpgs> SHARE_PREVIEW_OUT=<dir> flutter test test/share_cards_preview_test.dart
// Skipped when the variables aren't set, so it never runs in a normal test pass.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cinemon/core/utils/poster_palette.dart';
import 'package:cinemon/models/explore_post_model.dart';
import 'package:cinemon/share/share_sheet.dart';
import 'package:cinemon/share/share_subject.dart';
import 'package:cinemon/share/story_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _art = Platform.environment['SHARE_PREVIEW_ART'];
final _out = Platform.environment['SHARE_PREVIEW_OUT'];

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

void main() {
  final skip = _art == null || _out == null;

  setUpAll(() async {
    if (skip) return;
    const sf = '/System/Library/Fonts/SFNS.ttf';
    await _font('CupertinoSystemText', [sf]);
    await _font('CupertinoSystemDisplay', [sf]);
    await _font('.SF Pro Text', [sf]);
    debugPrint('fonts');
    await _font('Helvetica Neue', ['/System/Library/Fonts/HelveticaNeue.ttc']);
    debugPrint('helvetica ok');
    await _font('Roboto', [sf]);
    final home = Platform.environment['HOME'];
    await _font('packages/cupertino_icons/CupertinoIcons', [
      '$home/.pub-cache/hosted/pub.dev/cupertino_icons-1.0.6/assets/CupertinoIcons.ttf'
    ]);
    StoryImage.debugProvider = (url) {
      final name = url.split('/').last;
      return FileImage(File('$_art/$name'));
    };
  });

  const lalaland = ExploreSubject(
    filmId: 313369,
    mediaType: 'movie',
    title: 'La La Land',
    posterPath: '/p_lalaland.jpg',
    year: '2016',
  );
  final take = ExplorePost(
    id: 't',
    userId: 'u',
    username: 'lilkhush',
    userPhotoUrl: 'https://x/me.jpg',
    kind: ExploreKind.take,
    body:
        "La La Land's last eight minutes are the best ending any musical has ever had.",
    subject: lalaland,
    agreeCount: 855,
    disagreeCount: 349,
    createdAt: DateTime(2026, 9, 21),
  );
  const review = ReviewShare(
    username: 'lilkhush',
    userPhotoUrl: 'https://x/me.jpg',
    filmId: 693134,
    mediaType: 'movie',
    title: 'Dune: Part Two',
    year: '2024',
    posterPath: '/p_dune2.jpg',
    rating: 5,
    text:
        'Cinema as an event. The whole IMAX row gasped at the first sandworm ride.',
  );
  const episode = EpisodeShare(
    username: 'lilkhush',
    userPhotoUrl: 'https://x/me.jpg',
    showTitle: 'The Bear',
    posterPath: '/p_bear.jpg',
    stillPath: '/st_fishes.jpg',
    seasonNumber: 2,
    episodeNumber: 6,
    episodeTitle: 'Fishes',
    rating: 5,
    text: 'Seven Christmases of dread in one hour. I needed a walk after.',
  );

  final bare = ExplorePost(
    id: 't2',
    userId: 'u',
    username: 'lilkhush',
    userPhotoUrl: 'https://x/me.jpg',
    kind: ExploreKind.take,
    body: 'Sequels are better.',
    createdAt: DateTime(2026, 9, 21),
  );
  final long = ExplorePost(
    id: 't3',
    userId: 'u',
    username: 'lilkhush',
    kind: ExploreKind.take,
    body:
        'Nolan has never made a film where the women are more than a plot device, and Oppenheimer is the clearest case yet: three hours, two women, zero inner lives. Fight me.',
    subject: lalaland,
    agreeCount: 3,
    createdAt: DateTime(2026, 9, 21),
  );
  final variants = {'bare': TakeShare(bare), 'long': TakeShare(long)};
  final subjects = <ShareSubject>[TakeShare(take), review, episode];
  const palette =
      PosterPalette(primary: Color(0xFF3B3AB0), secondary: Color(0xFFF2C230));

  final named = [
    for (final s in subjects) ('', s),
    for (final e in variants.entries) ('-${e.key}', e.value),
  ];
  for (final (suffix, subject) in named) {
    for (final t in subject.templates) {
      testWidgets('render ${t.code}$suffix', skip: skip, (tester) async {
        tester.view.physicalSize = const Size(kStoryWidth, kStoryHeight);
        tester.view.devicePixelRatio = 1;
        final key = GlobalKey();
        final look = ShareLook(
            palette:
                subject.paletteUrl.isEmpty ? PosterPalette.neutral : palette);
        final card = t.sticker
            ? StickerStory(look: look, sticker: t.build(look))
            : t.build(look);
        // Decode the artwork first, outside the fake clock. An image first
        // requested by a build inside it never finishes loading.
        await tester.pumpWidget(const SizedBox());
        final ctx = tester.element(find.byType(SizedBox));
        await tester.runAsync(() async {
          for (final url in subject.imageUrls) {
            await precacheImage(StoryImage.debugProvider!(url), ctx);
          }
          await precacheImage(const AssetImage('assets/share/mark.png'), ctx);
          await precacheImage(const AssetImage('assets/share/grain.png'), ctx);
        });
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Material(
              color: Colors.black,
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(key: key, child: card),
              ),
            ),
          ),
        ));
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_out/${t.code}$suffix.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
        });
        // Let the film page request (R2's director credit) run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 31));
      });
    }
  }
}
