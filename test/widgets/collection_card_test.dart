// test/widgets/collection_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/collection/collection_card.dart';

Widget wrap(Widget child, {double width = 160}) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
);

CollectionCard card({
  List<String> posters = const [],
  bool alwaysUseIcon = false,
  String title = 'Weekend',
  VoidCallback? onTap,
}) => CollectionCard(
  title: title,
  subtitle: '3 titles',
  posters: posters,
  icon: Icons.playlist_play_rounded,
  accent: const Color(0xFF7C4DFF),
  alwaysUseIcon: alwaysUseIcon,
  onTap: onTap ?? () {},
);

void main() {
  // The artwork choice is asserted on the widget rather than by pumping it:
  // every branch but the icon draws a CachedNetworkImage, which would put a
  // real fetch and a plugin-backed cache in the middle of a unit test.
  group('which artwork a card gets', () {
    test('nothing to show falls back to the icon', () {
      expect(card().artKind, CollectionArt.icon);
      expect(card().visiblePosters, isEmpty);
    });

    test('one to three posters show the first', () {
      // A 2x2 with holes in it reads as broken rather than sparse.
      for (final count in [1, 2, 3]) {
        final c = card(posters: List.generate(count, (i) => 'p$i'));
        expect(c.artKind, CollectionArt.single, reason: '$count posters');
        expect(c.visiblePosters, ['p0']);
      }
    });

    test('four or more tile into a 2x2, and never more than four', () {
      expect(
        card(posters: const ['a', 'b', 'c', 'd']).artKind,
        CollectionArt.mosaic,
      );
      expect(
        card(posters: const ['a', 'b', 'c', 'd', 'e', 'f']).visiblePosters,
        ['a', 'b', 'c', 'd'],
      );
    });

    test('a built-in shelf keeps its icon however full it is', () {
      // Liked has to stay recognisably Liked as its contents change.
      final c = card(posters: const ['a', 'b', 'c', 'd'], alwaysUseIcon: true);

      expect(c.artKind, CollectionArt.icon);
      expect(c.visiblePosters, isEmpty);
    });
  });

  group('CollectionCard', () {
    testWidgets('the artwork is square', (tester) async {
      // The whole point of the shape: a 2:3 tile is a title, a square is a
      // container of titles. Spotify and YouTube Music draw the same line.
      await tester.pumpWidget(wrap(card()));

      final art = tester.getRect(find.byType(AspectRatio));
      expect(art.width, art.height);
    });

    testWidgets('draws the icon when there is nothing else', (tester) async {
      await tester.pumpWidget(wrap(card()));

      expect(find.byIcon(Icons.playlist_play_rounded), findsOneWidget);
      expect(find.text('Weekend'), findsOneWidget);
      expect(find.text('3 titles'), findsOneWidget);
    });

    testWidgets('a long name ellipsizes instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(card(title: 'A' * 120), width: 120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping opens it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(card(onTap: () => taps++)));

      await tester.tap(find.byType(CollectionCard));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
