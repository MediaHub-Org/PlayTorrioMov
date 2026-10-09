// test/widgets/focus_fill_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/widgets/common/focus_fill.dart';

Widget tile(FocusNode node) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: FocusFill(
        radius: 12,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: node,
            onTap: () {},
            // An opaque child, as the settings tiles have: the InkWell's own
            // focus tint is painted beneath this and never seen.
            child: Container(
              key: const Key('tile'),
              width: 200,
              height: 60,
              color: const Color(0xFF1B1D26),
            ),
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration cue(WidgetTester tester) => tester
    .widget<AnimatedContainer>(find.descendant(
      of: find.byType(FocusFill),
      matching: find.byType(AnimatedContainer),
    ))
    .decoration! as BoxDecoration;

void main() {
  testWidgets('a settings row shows focus even over an opaque child', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(tile(node));

    expect(cue(tester).color, Colors.transparent);

    node.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(cue(tester).color, isNot(Colors.transparent));
    expect(cue(tester).border, isNull, reason: 'a wash, not an outline');
    // In the row's own box: nothing grows or moves.
    expect(tester.getSize(find.byKey(const Key('tile'))), const Size(200, 60));
    expect(tester.getSize(find.byType(FocusFill)), const Size(200, 60));
  });

  testWidgets('a mouse over an opaque row shows it, lighter than focus', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(tile(node));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('tile'))));
    await tester.pump(const Duration(milliseconds: 300));
    final hover = cue(tester).color!;
    expect(hover, isNot(Colors.transparent));

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cue(tester).color, Colors.transparent);

    node.requestFocus();
    await tester.pump(const Duration(milliseconds: 300));
    expect(cue(tester).color!.a, greaterThan(hover.a));
  });

  testWidgets('a press shows, and the row still gets its tap', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: FocusFill(
            radius: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: node,
                onTap: () => taps++,
                child: Container(
                  key: const Key('tile'),
                  width: 200,
                  height: 60,
                  color: const Color(0xFF1B1D26),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('tile'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(cue(tester).color, isNot(Colors.transparent));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1, reason: 'the Listener watches; it does not take the tap');
    expect(cue(tester).color, Colors.transparent);
  });

  test('the theme gives focus a tint strong enough to see', () {
    final theme = AppThemeService.createThemeData(
      AppThemeService.currentPalette.value,
    );
    expect(theme.focusColor.a, greaterThan(0.2));
    expect(theme.sliderTheme.overlayColor, isNotNull);
    final overlay = theme.textButtonTheme.style!.overlayColor!;
    expect(
      overlay.resolve({WidgetState.focused})!.a,
      greaterThan(overlay.resolve({WidgetState.hovered})!.a),
    );
  });
}
