// test/widgets/embedded_subtitle_order_test.dart
//
// Two things about the embedded list that a viewer notices immediately and a
// test can pin down: the order, and which track is on.
//
// The order was the muxer's, which is arbitrary -- a twelve-track disc put
// its languages in whatever order they were authored, so the list looked
// shuffled. The language being heard now leads, because that is the track a
// viewer is most likely to want; the rest are alphabetical, which is the
// order someone scanning for "Spanish" can use. When nothing matches the
// audio the whole list is alphabetical -- there is no second-best language
// to promote.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

Widget menu(
  List<PlayerEmbeddedSubtitle> embedded, {
  String? audioLanguage,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: PlayerSubtitleMenu(
        embeddedSubtitles: embedded,
        audioLanguage: audioLanguage,
        isSubtitleEnabled: false,
        onSelectVariant: (_) {},
        onSelectEmbedded: (_) {},
        onEnable: () {},
        onDisable: () {},
        onOpenSyncBar: () {},
      ),
    ),
  ),
);

PlayerEmbeddedSubtitle track(int index, String language, {bool isDefault = false}) =>
    PlayerEmbeddedSubtitle(
      index: index,
      title: language,
      language: language,
      isDefault: isDefault,
    );

/// The row titles, in the order they are drawn.
List<String> rowTitles(WidgetTester tester) => tester
    .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
    .map((r) => r.title)
    .toList();

void main() {
  group('embedded track order', () {
    testWidgets('is alphabetical, not the muxer\'s order', (tester) async {
      await tester.pumpWidget(
        menu([
          track(1, 'Spanish'),
          track(2, 'English'),
          track(3, 'French'),
          track(4, 'Arabic'),
        ]),
      );
      await tester.pump();

      expect(rowTitles(tester), ['Arabic', 'English', 'French', 'Spanish']);
    });

    testWidgets('puts the audio language first, then alphabetical', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          [
            track(1, 'Spanish'),
            track(2, 'English'),
            track(3, 'Arabic'),
            track(4, 'French'),
          ],
          audioLanguage: 'spa',
        ),
      );
      await tester.pump();

      // Spanish leads because it is being heard; the rest are alphabetical.
      expect(rowTitles(tester), ['Spanish', 'Arabic', 'English', 'French']);
    });

    testWidgets('is alphabetical when nothing matches the audio', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          [
            track(1, 'Spanish'),
            track(2, 'English', isDefault: true),
            track(3, 'Arabic'),
          ],
          audioLanguage: 'kor',
        ),
      );
      await tester.pump();

      // The file's own default is not promoted. It is the muxer's opinion,
      // not the viewer's, and with no audio match the list is simply
      // alphabetical.
      expect(rowTitles(tester), ['Arabic', 'English', 'Spanish']);
    });

    testWidgets('is case-insensitive when sorting', (tester) async {
      await tester.pumpWidget(
        menu([
          track(1, 'spanish'),
          track(2, 'Arabic'),
          track(3, 'english'),
        ]),
      );
      await tester.pump();

      expect(rowTitles(tester), ['Arabic', 'english', 'spanish']);
    });
  });

  group('the embedded tab', () {
    testWidgets('shows the file\'s tracks and not the online ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu([track(1, 'English'), track(2, 'Spanish')]),
      );
      await tester.pump();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
    });

    testWidgets('a file with no embedded tracks opens on Online', (
      tester,
    ) async {
      await tester.pumpWidget(menu(const []));
      await tester.pump();

      // Opening on an empty Embedded tab would read as "no subtitles".
      expect(find.text('No subtitles available for this stream'), findsOneWidget);
    });
  });
}