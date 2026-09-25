import 'package:cinemon/models/explore_post_model.dart';
import 'package:cinemon/providers/user/verified_provider.dart';
import 'package:cinemon/core/utils/poster_palette.dart';
import 'package:cinemon/screens/explore/critique_colors.dart';
import 'package:cinemon/screens/explore/critique_feed_card.dart';
import 'package:cinemon/screens/explore/critique_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _para(String seed, int words) =>
    List.generate(words, (i) => i == 0 ? seed : 'word$i').join(' ') + '.';

void main() {
  group('critiqueLayout', () {
    test('splits on returns, one or several, and drops blank lines', () {
      final l = critiqueLayout('One.\nTwo.\n\n\n  Three.  \n');
      expect(l.paragraphs, ['One.', 'Two.', 'Three.']);
      expect(l.pullQuote, isNull);
    });

    test('short pieces get no pull quote', () {
      final body = [for (var i = 0; i < 5; i++) _para('P$i', 20)].join('\n');
      expect(critiqueLayout(body).pullQuote, isNull);
    });

    test('long pieces get a quote from past the opening, mid-piece', () {
      final opening =
          'The opening sentence is long enough to be a quote itself.';
      final paragraphs = [
        opening,
        for (var i = 0; i < 5; i++)
          'Paragraph $i has a sentence that could stand on its own as a quote. '
              '${_para('Filler', 60)}',
      ];
      final l = critiqueLayout(paragraphs.join('\n\n'));
      expect(l.paragraphs, hasLength(6));
      expect(l.pullQuote, isNotNull);
      expect(l.pullQuote, isNot(opening));
      expect(l.pullAfter, 2);
    });
  });

  testWidgets('drop cap sets the first letter apart and keeps every word',
      (tester) async {
    final text = 'Nothing in this film is accidental. ${_para('Every', 80)}';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 340,
            child: DropCapParagraph(text: text, style: critiqueBodyStyle()),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('N'), findsOneWidget);
    // Set in two parts: three lines beside the letter, the rest under it.
    expect(find.byType(RichText), findsNWidgets(3));
    final pieces = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .where((t) => t != 'N')
        .join(' ');
    expect(pieces.replaceAll(RegExp(r'\s+'), ' '),
        text.substring(1).replaceAll(RegExp(r'\s+'), ' '));
  });

  testWidgets('a paragraph opening with a quote mark gets no drop cap',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropCapParagraph(
            text: '“Quoted,” she said.', style: critiqueBodyStyle()),
      ),
    ));
    expect(find.text('“'), findsNothing);
    expect(find.byType(LayoutBuilder), findsNothing);
  });

  testWidgets('the reader lays out a spoiler-free preview without errors',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final body = [
      for (var i = 0; i < 6; i++)
        'Paragraph $i makes a point long enough to be quoted on its own. '
            '${_para('More', 70)}',
    ].join('\n\n');
    await tester.pumpWidget(ProviderScope(
      overrides: [verifiedUsersProvider.overrideWith((_) async => <String>{})],
      child: MaterialApp(
        home: CritiqueReader(
          preview: true,
          post: ExplorePost(
            id: 'preview',
            userId: 'u',
            username: 'khush',
            kind: ExploreKind.critique,
            headline: 'A long, patient film',
            body: body,
            createdAt: DateTime(2026, 9, 25),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('CRITIQUE'), findsOneWidget);
  });

  group('CritiqueColors', () {
    test('a post without a film always gets the same house palette', () {
      expect(CritiqueColors.basicFor('abc'), CritiqueColors.basicFor('abc'));
      final seen = {
        for (var i = 0; i < 60; i++) CritiqueColors.basicFor('post-$i')
      };
      expect(seen.length, greaterThan(3));
    });

    test('black-and-white posters get gold on ink', () {
      expect(CritiqueColors.fromPalette(PosterPalette.neutral),
          CritiqueColors.classic);
    });

    test("a poster's hues become a dark page and light inks", () {
      final c = CritiqueColors.fromPalette(const PosterPalette(
        primary: Color(0xFFFF2E88),
        secondary: Color(0xFF2EE6FF),
      ));
      final ground = HSLColor.fromColor(c.ground);
      final accent = HSLColor.fromColor(c.accent);
      final accent2 = HSLColor.fromColor(c.accent2);
      expect(ground.lightness, lessThan(0.08));
      expect(accent.lightness, greaterThan(0.6));
      expect(
          (accent.hue - HSLColor.fromColor(const Color(0xFFFF2E88)).hue).abs(),
          lessThan(2));
      expect(
          (accent2.hue - HSLColor.fromColor(const Color(0xFF2EE6FF)).hue).abs(),
          lessThan(2));
    });
  });

  testWidgets('the feed card lays out a long headline without overflow',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [verifiedUsersProvider.overrideWith((_) async => <String>{})],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: CritiqueFeedCard(
                onLike: () {},
                onMenu: () {},
                post: ExplorePost(
                  id: 'p1',
                  userId: 'u',
                  username: 'a_rather_long_username_indeed',
                  kind: ExploreKind.critique,
                  headline: 'An unusually long headline that goes on and on '
                      'about the film and never quite stops',
                  body: 'The first sentence sets the scene. Then more.',
                  createdAt: DateTime(2026, 9, 25),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('CRITIQUE'), findsOneWidget);
    expect(find.text('The first sentence sets the scene.'), findsOneWidget);
  });
}
