// test/widgets/player_seek_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
