// test/widgets/player_center_controls_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_center_controls.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PlayerCenterControls', () {
    testWidgets('shows play icon when paused, pause icon when playing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PlayerCenterControls(isPlaying: false, onPlayPause: () {})),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      await tester.pumpWidget(
        wrap(PlayerCenterControls(isPlaying: true, onPlayPause: () {})),
      );
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('reports a tap through its callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(PlayerCenterControls(isPlaying: false, onPlayPause: () => taps++)),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect(taps, 1);
    });

    testWidgets('stays centered -- no seek buttons beside it', (tester) async {
      // Removed rather than kept behind a flag: every platform already has a
      // better way to do the same jump (see PlayerCenterControls's own doc
      // comment). This is the one thing left to protect against it quietly
      // coming back as a second, near-identical control.
      await tester.pumpWidget(
        wrap(PlayerCenterControls(isPlaying: false, onPlayPause: () {})),
      );

      expect(find.byIcon(Icons.replay_30_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_30_rounded), findsNothing);

      final screenCentre = tester.getCenter(find.byType(Scaffold)).dx;
      expect(
        tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dx,
        moreOrLessEquals(screenCentre, epsilon: 1.0),
      );
    });
  });
}
