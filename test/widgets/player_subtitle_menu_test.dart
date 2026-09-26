// test/widgets/player_subtitle_menu_test.dart
//
// Two things are worth guarding here. The rows are languages, not files --
// four OpenSubtitles files for Arabic are one row, because a list of files
// buried the languages it was meant to list. And the on/off control is one
// button whose label names where a press takes you, not two chips with one
// of them dead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';
import 'package:playtorriomov/widgets/player/player_subtitle_menu.dart';

SubtitleVariant variant(String language, String url) => SubtitleVariant(
  providerName: 'test',
  language: language,
  title: '',
  downloadUrl: url,
  format: 'srt',
);

Widget menu({
  List<SubtitleLanguageGroup> groups = const [],
  List<PlayerEmbeddedSubtitle> embedded = const [],
  bool enabled = false,
  SubtitleVariant? selected,
  int? selectedEmbedded,
  ValueChanged<SubtitleVariant>? onVariant,
  VoidCallback? onEnable,
  VoidCallback? onDisable,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: PlayerSubtitleMenu(
        groups: groups,
        embeddedSubtitles: embedded,
        selectedVariant: selected,
        selectedEmbeddedIndex: selectedEmbedded,
        isSubtitleEnabled: enabled,
        onSelectVariant: onVariant ?? (_) {},
        onSelectEmbedded: (_) {},
        onEnable: onEnable ?? () {},
        onDisable: onDisable ?? () {},
        onOpenSyncBar: () {},
      ),
    ),
  ),
);

void main() {
  group('rows are languages, not files', () {
    testWidgets('four files for one language are one row', (tester) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [
                variant('Arabic', 'a1'),
                variant('Arabic', 'a2'),
                variant('Arabic', 'a3'),
                variant('Arabic', 'a4'),
              ],
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('4 files'), findsOneWidget);
    });

    testWidgets('the per-file tags are not shown at all', (tester) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'a1')],
            ),
          ],
        ),
      );
      await tester.pump();

      // Provider, format and release tags were the clutter this removed.
      expect(find.textContaining('SRT'), findsNothing);
      expect(find.textContaining('BluRay'), findsNothing);
      expect(find.textContaining('test'), findsNothing);
    });

    testWidgets('picking a language picks its best file', (tester) async {
      SubtitleVariant? picked;
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'best'), variant('Arabic', 'worse')],
            ),
          ],
          onVariant: (v) => picked = v,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Arabic'));
      await tester.pump();

      expect(picked?.downloadUrl, 'best');
    });

    testWidgets('embedded and online are separate tabs, not one list', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          embedded: const [
            PlayerEmbeddedSubtitle(
              index: 1,
              title: 'English',
              language: 'English',
            ),
          ],
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'a')],
            ),
          ],
        ),
      );
      await tester.pump();

      // The file has embedded tracks, so it opens on that tab and the online
      // list is not mixed in with it.
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Arabic'), findsNothing);

      await tester.tap(find.textContaining('Online'));
      await tester.pump();

      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('English'), findsNothing);
    });

    testWidgets('a file with no embedded tracks opens on Online', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'a')],
            ),
          ],
        ),
      );
      await tester.pump();

      // Opening on an empty Embedded tab would look like "no subtitles".
      expect(find.text('Arabic'), findsOneWidget);
    });

    testWidgets('nothing available says so', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pump();

      expect(
        find.text('No subtitles available for this stream'),
        findsOneWidget,
      );
    });
  });

  group('the on/off button', () {
    testWidgets('offers to turn subtitles on while they are off', (
      tester,
    ) async {
      await tester.pumpWidget(menu(enabled: false));
      await tester.pump();

      expect(find.text('Turn subtitles on'), findsOneWidget);
      expect(find.text('Turn subtitles off'), findsNothing);
      expect(find.byIcon(Icons.closed_caption_disabled_rounded), findsOneWidget);
    });

    testWidgets('offers to turn them off while they are on', (tester) async {
      await tester.pumpWidget(
        menu(enabled: true, selected: variant('English', 'e')),
      );
      await tester.pump();

      expect(find.text('Turn subtitles off'), findsOneWidget);
      expect(find.text('Turn subtitles on'), findsNothing);
      expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
    });

    testWidgets('a press while off calls onEnable, not onDisable', (
      tester,
    ) async {
      var enabled = 0;
      var disabled = 0;
      await tester.pumpWidget(
        menu(
          enabled: false,
          onEnable: () => enabled++,
          onDisable: () => disabled++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Turn subtitles on'));
      await tester.pump();

      expect(enabled, 1);
      expect(disabled, 0);
    });

    testWidgets('a press while on calls onDisable, not onEnable', (
      tester,
    ) async {
      var enabled = 0;
      var disabled = 0;
      await tester.pumpWidget(
        menu(
          enabled: true,
          selected: variant('English', 'e'),
          onEnable: () => enabled++,
          onDisable: () => disabled++,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Turn subtitles off'));
      await tester.pump();

      expect(disabled, 1);
      expect(enabled, 0);
    });

    testWidgets('it is one control, not two chips', (tester) async {
      await tester.pumpWidget(menu(enabled: false));
      await tester.pump();

      // The old panel drew an On chip and an Off chip, so one of them was
      // always inert and the pair read as a state rather than an action.
      expect(find.text('On'), findsNothing);
      expect(find.text('Off'), findsNothing);
    });
  });

  group('selection marks the row', () {
    testWidgets('the playing language is the one ticked', (tester) async {
      await tester.pumpWidget(
        menu(
          enabled: true,
          selected: variant('Arabic', 'a'),
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'a')],
            ),
            SubtitleLanguageGroup(
              language: 'French',
              variants: [variant('French', 'f')],
            ),
          ],
        ),
      );
      await tester.pump();

      final rows = tester
          .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
          .toList();
      final ticked = rows.where((r) => r.isSelected).toList();
      expect(ticked.length, 1);
      expect(ticked.single.title, 'Arabic');
    });

    testWidgets('with subtitles off nothing is ticked', (tester) async {
      await tester.pumpWidget(
        menu(
          enabled: false,
          selected: variant('Arabic', 'a'),
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'a')],
            ),
          ],
        ),
      );
      await tester.pump();

      final rows = tester
          .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
          .toList();
      expect(rows.every((r) => !r.isSelected), isTrue);
    });
  });
}