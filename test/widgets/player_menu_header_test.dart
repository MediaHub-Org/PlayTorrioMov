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
      await tester.pumpWidget(wrap(
        PlayerMenuHeader(title: 'SETTINGS', onClose: () {}),
      ));

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('a stepped-into menu offers back and close', (tester) async {
      await tester.pumpWidget(wrap(
        PlayerMenuHeader(
          title: 'PLAYBACK SPEED',
          onBack: () {},
          onClose: () {},
        ),
      ));

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('back and close are separate actions', (tester) async {
      // Back returns to settings; close dismisses the panel. Wiring one to
      // the other would make the arrow a second close button.
      var backs = 0;
      var closes = 0;
      await tester.pumpWidget(wrap(
        PlayerMenuHeader(
          title: 'ASPECT RATIO',
          onBack: () => backs++,
          onClose: () => closes++,
        ),
      ));

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(backs, 1);
      expect(closes, 0);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(backs, 1);
      expect(closes, 1);
    });

    testWidgets('the back arrow leads the title', (tester) async {
      await tester.pumpWidget(wrap(
        PlayerMenuHeader(title: 'SUBTITLES', onBack: () {}, onClose: () {}),
      ));

      expect(
        tester.getCenter(find.byIcon(Icons.arrow_back_ios_new_rounded)).dx,
        lessThan(tester.getCenter(find.text('SUBTITLES')).dx),
      );
    });

    testWidgets('a long title is clipped, not overflowed', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(
        PlayerMenuHeader(
          title: 'A VERY LONG MENU TITLE THAT WOULD NOT OTHERWISE FIT',
          onBack: () {},
          onClose: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
