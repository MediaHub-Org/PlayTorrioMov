// test/widgets/subtitle_overlay_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/player_settings.dart';
import 'package:playtorriomov/widgets/player/subtitle_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpOverlay(
  WidgetTester tester,
  Stream<List<String>> lines, {
  List<String> initial = const [],
  bool sample = false,
}) async {
  tester.view.physicalSize = const Size(800, 450);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: SubtitleOverlay(
          lines: lines,
          initialLines: initial,
          showSample: sample,
        ),
      ),
    ),
  ));
}

void main() {
  late StreamController<List<String>> controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = StreamController<List<String>>.broadcast();
    await PlayerSettings.setUseLibass(false);
    await PlayerSettings.setSubAlignX('center');
    await PlayerSettings.setSubPos(100);
    await PlayerSettings.setSubMarginY(30);
  });

  tearDown(() => controller.close());

  group('placement', () {
    test('the vertical position runs from the top (0) to the bottom (100)', () {
      expect(SubtitleOverlay.alignmentY(0), -1);
      expect(SubtitleOverlay.alignmentY(50), 0);
      expect(SubtitleOverlay.alignmentY(100), 1);
      expect(SubtitleOverlay.alignmentY(400), 1, reason: 'clamped');
    });

    test('the side maps to an alignment', () {
      expect(SubtitleOverlay.alignmentX('left'), -1);
      expect(SubtitleOverlay.alignmentX('center'), 0);
      expect(SubtitleOverlay.alignmentX('right'), 1);
      expect(SubtitleOverlay.alignmentX('anything else'), 0);
    });
  });

  group('SubtitleOverlay', () {
    testWidgets('draws the lines the player reports, dropping blank ones',
        (tester) async {
      await pumpOverlay(tester, controller.stream);
      expect(find.byType(Text), findsNothing);

      controller.add(['Hello there', '  ', 'General Kenobi']);
      await tester.pump();

      expect(find.text('Hello there\nGeneral Kenobi'), findsOneWidget);

      controller.add(<String>[]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(Text), findsNothing, reason: 'no dialogue, no text');
    });

    testWidgets('starts from the lines already showing', (tester) async {
      await pumpOverlay(tester, controller.stream, initial: ['Already here']);
      expect(find.text('Already here'), findsOneWidget);
    });

    testWidgets('Left, Center and Right move the text', (tester) async {
      await pumpOverlay(tester, controller.stream, initial: ['Hi']);
      final centre = tester.getCenter(find.text('Hi')).dx;
      expect(centre, closeTo(400, 2));

      await PlayerSettings.setSubAlignX('left');
      await tester.pump();
      expect(tester.getRect(find.text('Hi')).left, lessThan(60));

      await PlayerSettings.setSubAlignX('right');
      await tester.pump();
      expect(tester.getRect(find.text('Hi')).right, greaterThan(740));
    });

    testWidgets('the vertical position moves the text, and the margin lifts it',
        (tester) async {
      await pumpOverlay(tester, controller.stream, initial: ['Hi']);
      final atBottom = tester.getRect(find.text('Hi'));
      expect(atBottom.bottom, closeTo(450 - 30, 6),
          reason: 'bottom of the picture, less the 30px margin');

      await PlayerSettings.setSubMarginY(100);
      await tester.pump();
      expect(tester.getRect(find.text('Hi')).bottom, closeTo(450 - 100, 6));

      await PlayerSettings.setSubPos(0);
      await tester.pump();
      expect(tester.getRect(find.text('Hi')).top, lessThan(10),
          reason: '0 is the top of the picture');

      await PlayerSettings.setSubPos(50);
      await tester.pump();
      final mid = tester.getCenter(find.text('Hi')).dy;
      expect(mid, inInclusiveRange(150, 260));
    });

    testWidgets('sample mode shows two lines whatever the player says',
        (tester) async {
      await pumpOverlay(tester, controller.stream, sample: true);
      expect(find.text('Testing subtitles…\nThis is how your subtitles will look.'),
          findsOneWidget);

      controller.add(['Real dialogue']);
      await tester.pump();
      expect(find.text('Real dialogue'), findsNothing);
    });

    testWidgets('draws nothing when the native engine owns the text',
        (tester) async {
      await PlayerSettings.setUseLibass(true);
      await pumpOverlay(tester, controller.stream,
          initial: ['Hi'], sample: true);
      expect(find.byType(Text), findsNothing);
    });
  });
}
