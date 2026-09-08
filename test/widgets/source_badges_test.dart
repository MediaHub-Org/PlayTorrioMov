// test/widgets/source_badges_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/widgets/common/source_badges.dart';

StreamSource http({String? title}) => StreamSource(
  name: 'Server 1',
  title: title,
  url: 'https://example/a.mp4',
  addonName: 'Test',
);

StreamSource torrent({String? title, String? infoHash}) => StreamSource(
  name: 'Torrent 1',
  title: title,
  infoHash: infoHash ?? 'abc123',
  addonName: 'Test',
);

Widget wrap(List<Widget> badges) => MaterialApp(
  home: Scaffold(body: Row(children: badges)),
);

void main() {
  group('seedHealthColor', () {
    test('grades a torrent by how likely it is to start', () {
      // The boundaries matter more than the exact colours: a source with
      // single-digit seeds regularly never buffers at all.
      expect(seedHealthColor(0), seedHealthColor(9));
      expect(seedHealthColor(10), seedHealthColor(49));
      expect(seedHealthColor(50), seedHealthColor(5000));

      expect(seedHealthColor(9), isNot(seedHealthColor(10)));
      expect(seedHealthColor(49), isNot(seedHealthColor(50)));
    });
  });

  group('sourceDeliveryBadges', () {
    testWidgets('an HTTP source gets one HTTP badge and no seed count', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(sourceDeliveryBadges(http())));

      expect(find.text('HTTP'), findsOneWidget);
      expect(find.text('P2P'), findsNothing);
    });

    testWidgets('a torrent gets P2P plus its parsed seed count', (
      tester,
    ) async {
      // The count is parsed out of the source title, which is where every
      // scraper puts it -- it was being parsed and then never displayed.
      await tester.pumpWidget(
        wrap(sourceDeliveryBadges(torrent(title: 'Movie 1080p 👤 137 seeders'))),
      );

      expect(find.text('P2P'), findsOneWidget);
      expect(find.text('137'), findsOneWidget);
    });

    testWidgets('a torrent with no parseable count shows P2P alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(sourceDeliveryBadges(torrent(title: 'Movie 1080p x265'))),
      );

      expect(find.text('P2P'), findsOneWidget);
      expect(find.byType(SourceBadge), findsOneWidget);
    });

    testWidgets('a magnet URL with no infoHash still reads as P2P', (
      tester,
    ) async {
      final source = StreamSource(
        name: 'Magnet',
        url: 'magnet:?xt=urn:btih:deadbeef',
        addonName: 'Test',
      );
      await tester.pumpWidget(wrap(sourceDeliveryBadges(source)));

      expect(find.text('P2P'), findsOneWidget);
    });
  });
}
