// Renders every share card to PNG for a visual check, using local artwork
// and the Mac's system fonts. Run with:
//   SHARE_PREVIEW_ART=<dir of jpgs> SHARE_PREVIEW_OUT=<dir> flutter test test/share_cards_preview_test.dart
// Skipped when the variables aren't set, so it never runs in a normal test pass.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cinemon/core/utils/poster_palette.dart';
import 'package:cinemon/models/explore_post_model.dart';
import 'package:cinemon/models/film_model.dart';
import 'package:cinemon/models/list_model.dart';
import 'package:cinemon/models/user_model.dart';
import 'package:cinemon/share/month_stats.dart';
import 'package:cinemon/providers/movie/movie_provider.dart';
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
    const f = 'assets/fonts/share';
    await _font('InstrumentSerif',
        ['$f/InstrumentSerif-Regular.ttf', '$f/InstrumentSerif-Italic.ttf']);
    await _font('IBMPlexMono',
        ['$f/IBMPlexMono-Medium.ttf', '$f/IBMPlexMono-SemiBold.ttf']);
    await _font('BigShoulders', [
      '$f/BigShouldersDisplay-Bold.ttf',
      '$f/BigShouldersDisplay-Black.ttf'
    ]);
    await _font('ReenieBeanie', ['$f/ReenieBeanie.ttf']);
    await _font('Siberian',
        ['assets/siberian-font/SiberianPersonalUseRegular-d9Log.ttf']);
    await _font('Isometric3D', ['assets/3DIsometricBold-Yqy68.ttf']);
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
  final critique = CritiqueShare(ExplorePost(
    id: 'c',
    userId: 'u',
    username: 'lilkhush',
    kind: ExploreKind.critique,
    headline: "Aftersun is a memory you didn't know you were carrying",
    body:
        'Charlotte Wells builds a film out of the gaps in a camcorder tape, and trusts you to fill them. '
        'The saddest shot in the film is a Polaroid developing, and nothing happens in it at all. '
        'Everything Calum cannot say to his daughter is in the way Paul Mescal holds his shoulders.',
    subject: const ExploreSubject(
      filmId: 965150,
      mediaType: 'movie',
      title: 'Aftersun',
      posterPath: '/p_aftersun.jpg',
      backdropPath: '/b_aftersun.jpg',
      year: '2022',
    ),
    createdAt: DateTime(2026, 9, 21),
  ));
  critique.quote.value = 1;
  FilmModel film(int id, String title, String poster, String backdrop) =>
      FilmModel.fromJson({
        'id': id,
        'title': title,
        'poster_path': poster,
        'backdrop_path': backdrop,
        'media_type': 'movie',
      });
  final top3 = Top3Share(
    username: 'lilkhush',
    userPhotoUrl: 'https://x/me.jpg',
    isTv: false,
    films: [
      film(496243, 'Parasite', '/p_parasite.jpg', '/b_parasite.jpg'),
      film(129, 'Spirited Away', '/p_spirited.jpg', '/b_spirited.jpg'),
      film(843, 'In the Mood for Love', '/p_mood.jpg', '/b_mood.jpg'),
    ],
  );
  final me = UserModel(
    uid: 'u',
    username: 'lilkhush',
    photoUrl: 'https://x/me.jpg',
    bio: 'films, feelings, and far too many opinions',
    reviewCount: 48,
    followerCount: 1204,
    createdAt: DateTime(2026, 1, 1),
  );
  final profile = ProfileShare(
    user: me,
    top3: top3.films,
    logged: 214,
    month: DateTime(2026, 9),
  );
  final month = MonthInFilm(
    month: DateTime(2026, 9),
    films: 23,
    episodes: 6,
    minutes: 2490,
    posterPaths: const [
      '/p_pastlives.jpg',
      '/p_dune2.jpg',
      '/p_aftersun.jpg',
      '/p_anora.jpg',
      '/p_mood.jpg',
      '/p_chungking.jpg',
      '/p_lalaland.jpg',
      '/p_lost.jpg',
      '/p_sunrise.jpg',
      '/p_interstellar.jpg',
      '/p_women.jpg',
      '/p_bear.jpg',
    ],
    topGenre: 'Drama',
    topGenreShare: 0.38,
    mostWatched: 'Wong Kar-wai',
    mostWatchedCount: 3,
    highestRated: 'Past Lives',
    highestRating: 4.5,
    hottestTakeAgree: 71,
  );
  ListItem item(int id, String title, String poster, String year) => ListItem(
      listId: 'l',
      filmId: id,
      mediaType: 'movie',
      title: title,
      posterPath: poster,
      year: year);
  final playlist = PlaylistShare(
    list: const FilmList(
      id: 'l',
      userId: 'u',
      kind: 'playlist',
      title: 'Rainy Sunday comfort watches',
      description: "For when it's pouring out and you need something warm.",
    ),
    items: [
      item(194, 'Amélie', '/p_amelie.jpg', '2001'),
      item(76, 'Before Sunrise', '/p_sunrise.jpg', '1995'),
      item(346648, 'Paddington 2', '/p_paddington.jpg', '2017'),
      item(153, 'Lost in Translation', '/p_lost.jpg', '2003'),
      item(331482, 'Little Women', '/p_women.jpg', '2019'),
      item(11104, 'Chungking Express', '/p_chungking.jpg', '1994'),
    ],
    ownerName: 'lilkhush',
    ownerPhotoUrl: 'https://x/me.jpg',
  );
  final variants = {'bare': TakeShare(bare), 'long': TakeShare(long)};
  final subjects = <ShareSubject>[
    TakeShare(take),
    review,
    episode,
    critique,
    top3,
    profile,
    playlist,
  ];
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
          final urls = [
            ...subject.imageUrls,
            if (subject is ProfileShare)
              for (final p in month.posterPaths) 'https://x/w185$p',
            if (subject is ReviewShare)
              for (final n in ['s2', 's3', 's1'])
                'https://x/w780/${n}_pastlives.jpg',
          ];
          for (final url in urls) {
            await precacheImage(StoryImage.debugProvider!(url), ctx);
          }
          for (final a in [
            'mark.png',
            'grain.png',
            'sparkle.png',
            'top3_orb.png',
            'top3_rank1.png',
            'top3_rank2.png',
            'top3_rank3.png',
          ]) {
            await precacheImage(AssetImage('assets/share/$a'), ctx);
          }
        });
        await tester.pumpWidget(ProviderScope(
          overrides: [
            monthInFilmProvider.overrideWith((ref, _) async => month),
            filmStillsProvider.overrideWith((ref, _) async => [
                  '/s2_pastlives.jpg',
                  '/s3_pastlives.jpg',
                  '/s1_pastlives.jpg'
                ]),
          ],
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
