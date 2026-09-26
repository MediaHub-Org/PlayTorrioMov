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
  group('the online list marks exactly one row', () {
    testWidgets('a variant with no URL does not select every row', (
      tester,
    ) async {
      // The whole online list drew as selected. The comparison was
      // `selectedVariant?.downloadUrl == variant.downloadUrl`, and when both
      // sides were empty every row matched.
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [
                SubtitleVariant(
                  providerName: 'SubtitleCat',
                  language: 'Arabic',
                  title: 'Standard',
                  downloadUrl: '',
                  format: 'srt',
                ),
                SubtitleVariant(
                  providerName: 'OpenSubtitles',
                  language: 'Arabic',
                  title: 'Standard',
                  downloadUrl: '',
                  format: 'srt',
                ),
              ],
            ),
          ],
          enabled: true,
          selected: SubtitleVariant(
            providerName: 'SubtitleCat',
            language: 'Arabic',
            title: 'Standard',
            downloadUrl: '',
            format: 'srt',
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);
    });

    testWidgets('the selected file is the only one marked', (tester) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [
                variant('Arabic', 'https://x/1.srt'),
                variant('Arabic', 'https://x/2.srt'),
              ],
            ),
          ],
          enabled: true,
          selected: variant('Arabic', 'https://x/2.srt'),
        ),
      );
      await tester.pump();

      // The language row is marked, and so is the file inside it once the
      // row is opened -- but never both files.
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    });
  });

  group('a file row does not repeat its own format', () {
    testWidgets('the format is dropped when the title already says it', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [
                SubtitleVariant(
                  providerName: 'SubtitleCat',
                  language: 'Arabic',
                  title: 'Movie.srt',
                  downloadUrl: 'https://x/1.srt',
                  format: 'srt',
                ),
                SubtitleVariant(
                  providerName: 'SubtitleCat',
                  language: 'Arabic',
                  title: 'Movie.srt',
                  downloadUrl: 'https://x/2.srt',
                  format: 'srt',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Arabic'));
      await tester.pump();

      // "SubtitleCat · SRT · Movie.srt" says SRT twice.
      expect(find.textContaining('SRT'), findsNothing);
      expect(find.textContaining('SubtitleCat'), findsWidgets);
    });

    testWidgets('the format is kept when the title does not say it', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [
                SubtitleVariant(
                  providerName: 'SubDL',
                  language: 'Arabic',
                  title: 'BluRay',
                  downloadUrl: 'https://x/1.srt',
                  format: 'srt',
                ),
                SubtitleVariant(
                  providerName: 'SubDL',
                  language: 'Arabic',
                  title: 'WEB-DL',
                  downloadUrl: 'https://x/2.srt',
                  format: 'srt',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Arabic'));
      await tester.pump();

      expect(find.textContaining('SRT'), findsWidgets);
    });
  });

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

      // One row, not four. The count is a reason to tap -- it says there is
      // more than one file here -- rather than a fact about the
      // implementation.
      expect(find.text('Arabic'), findsOneWidget);
      expect(find.text('4 files'), findsOneWidget);
    });

    testWidgets('tapping the row picks the best file and opens the rest', (
      tester,
    ) async {
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

      // One tap does both: it picks the best file, the way Netflix and
      // Disney+ do, and opens the rest so a wrong pick is visible without a
      // second gesture to discover.
      expect(picked?.downloadUrl, 'best');
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      expect(find.textContaining('test'), findsWidgets);
    });

    testWidgets('tapping the open row again collapses it', (tester) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'best'), variant('Arabic', 'worse')],
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Arabic'));
      await tester.pump();
      await tester.tap(find.text('Arabic'));
      await tester.pump();

      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      expect(find.textContaining('test'), findsNothing);
    });

    testWidgets('a single-file language has no chevron and no sub-list', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: 'Arabic',
              variants: [variant('Arabic', 'only')],
            ),
          ],
        ),
      );
      await tester.pump();

      // Nothing to open, so nothing offers to.
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
      expect(find.textContaining('files'), findsNothing);
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

  group('online ordering and filtering', () {
    List<SubtitleLanguageGroup> tenEach() => [
      SubtitleLanguageGroup(
        language: 'Spanish',
        variants: [for (var i = 0; i < 10; i++) variant('Spanish', 'es$i')],
      ),
      SubtitleLanguageGroup(
        language: 'Chinese',
        variants: [for (var i = 0; i < 10; i++) variant('Chinese', 'zh$i')],
      ),
    ];

    Future<List<String>> rowTitles(WidgetTester tester) async {
      await tester.pump();
      return tester
          .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
          .map((r) => r.title)
          .toList();
    }

    testWidgets('identical file counts fall back to alphabetical', (
      tester,
    ) async {
      // Spanish before Chinese with ten files each is only correct when
      // the audio is Spanish. With no spoken match the tie breaks
      // alphabetically, so Chinese leads.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: PlayerSubtitleMenu(
                groups: tenEach(),
                embeddedSubtitles: const [],
                selectedVariant: null,
                selectedEmbeddedIndex: null,
                isSubtitleEnabled: false,
                audioLanguage: 'English',
                onSelectVariant: (_) {},
                onSelectEmbedded: (_) {},
                onEnable: () {},
                onDisable: () {},
                onOpenSyncBar: () {},
              ),
            ),
          ),
        ),
      );
      final titles = await rowTitles(tester);
      expect(titles.indexOf('Chinese'), lessThan(titles.indexOf('Spanish')));
    });

    testWidgets('the language being heard still leads on a tie', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: PlayerSubtitleMenu(
                groups: tenEach(),
                embeddedSubtitles: const [],
                selectedVariant: null,
                selectedEmbeddedIndex: null,
                isSubtitleEnabled: false,
                audioLanguage: 'Spanish',
                onSelectVariant: (_) {},
                onSelectEmbedded: (_) {},
                onEnable: () {},
                onDisable: () {},
                onOpenSyncBar: () {},
              ),
            ),
          ),
        ),
      );
      final titles = await rowTitles(tester);
      expect(titles.indexOf('Spanish'), lessThan(titles.indexOf('Chinese')));
    });

    testWidgets('a language with no name is not offered', (tester) async {
      await tester.pumpWidget(
        menu(
          groups: [
            SubtitleLanguageGroup(
              language: '',
              variants: [variant('', 'noname')],
            ),
            SubtitleLanguageGroup(
              language: 'French',
              variants: [variant('French', 'f')],
            ),
          ],
        ),
      );
      final titles = await rowTitles(tester);
      expect(titles, isNot(contains('')));
      expect(titles, contains('French'));
    });

    testWidgets('expanding the playing language moves the tick to the file', (
      tester,
    ) async {
      // Collapsed, the group row ticks. Open, the tick moves down to the
      // file -- the group staying ticked beside it read as two selections.
      // Either way exactly one radio is ever marked.
      final files = [variant('Chinese', 'zh1'), variant('Chinese', 'zh2')];
      Future<List<PlayerMenuRow>> tickedRows() async {
        await tester.pump();
        return tester
            .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
            .where((r) => r.isSelected)
            .toList();
      }

      await tester.pumpWidget(
        menu(
          enabled: true,
          selected: files.first,
          groups: [
            SubtitleLanguageGroup(language: 'Chinese', variants: files),
            SubtitleLanguageGroup(
              language: 'English',
              variants: [variant('English', 'en1')],
            ),
          ],
        ),
      );
      var ticked = await tickedRows();
      expect(ticked.length, 1);
      expect(ticked.single.title, 'Chinese');

      await tester.tap(find.text('Chinese'));
      ticked = await tickedRows();
      expect(ticked.length, 1);
      expect(ticked.single.title, isNot('Chinese'));
    });

    testWidgets('one file shared by two languages ticks exactly one row', (
      tester,
    ) async {
      // A provider lists the same file under every language it was
      // translated into, so the URL alone matched a row in each group and
      // the radio list showed several. The selected file went through the
      // same grouping on its way in, so mapping it back names one group.
      const sharedUrl = 'https://x/shared.srt';
      await tester.pumpWidget(
        menu(
          enabled: true,
          selected: SubtitleVariant(
            providerName: 'SubtitleCat',
            language: 'Spanish (ES)',
            title: 'Standard',
            downloadUrl: sharedUrl,
            format: 'srt',
          ),
          groups: [
            SubtitleLanguageGroup(
              language: 'Spanish (ES)',
              variants: [
                SubtitleVariant(
                  providerName: 'SubtitleCat',
                  language: 'Spanish (ES)',
                  title: 'Standard',
                  downloadUrl: sharedUrl,
                  format: 'srt',
                ),
              ],
            ),
            SubtitleLanguageGroup(
              language: 'English',
              variants: [
                SubtitleVariant(
                  providerName: 'SubtitleCat',
                  language: 'English',
                  title: 'Standard',
                  downloadUrl: sharedUrl,
                  format: 'srt',
                ),
              ],
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
      expect(ticked.single.title, 'Spanish (ES)');
    });
  });

  group('the Forced pill', () {
    PlayerEmbeddedSubtitle embedded({
      required int index,
      required String language,
      bool forced = false,
    }) => PlayerEmbeddedSubtitle(
      index: index,
      title: language,
      language: language,
      isForcedTrack: forced,
    );

    SubtitleVariant online({
      required String language,
      required String url,
      bool forced = false,
    }) => SubtitleVariant(
      providerName: 'SubtitleCat',
      language: language,
      title: 'Standard',
      downloadUrl: url,
      format: 'srt',
      isForced: forced,
    );

    // The pill precedes the chips in the column, and it carries its
    // count ("Forced  2") while the chip reads bare, so the first partial
    // match is the pill while both are visible.
    Future<void> openForced(WidgetTester tester) async {
      await tester.tap(find.textContaining('Forced').first);
      await tester.pump();
    }

    testWidgets('shows forced files from both sides, nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          embedded: [
            embedded(index: 1, language: 'Spanish (ES)', forced: true),
            embedded(index: 2, language: 'English'),
          ],
          groups: [
            SubtitleLanguageGroup(
              language: 'Spanish (ES)',
              variants: [
                online(language: 'Spanish (ES)', url: 'es-forced', forced: true),
                online(language: 'Spanish (ES)', url: 'es-full'),
              ],
            ),
            SubtitleLanguageGroup(
              language: 'English',
              variants: [online(language: 'English', url: 'en-full')],
            ),
          ],
        ),
      );
      await openForced(tester);

      // Embedded forced tracks lead; the online forced group follows; the
      // full translation and the plain embedded track stay out.
      expect(find.text('Spanish (ES)'), findsNWidgets(2));
      expect(find.text('English'), findsNothing);
    });

    testWidgets('an empty Forced view says so', (tester) async {
      await tester.pumpWidget(
        menu(
          embedded: [embedded(index: 1, language: 'English')],
          groups: [
            SubtitleLanguageGroup(
              language: 'English',
              variants: [online(language: 'English', url: 'en-full')],
            ),
          ],
        ),
      );
      await openForced(tester);

      expect(
        find.text('No forced subtitles for this stream'),
        findsOneWidget,
      );
    });

    testWidgets('the Forced chip hides while the Forced pill shows', (
      tester,
    ) async {
      await tester.pumpWidget(menu());
      // Online view: the pill and the chip both read "Forced".
      expect(find.text('Forced'), findsNWidgets(2));
      await openForced(tester);
      // Forced view: the pill alone. A chip for the view's own filter
      // would change nothing and read as broken.
      expect(find.text('Forced'), findsOneWidget);
    });
  });
}
