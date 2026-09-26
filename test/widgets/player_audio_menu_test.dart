// test/widgets/player_audio_menu_test.dart
//
// The menu is a list of languages and nothing else. Rows used to carry the
// container's own title, the codec and the channel layout; all three are
// gone, and this keeps them from creeping back -- each one is a thing to
// read past on the way to the only question the list answers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/widgets/player/player_audio_menu.dart';
import 'package:playtorriomov/widgets/player/player_menu_row.dart';

PlayerAudioTrack track(
  int index,
  String language, {
  String? codec,
  int? channels,
}) => PlayerAudioTrack(
  index: index,
  title: language,
  language: language,
  codec: codec,
  channels: channels,
);

Widget menu({
  List<PlayerAudioTrack> tracks = const [],
  int selected = 0,
  int? primary,
  ValueChanged<int>? onSelected,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: PlayerAudioMenu(
        audioTracks: tracks,
        selectedIndex: selected,
        primaryIndex: primary,
        onTrackSelected: onSelected ?? (_) {},
      ),
    ),
  ),
);

void main() {
  group('rows', () {
    testWidgets('one row per language, labelled by language', (tester) async {
      await tester.pumpWidget(
        menu(tracks: [track(1, 'English'), track(2, 'Italian')]),
      );
      await tester.pump();

      expect(find.byType(PlayerMenuRow), findsNWidgets(2));
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Italian'), findsOneWidget);
    });

    testWidgets('no codec or channel line under a row', (tester) async {
      await tester.pumpWidget(
        menu(
          tracks: [track(1, 'English', codec: 'eac3', channels: 6)],
        ),
      );
      await tester.pump();

      expect(find.textContaining('EAC3'), findsNothing);
      expect(find.textContaining('5.1'), findsNothing);
      expect(find.textContaining('eac3'), findsNothing);
    });

    testWidgets('tapping a row reports its track index', (tester) async {
      int? picked;
      await tester.pumpWidget(
        menu(
          tracks: [track(1, 'English'), track(2, 'Italian')],
          onSelected: (i) => picked = i,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Italian'));
      await tester.pump();

      expect(picked, 2);
    });

    testWidgets('the playing track is the ticked one', (tester) async {
      await tester.pumpWidget(
        menu(tracks: [track(1, 'English'), track(2, 'Italian')], selected: 2),
      );
      await tester.pump();

      final rows = tester
          .widgetList<PlayerMenuRow>(find.byType(PlayerMenuRow))
          .toList();
      expect(rows.where((r) => r.isSelected).single.title, 'Italian');
    });
  });

  group('the Original badge', () {
    testWidgets('marks the primary track', (tester) async {
      await tester.pumpWidget(
        menu(
          tracks: [track(1, 'English'), track(2, 'Italian')],
          primary: 1,
        ),
      );
      await tester.pump();

      expect(find.text('ORIGINAL'), findsOneWidget);
    });

    testWidgets('nothing is badged when the primary is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(menu(tracks: [track(1, 'English')]));
      await tester.pump();

      // Better to badge nothing than to badge a guess: there is no original
      // flag in the data, so an unknown primary must stay unmarked.
      expect(find.text('ORIGINAL'), findsNothing);
    });
  });

  group('sync', () {
    testWidgets('is not in this menu at all', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pump();

      // Audio sync was removed: the only sync a viewer reaches for is the
      // subtitle one, and a second control with the same name in a different
      // menu was a coin flip.
      expect(find.text('Audio sync'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
    });

    testWidgets('an empty track list still says so', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pump();

      expect(find.text('Default audio stream playing.'), findsOneWidget);
    });
  });
}