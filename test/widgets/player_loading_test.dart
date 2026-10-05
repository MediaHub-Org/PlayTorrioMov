import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  });

  testWidgets('the logo fills progressively without showing a percentage', (
    tester,
  ) async {
    Future<void> pump(double progress) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerLoadingLogo(progress: progress)),
      ),
    );

    await pump(0.42);
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(ClipRect), findsOneWidget);

    await pump(1);
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets(
    'the visible part of the logo is the filled fraction, from the bottom',
    (tester) async {
      // The first version cut the logo with Align(heightFactor), which a
      // Stack's tight constraints ignore: the whole logo showed at 0%.
      Future<Rect> visibleAt(double progress) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: PlayerLoadingLogo(progress: progress)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final clip = tester.renderObject<RenderClipRect>(find.byType(ClipRect));
        return clip.clipper!.getClip(clip.size);
      }

      final quarter = await visibleAt(0.25);
      expect(quarter.height / quarter.bottom, closeTo(0.25, 1e-6));
      expect(quarter.bottom, greaterThan(0));

      final empty = await visibleAt(0);
      expect(empty.height, 0);

      final full = await visibleAt(1);
      expect(full.top, 0);
    },
  );
}
