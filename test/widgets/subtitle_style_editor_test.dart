// test/widgets/subtitle_style_editor_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/player_settings.dart';
import 'package:playtorriomov/widgets/player/player_sub_style_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget editor({double height = 700}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: height, child: const SubtitleStyleEditor()),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('background opacity', () {
    test('reads the alpha of a #AARRGGBB string', () {
      expect(subtitleBackgroundOpacity('#00000000'), 0);
      expect(subtitleBackgroundOpacity('#FF000000'), 1);
      expect(subtitleBackgroundOpacity('#80000000'), closeTo(0.5, 0.01));
      expect(subtitleBackgroundOpacity('nonsense'), 0);
    });

    test('changes the alpha and keeps the tint', () {
      expect(withSubtitleBackgroundOpacity('#800F172A', 1), '#FF0F172A');
      expect(withSubtitleBackgroundOpacity('#00000000', 0.5), '#80000000');
      expect(withSubtitleBackgroundOpacity('garbage', 0), '#00000000');
    });
  });

  testWidgets('the background is a slider, not a list of boxes', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await PlayerSettings.setSubBackColor('#00000000');

    await tester.pumpWidget(editor());
    await tester.pump();

    expect(find.textContaining('INDIGO'), findsNothing);
    expect(find.textContaining('Indigo'), findsNothing);
    expect(find.text('BACKGROUND OPACITY: 0%'), findsOneWidget);
  });

  testWidgets('dragging the slider moves the background alpha', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await PlayerSettings.setSubBackColor('#000F172A');

    await tester.pumpWidget(editor());
    await tester.pump();

    final backgroundSlider = find.byWidgetPredicate(
      (w) => w is Slider && w.min == 0.0 && w.max == 1.0,
    );
    expect(backgroundSlider, findsOneWidget);

    // Dragging to the far right end makes it solid; the tint survives.
    await tester.drag(backgroundSlider, const Offset(2000, 0));
    await tester.pump();
    expect(PlayerSettings.subBackColor.value, '#FF0F172A');
  });

  testWidgets('fonts are chips, so no dropdown opens its own menu', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(editor());
    await tester.pump();
    expect(find.byType(DropdownButton<String>), findsNothing);
    final page = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('More options'), 300, scrollable: page);
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Georgia'), 200, scrollable: page);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.ensureVisible(find.text('Georgia'));
    await tester.pump();
    await tester.tap(find.text('Georgia'));
    await tester.pump();
    expect(PlayerSettings.subFont.value, 'Georgia');
  });
}
