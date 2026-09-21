// test/widgets/player_subtitle_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

SubtitleVariant variant(String title, String url, {String language = 'English'}) =>
    SubtitleVariant(
      providerName: 'test',
      language: language,
      title: title,
      downloadUrl: url,
      format: 'srt',
    );

/// A filter chip by its label -- the row badges say "CC / SDH" and "Forced" too.
Finder chip(String label) => find.descendant(
      of: find.byType(PlayerToggleChip),
      matching: find.text(label),
    );

Widget menu({
  List<PlayerEmbeddedSubtitle> embedded = const [],
  List<SubtitleVariant> variants = const [],
  ValueChanged<PlayerEmbeddedSubtitle>? onEmbedded,
  SubtitleVariant? selected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: PlayerSubtitleMenu(
          groups: variants.isEmpty
              ? const []
              : [SubtitleLanguageGroup(language: 'English', variants: variants)],
          embeddedSubtitles: embedded,
          selectedVariant: selected,
          isSubtitleEnabled: selected != null,
          movieTitle: 'A Movie',
          delaySec: 0,
          onSelectVariant: (_) {},
          onSelectEmbedded: onEmbedded ?? (_) {},
          onToggleOff: () {},
          onOpenSyncBar: () {},
          onAutoPick: () {},
          onClose: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('the "In this video" strip', () {
    testWidgets('lists the embedded tracks up top, the file default first',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(menu(
        variants: [variant('Movie.2020', 'u1')],
        embedded: const [
          PlayerEmbeddedSubtitle(index: 1, title: 'English', language: 'English'),
          PlayerEmbeddedSubtitle(
            index: 2,
            title: 'Spanish',
            language: 'Spanish',
            isDefault: true,
          ),
        ],
      ));
      await tester.pump();

      expect(find.text('IN THIS VIDEO'), findsOneWidget);
      // The default track's chip comes before the other one's.
      final spanish = tester.getTopLeft(find.text('Spanish').first).dx;
      final english = tester.getTopLeft(find.text('English').first).dx;
      expect(spanish, lessThan(english), reason: 'default first');
      expect(find.text('DEFAULT'), findsWidgets);
    });

    testWidgets('tapping a chip selects that embedded track', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      PlayerEmbeddedSubtitle? picked;
      await tester.pumpWidget(menu(
        variants: [variant('Movie.2020', 'u1')],
        embedded: const [
          PlayerEmbeddedSubtitle(index: 7, title: 'Spanish', language: 'Spanish'),
        ],
        onEmbedded: (t) => picked = t,
      ));
      await tester.pump();

      await tester.tap(find.text('Spanish').first);
      await tester.pump();

      expect(picked?.index, 7);
    });

    testWidgets('is absent when the video carries none and none is loaded',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(menu(variants: [variant('Movie.2020', 'u1')]));
      await tester.pump();

      expect(find.text('IN THIS VIDEO'), findsNothing);
    });
  });

  group('the CC and Forced filters', () {
    final variants = [
      variant('Movie.2020.SDH', 'u1'),
      variant('Movie.2020.HI.CC', 'u2'),
      variant('Movie.2020.forced', 'u3'),
      variant('Movie.2020', 'u4'),
    ];

    testWidgets('show how many each would leave', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(menu(variants: variants));
      await tester.pump();

      expect(chip('CC / SDH'), findsOneWidget);
      expect(chip('Forced'), findsOneWidget);
      final counts = tester
          .widgetList<PlayerToggleChip>(find.byType(PlayerToggleChip))
          .map((c) => '${c.label}:${c.count}')
          .toList();
      expect(counts, containsAll(['CC / SDH:2', 'Forced:1']));
    });

    testWidgets('CC narrows the list, and All clears it again', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(menu(variants: variants));
      await tester.pump();
      expect(find.textContaining('Movie.2020'), findsNWidgets(4));

      await tester.tap(chip('CC / SDH'));
      await tester.pump();
      expect(find.textContaining('Movie.2020'), findsNWidgets(2));

      await tester.tap(chip('All'));
      await tester.pump();
      expect(find.textContaining('Movie.2020'), findsNWidgets(4));
    });

    testWidgets('a filter with nothing behind it does nothing', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(menu(variants: [variant('Movie.2020', 'u1')]));
      await tester.pump();

      // No forced track exists: pressing Forced must not empty the list.
      await tester.tap(chip('Forced'));
      await tester.pump();
      expect(find.textContaining('Movie.2020'), findsOneWidget);
    });
  });
}
