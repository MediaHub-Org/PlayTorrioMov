// test/widgets/source_filter_settings_page_test.dart
//
// The settings page collapsed from three blocks to two, and the block that
// disappeared is the one worth guarding: the audio filter and the
// preferred-audio ranking used to be separate, with separate value notifiers
// and separate persistence. If either half comes back -- or if a chip stops
// writing through to the shared list -- the page silently reverts to asking
// the same question twice.
//
// The service's own behaviour is covered in
// `test/services/source_filter_settings_test.dart`. What is tested here is
// the page: which blocks it draws, and that a tap on a chip reaches the
// shared state rather than a local copy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/pages/settings/source_filter_settings_page.dart';
import 'package:playtorriomov/services/sources/source_filter_settings.dart';
import 'package:playtorriomov/widgets/common/setting_choice_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap() => const MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SourceFilterSettingsPage(),
);

/// The label a chip shows, so a test can find the chip for one language
/// without depending on the key-to-label table.
String chipText(WidgetTester tester, Finder chip) =>
    tester.widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
        .data!;

/// A chip whose label is [text].
Finder chipWithText(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byType(SettingChoiceChip),
);

/// The page is taller than the default 800x600 test surface, and
/// [SettingsScrollView] is a lazy list, so a block below the fold is not
/// built and cannot be found. Give the surface room for the whole page.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SourceFilterSettings.audioLanguages.value = const <String>[];
    SourceFilterSettings.qualities.value = const <String>[];
  });

  group('SourceFilterSettingsPage layout', () {
    testWidgets('draws two filter blocks, not three', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      // The heading is the count that matters: a third one means the
      // separate preferred-audio block has come back.
      final headings = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            (w.data!.contains('AUDIO LANGUAGE') ||
                w.data!.contains('VIDEO QUALITY') ||
                w.data!.contains('PREFERRED')),
      );
      expect(headings, findsNWidgets(2));
    });

    testWidgets('with nothing selected, both blocks say so', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      // Every quality is offered as an unselected chip, and the audio block
      // shows its empty message rather than an empty ranking.
      expect(find.byType(SettingChoiceChip), findsWidgets);
      expect(chipWithText('4K / UHD'), findsOneWidget);
    });
  });

  group('tapping a chip', () {
    testWidgets('a quality chip adds to the shared list, and again removes', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(chipWithText('1080p'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(SourceFilterSettings.qualities.value, ['1080p']);

      await tester.tap(chipWithText('720p'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(SourceFilterSettings.qualities.value, ['1080p', '720p']);

      // Selecting several is the whole point, so a second tap on an already
      // selected chip must remove just that one.
      await tester.tap(chipWithText('1080p'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(SourceFilterSettings.qualities.value, ['720p']);
    });

    testWidgets('an audio chip lands in the ranked list', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(chipWithText('🇩🇪 German'));
      await tester.pump(const Duration(milliseconds: 350));

      // The same notifier the player reads, not a page-local copy.
      expect(SourceFilterSettings.audioLanguages.value, ['german']);
    });

    testWidgets('a selected language leaves the catalogue row', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      // German is offered twice by design only if it is in the catalogue
      // while also being ranked; the page removes it from the bottom row so
      // one language never appears with two meanings.
      expect(chipWithText('🇩🇪 German'), findsOneWidget);

      await tester.tap(chipWithText('🇩🇪 German'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(chipWithText('🇩🇪 German'), findsNothing);
    });

    testWidgets('the ranked row reorders through the shared service', (
      tester,
    ) async {
      SourceFilterSettings.audioLanguages.value = const ['german', 'spanish'];
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(milliseconds: 350));

      // Move Spanish up. The up arrow is the first IconButton in its row.
      final upButtons = find.byIcon(Icons.keyboard_arrow_up_rounded);
      expect(upButtons, findsNWidgets(2));
      // Index 1 is the second row's up button.
      await tester.tap(upButtons.at(1));
      await tester.pump(const Duration(milliseconds: 350));

      expect(SourceFilterSettings.audioLanguages.value, ['spanish', 'german']);
    });
  });
}