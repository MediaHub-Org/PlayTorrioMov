// test/widgets/section_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/utils/hub_controller.dart';
import 'package:playtorriomov/widgets/common/section_top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    // HubController is a singleton, so reset the active section between tests.
    HubController.instance.setMediaSection('movies');
  });

  group('SectionTopBar', () {
    testWidgets('renders nothing on mobile — the bottom bar owns sections there',
        (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.text('Movies'), findsNothing);
      expect(find.text('Anime'), findsNothing);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets('desktop shows every section as a chip', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('desktop chip tap switches the section', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();

      expect(HubController.instance.mediaSection, 'anime');
    });
  });

  group('HubController sections', () {
    test('Media hub exposes exactly five sections', () {
      expect(
        HubController.instance.currentSections.length,
        5,
        reason: 'Movies, Series, Anime, Live TV, Library',
      );
    });

    test('sections end with a Library section', () {
      expect(HubController.instance.currentSections.last.label, 'Library');
    });

    test('Movies and Series are both selectable top-level sections', () {
      HubController.instance.setMediaSection('movies');
      expect(HubController.instance.mediaSection, 'movies');
      HubController.instance.setMediaSection('series');
      expect(HubController.instance.mediaSection, 'series');
    });
  });
}
