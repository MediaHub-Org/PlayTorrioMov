// test/widgets/focus_fill_test.dart
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
    expect((cue(tester).border! as Border).top.color, Colors.transparent);

    node.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(cue(tester).color, isNot(Colors.transparent));
    expect((cue(tester).border! as Border).top.color, isNot(Colors.transparent));
    // In the row's own box: nothing grows or moves.
    expect(tester.getSize(find.byKey(const Key('tile'))), const Size(200, 60));
    expect(tester.getSize(find.byType(FocusFill)), const Size(200, 60));
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
