import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_glass.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PlayerMenuHeader', () {
    testWidgets('a root menu offers no way back', (tester) async {
      // Nothing was stepped into, so a back arrow would promise a screen
      // the user never came from.
      await tester.pumpWidget(wrap(const PlayerMenuHeader(title: 'SETTINGS')));

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('a stepped-into menu offers a way back', (tester) async {
      await tester.pumpWidget(
        wrap(PlayerMenuHeader(title: 'PLAYBACK SPEED', onBack: () {})),
      );

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('carries no close button, at any depth', (tester) async {
      // Tapping off the panel dismisses it -- player_screen puts a
      // full-screen barrier behind every open menu -- so an X was a third
      // way to do what the barrier and the back arrow already did, and it
      // cost the header's whole right end.
      await tester.pumpWidget(wrap(const PlayerMenuHeader(title: 'SETTINGS')));
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.pumpWidget(
        wrap(PlayerMenuHeader(title: 'ASPECT RATIO', onBack: () {})),
      );
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('the back arrow reports back, and only back', (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        wrap(PlayerMenuHeader(title: 'ASPECT RATIO', onBack: () => backs++)),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(backs, 1);
    });

    testWidgets('the back arrow leads the title', (tester) async {
      await tester.pumpWidget(
        wrap(PlayerMenuHeader(title: 'SUBTITLES', onBack: () {})),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.arrow_back_ios_new_rounded)).dx,
        lessThan(tester.getCenter(find.text('SUBTITLES')).dx),
      );
    });

    testWidgets('a trailing widget sits at the far end', (tester) async {
      await tester.pumpWidget(
        wrap(
          const PlayerMenuHeader(
            title: 'AUDIO',
            trailing: Icon(Icons.headphones_rounded),
          ),
        ),
      );

      expect(
        tester.getCenter(find.byIcon(Icons.headphones_rounded)).dx,
        greaterThan(tester.getCenter(find.text('AUDIO')).dx),
      );
    });

    testWidgets('a long title is clipped, not overflowed', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          PlayerMenuHeader(
            title: 'A VERY LONG MENU TITLE THAT WOULD NOT OTHERWISE FIT',
            onBack: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
