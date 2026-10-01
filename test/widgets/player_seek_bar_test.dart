// test/widgets/player_seek_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:playtorriomov/widgets/common/focus_ring.dart';
import 'package:playtorriomov/widgets/player/player_seek_bar.dart';

void main() {
  testWidgets('the scrubber takes the row, leaving only the time labels',
      (tester) async {
    // The labels were Flexible siblings of the Expanded track, so the three
    // split the row by flex factor and the track ended a third of the way
    // across: on a 1400px desktop window the scrubber stopped near x=520 with
    // the remaining time floating at x=960.
    tester.view.physicalSize = const Size(1400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: PlayerSeekBar(
            position: const Duration(seconds: 1),
            duration: const Duration(hours: 1, minutes: 50, seconds: 24),
            onSeek: (_) {},
          ),
        ),
      ),
    ));

    final start = tester.getRect(find.text('0:01'));
    final end = tester.getRect(find.text('-1:50:23'));

    expect(start.left, lessThan(60));
    expect(start.right, lessThan(100), reason: 'the start label hugs the edge');
    expect(end.right, greaterThan(1400 - 60),
        reason: 'the remaining label hugs the far edge');
    expect(end.left, greaterThan(1400 - 140),
        reason: 'so the track between them spans nearly the whole bar');
  });

  testWidgets('a focused scrubber seeks with Left/Right and draws no ring',
      (tester) async {
    // The ring read as a box drawn around a thin track; focus is the bar
    // itself turning a stronger violet (#80). Left/Right still move it.
    final seeks = <Duration>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerSeekBar(
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 50),
          onSeek: seeks.add,
        ),
      ),
    ));

    // Tab to the scrubber: the start label is not a stop, the track is first.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // The remaining-time label next to it still carries a (hidden) ring; the
    // track itself must not have lit one.
    final rings = tester.widgetList<FocusRing>(find.byType(FocusRing));
    expect(rings.where((r) => r.visible), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(seeks, isNotEmpty);
    expect(seeks.last, greaterThan(const Duration(minutes: 5)));
  });
}
