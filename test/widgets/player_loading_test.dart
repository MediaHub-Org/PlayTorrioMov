import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/player/player_load_progress.dart';
import 'package:playtorriomov/widgets/player/player_loading_logo.dart';

void main() {
  group('PlayerLoadProgress', () {
    test('only moves forward', () {
      final progress = PlayerLoadProgress();
      progress.reach(PlayerLoadProgress.resolved);
      progress.reach(PlayerLoadProgress.started);
      expect(progress.value, PlayerLoadProgress.resolved);
    });

    test('buffering fills what is left after the player opens', () {
      final progress = PlayerLoadProgress();
      progress.reachBuffering(0);
      expect(progress.value, PlayerLoadProgress.opened);
      progress.reachBuffering(0.5);
      expect(progress.value, closeTo(0.7, 1e-9));
      progress.reachBuffering(1);
      expect(progress.value, 1);
    });

    test('out-of-range input is clamped, not trusted', () {
      final progress = PlayerLoadProgress();
      progress.reachBuffering(5);
      expect(progress.value, 1);
      progress.reset();
      progress.reach(-1);
      expect(progress.value, 0);
    });

    test('percent rounds down so 100 means done', () {
      expect(PlayerLoadProgress.percentOf(0.999), 99);
      expect(PlayerLoadProgress.percentOf(1), 100);
      expect(PlayerLoadProgress.percentOf(0.4), 40);
    });
  });

  testWidgets('the logo shows the percent and settles on it', (tester) async {
    Future<void> pump(double progress) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: PlayerLoadingLogo(progress: progress))),
        );

    await pump(0.42);
    await tester.pumpAndSettle();
    expect(find.text('42%'), findsOneWidget);

    await pump(1);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });
}
