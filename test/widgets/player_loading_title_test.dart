// The loading screen says what is loading. Stremio leads with the title's
// logo; PlayerScreen had been handed one for years and never drew it, so a
// slow torrent waited on a screen that did not even name the movie.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_loading_title.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PlayerLoadingTitle', () {
    testWidgets('shows the name when the title has no logo', (tester) async {
      await tester.pumpWidget(wrap(const PlayerLoadingTitle(title: 'Dune')));

      expect(find.text('Dune'), findsOneWidget);
    });

    testWidgets('an empty logo URL is no logo', (tester) async {
      await tester.pumpWidget(
        wrap(const PlayerLoadingTitle(title: 'Dune', logoUrl: '')),
      );

      expect(find.text('Dune'), findsOneWidget);
    });

    testWidgets('shows the episode under the name', (tester) async {
      await tester.pumpWidget(wrap(const PlayerLoadingTitle(
        title: 'Severance',
        subtitle: 'S1 · E3 · In Perpetuity',
      )));

      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('S1 · E3 · In Perpetuity'), findsOneWidget);
    });

    testWidgets('a movie has no second line', (tester) async {
      await tester.pumpWidget(wrap(const PlayerLoadingTitle(title: 'Dune')));

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a long name stays inside two lines', (tester) async {
      await tester.pumpWidget(wrap(PlayerLoadingTitle(title: 'Long ' * 60)));

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('PlayerLoadingTitle.episodeLabel', () {
    test('season, episode and the episode name', () {
      expect(
        PlayerLoadingTitle.episodeLabel(
          season: 1,
          episode: 3,
          name: 'In Perpetuity',
        ),
        'S1 · E3 · In Perpetuity',
      );
    });

    test('numbers alone when the name adds nothing', () {
      expect(
        PlayerLoadingTitle.episodeLabel(season: 2, episode: 5, name: 'Episode 5'),
        'S2 · E5',
      );
      expect(
        PlayerLoadingTitle.episodeLabel(season: 2, episode: 5, name: 'Ep. 5'),
        'S2 · E5',
      );
      expect(
        PlayerLoadingTitle.episodeLabel(season: 2, episode: 5, name: ' '),
        'S2 · E5',
      );
    });

    test('an anime with no season is just its episode', () {
      expect(
        PlayerLoadingTitle.episodeLabel(episode: 12, name: 'The Battle'),
        'E12 · The Battle',
      );
    });

    test('nothing to say is null, not an empty line', () {
      expect(PlayerLoadingTitle.episodeLabel(), isNull);
      expect(PlayerLoadingTitle.episodeLabel(name: 'Episode 1'), isNull);
    });
  });
}
