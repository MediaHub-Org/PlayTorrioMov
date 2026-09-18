import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/settings/settings_scroll_view.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Rows that fill whatever width they are given, so measuring one measures
/// the content column. A bare Text would report its own glyph box instead,
/// which sits at the left edge and says nothing about the layout.
List<Widget> rows(int n) => [
  for (var i = 0; i < n; i++)
    Container(
      key: ValueKey('row $i'),
      height: 80,
      alignment: Alignment.centerLeft,
      child: Text('row $i'),
    ),
];

Rect rowRect(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(ValueKey('row $i')));

void main() {
  group('SettingsScrollView', () {
    testWidgets('the scrollable fills the window, not just the center', (
      tester,
    ) async {
      // The regression this exists for. Settings pages wrapped the ListView
      // in Center(ConstrainedBox(maxWidth: 800)), so on a wide desktop
      // window the scrollable was an 800px column in the middle -- the
      // wheel did nothing while the pointer was anywhere else, which on a
      // maximized window is most of the screen.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScrollView(children: rows(30))));

      final viewport = tester.getRect(find.byType(Scrollable));
      expect(viewport.left, 0);
      expect(viewport.right, 1600);
    });

    testWidgets('content still reads at the same width it always did', (
      tester,
    ) async {
      // Widening the scrollable must not widen the cards: the gutters take
      // the extra room, so a row is still 800px in the middle of a 1600px
      // window.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScrollView(children: rows(4))));

      final row = rowRect(tester, 0);
      expect(row.width, 800);
      expect(row.center.dx, closeTo(800, 1));

      final gutter = SettingsScrollView.gutterFor(1600);
      expect(gutter, 400);
    });

    testWidgets('a phone gets the minimum gutter, not a negative one', (
      tester,
    ) async {
      // (width - maxContentWidth) / 2 goes negative below 800px, which as a
      // padding would throw.
      expect(SettingsScrollView.gutterFor(360), 16);
      expect(SettingsScrollView.gutterFor(360, minGutter: 20), 20);

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScrollView(children: rows(20))));
      expect(tester.takeException(), isNull);

      final row = rowRect(tester, 0);
      expect(row.left, 16);
      expect(row.right, 344);
    });

    testWidgets('exactly at the content width the gutter is the minimum', (
      tester,
    ) async {
      expect(SettingsScrollView.gutterFor(800), 16);
      expect(SettingsScrollView.gutterFor(832), 16);
      // The first width where centring beats the minimum.
      expect(SettingsScrollView.gutterFor(833), greaterThan(16));
    });

    testWidgets('a wider content width is honoured', (tester) async {
      // The video player settings page asks for 820.
      expect(SettingsScrollView.gutterFor(1600, maxContentWidth: 820), 390);
    });

    testWidgets('it draws a scrollbar attached to its own list', (
      tester,
    ) async {
      // Scrollbar and ListView have to share one controller or the bar has
      // nothing to track and silently does not paint.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScrollView(children: rows(40))));

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the separated form lays out too', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          SettingsScrollView.separated(
            itemCount: 12,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => Container(
              key: ValueKey('item $i'),
              height: 60,
              alignment: Alignment.centerLeft,
              child: Text('item $i'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final viewport = tester.getRect(find.byType(Scrollable));
      expect(viewport.width, 1600);
      final item = tester.getRect(find.byKey(const ValueKey('item 0')));
      expect(item.width, 800);
      expect(item.center.dx, closeTo(800, 1));
    });

    testWidgets('scrolling works and reaches the end', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(SettingsScrollView(children: rows(30))));

      expect(find.text('row 29'), findsNothing);
      await tester.drag(find.byType(Scrollable), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('row 29'), findsOneWidget);
    });
  });
}
