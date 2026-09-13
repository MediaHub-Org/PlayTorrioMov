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
        wrap(
          PlayerCenterControls(
            isPlaying: false,
            onPlayPause: () {},
            onSeekBack10: () {},
            onSeekForward10: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      await tester.pumpWidget(
        wrap(
          PlayerCenterControls(
            isPlaying: true,
            onPlayPause: () {},
            onSeekBack10: () {},
            onSeekForward10: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('each button reports through its own callback', (
      tester,
    ) async {
      var playPauseTaps = 0;
      var back10Taps = 0;
      var forward10Taps = 0;

      await tester.pumpWidget(
        wrap(
          PlayerCenterControls(
            isPlaying: false,
            onPlayPause: () => playPauseTaps++,
            onSeekBack10: () => back10Taps++,
            onSeekForward10: () => forward10Taps++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.tap(find.byIcon(Icons.forward_10_rounded));

      expect(playPauseTaps, 1);
      expect(back10Taps, 1);
      expect(forward10Taps, 1);
    });

    testWidgets('a live stream gets play/pause alone, still centred', (
      tester,
    ) async {
      // Seeking has no meaning without a duration, so the ±10s buttons take
      // no callbacks on a live stream. The button that remains has to stay
      // where it was, or Live TV reads as a different player -- which is
      // what sharing this widget is for.
      await tester.pumpWidget(
        wrap(PlayerCenterControls(isPlaying: false, onPlayPause: () {})),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_10_rounded), findsNothing);

      final screenCentre = tester.getCenter(find.byType(Scaffold)).dx;
      expect(
        tester.getCenter(find.byIcon(Icons.play_arrow_rounded)).dx,
        moreOrLessEquals(screenCentre, epsilon: 1.0),
      );
    });

    testWidgets('the seekable layout keeps play/pause between the skips', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PlayerCenterControls(
            isPlaying: true,
            onPlayPause: () {},
            onSeekBack10: () {},
            onSeekForward10: () {},
          ),
        ),
      );

      final back = tester.getCenter(find.byIcon(Icons.replay_10_rounded)).dx;
      final play = tester.getCenter(find.byIcon(Icons.pause_rounded)).dx;
      final forward =
          tester.getCenter(find.byIcon(Icons.forward_10_rounded)).dx;

      expect(back, lessThan(play));
      expect(forward, greaterThan(play));
    });

    testWidgets('one side alone is honoured rather than dropping both', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          PlayerCenterControls(
            isPlaying: true,
            onPlayPause: () {},
            onSeekForward10: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    });
  });
}
