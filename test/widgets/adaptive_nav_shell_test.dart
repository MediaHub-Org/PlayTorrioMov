// test/widgets/adaptive_nav_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/utils/app_hub.dart';
import 'package:playtorrio/utils/hub_controller.dart';
import 'package:playtorrio/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorrio/widgets/common/top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    HubController.instance.setHub(AppHub.media);
    HubController.instance.setCurrentSection('watch');
  });

  group('AdaptiveNavShell', () {
    testWidgets('mobile bottom bar carries the four sections, not the hubs',
        (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsOneWidget);
      expect(find.byType(TopBar), findsNothing);

      // Watch's four sections.
      expect(find.text('Movies/Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);

      // Hubs moved to the header as icon-only pills, so no hub labels render.
      expect(find.text('Watch'), findsNothing);
      expect(find.text('Listen'), findsNothing);
      expect(find.text('Read'), findsNothing);
    });

    testWidgets('mobile header pills switch hub, and the bottom bar follows',
        (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      // Listen's icon pill, identified by the icon since the label is a tooltip.
      await tester.tap(find.byIcon(AppHub.music.navIcon));
      await tester.pumpAndSettle();

      expect(HubController.instance.currentHub, AppHub.music);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Podcasts'), findsOneWidget);
      expect(find.text('Movies/Series'), findsNothing);
    });

    testWidgets('mobile bottom bar tap switches section', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();

      expect(HubController.instance.mediaSection, 'anime');
    });

    testWidgets('tablet tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 700);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });

    testWidgets('desktop tier shows TopBar, not the bottom tab bar', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsNothing);
    });

    testWidgets('mobile top bar hides settings icon when onSettingsTap is null', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsNothing);
    });

    testWidgets('mobile top bar shows settings icon and calls onSettingsTap', (tester) async {
      setSurfaceWidth(tester, 400);
      var tapped = false;
      await tester.pumpWidget(wrap(AdaptiveNavShell(
        onSettingsTap: () => tapped = true,
        child: const SizedBox.shrink(),
      )));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump();
      expect(tapped, true);
    });

    testWidgets('renders the provided child', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: Text('hub content'))));
      await tester.pumpAndSettle();

      expect(find.text('hub content'), findsOneWidget);
    });
  });
}
