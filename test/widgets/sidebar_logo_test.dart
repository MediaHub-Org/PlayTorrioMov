import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/app_info.dart';
import 'package:playtorriomov/widgets/common/sidebar_logo.dart';

/// Mirrors how the header actually places it: `Flexible`, so the logo gets
/// a bounded width and the wordmark can ellipsize.
///
/// A bare `Row(children: [SidebarLogo()])` would hand it *unbounded* width
/// -- that is what a Row gives a non-flex child -- and then nothing inside
/// can shrink. That models a placement the app does not use, and the first
/// version of this test did exactly that and failed on it.
Widget wrap({double width = 800}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: const Row(children: [Flexible(child: SidebarLogo())]),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the wordmark alongside the icon', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the film-strip accent is painted under the wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    final paint = find.descendant(
      of: find.byType(SidebarLogo),
      matching: find.byType(CustomPaint),
    );
    expect(paint, findsWidgets);

    // Under, not beside: the icon already owns the left, and a second mark
    // there would crowd a phone header that also carries Settings.
    expect(
      tester.getCenter(paint.first).dy,
      greaterThan(tester.getCenter(find.text(AppInfo.name)).dy),
    );
  });

  testWidgets('survives a narrow header without overflowing', (tester) async {
    // 200px is narrower than the logo's natural width, so the wordmark has
    // to ellipsize and the accent has to still fit beneath it.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(width: 200));

    expect(tester.takeException(), isNull);
    expect(find.text(AppInfo.name), findsOneWidget);
  });
}
