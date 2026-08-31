// test/widgets/section_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/utils/app_hub.dart';
import 'package:playtorrio/utils/hub_controller.dart';
import 'package:playtorrio/widgets/common/section_top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    // HubController is a singleton, so reset both axes between tests.
    HubController.instance.setHub(AppHub.media);
    HubController.instance.setCurrentSection('watch');
  });

  group('SectionTopBar', () {
    testWidgets('renders nothing on mobile — the bottom bar owns sections there',
        (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.text('Movies/Series'), findsNothing);
      expect(find.text('Anime'), findsNothing);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets('desktop shows every section as a chip', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      expect(find.text('Movies/Series'), findsOneWidget);
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

    testWidgets('chips follow the active hub', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const SectionTopBar()));
      await tester.pumpAndSettle();

      HubController.instance.setHub(AppHub.music);
      await tester.pumpAndSettle();

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Podcasts'), findsOneWidget);
      expect(find.text('Movies/Series'), findsNothing);
    });
  });

  group('HubController sections', () {
    test('every hub exposes exactly four sections', () {
      for (final hub in AppHub.values) {
        HubController.instance.setHub(hub);
        expect(
          HubController.instance.currentSections.length,
          4,
          reason: '${hub.navLabel} must have four sections so the mobile '
              'bottom bar divides evenly',
        );
      }
    });

    test('each hub ends with a Library section', () {
      for (final hub in AppHub.values) {
        HubController.instance.setHub(hub);
        expect(HubController.instance.currentSections.last.label, 'Library');
      }
    });

    test('merged sections keep their two sides selectable', () {
      HubController.instance.setHub(AppHub.media);
      expect(HubController.instance.watchType, 'movie');
      HubController.instance.setWatchType('series');
      expect(HubController.instance.watchType, 'series');

      HubController.instance.setHub(AppHub.books);
      HubController.instance.setReadableType('comics');
      expect(HubController.instance.readableType, 'comics');
    });
  });
}
