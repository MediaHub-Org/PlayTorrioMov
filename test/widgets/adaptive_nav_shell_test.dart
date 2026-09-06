// test/widgets/adaptive_nav_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/utils/hub_controller.dart';
import 'package:playtorriomov/widgets/common/adaptive_nav_shell.dart';
import 'package:playtorriomov/widgets/common/nested_navigator.dart';
import 'package:playtorriomov/widgets/common/top_bar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void setSurfaceWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    HubController.instance.setMediaSection('movies');
  });

  group('AdaptiveNavShell', () {
    testWidgets('mobile bottom bar carries the five sections', (tester) async {
      setSurfaceWidth(tester, 400);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: SizedBox.shrink())));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adaptiveNavMobileBar')), findsOneWidget);
      // Mobile uses the exact same TopBar as tablet/desktop now -- one
      // definition, not a second copy that could drift the Settings icon's
      // position out of sync (see the dedicated position test below).
      expect(find.byType(TopBar), findsOneWidget);

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
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

    testWidgets(
        'Settings icon sits at the same distance from the top-right corner on every tier',
        (tester) async {
      // Regression test for the icon drifting between tiers: same window
      // width for the "top" measurement is irrelevant since both tiers
      // right-align, so this checks the icon's offset from its own bar's
      // top-right corner, which must be identical everywhere since TopBar
      // is now one shared definition.
      Future<Offset> settingsOffsetFromTopRight(double width) async {
        setSurfaceWidth(tester, width);
        await tester.pumpWidget(wrap(AdaptiveNavShell(
          onSettingsTap: () {},
          child: const SizedBox.shrink(),
        )));
        await tester.pumpAndSettle();

        final iconTopLeft = tester.getTopLeft(find.byIcon(Icons.settings_rounded));
        final iconSize = tester.getSize(find.byIcon(Icons.settings_rounded));
        final barTopRight = tester.getTopRight(find.byType(TopBar));
        return Offset(
          barTopRight.dx - (iconTopLeft.dx + iconSize.width),
          iconTopLeft.dy,
        );
      }

      final mobileOffset = await settingsOffsetFromTopRight(400);
      final tabletOffset = await settingsOffsetFromTopRight(700);
      final desktopOffset = await settingsOffsetFromTopRight(1200);

      expect(mobileOffset, tabletOffset);
      expect(mobileOffset, desktopOffset);
    });

    testWidgets('renders the provided child', (tester) async {
      setSurfaceWidth(tester, 1200);
      await tester.pumpWidget(wrap(const AdaptiveNavShell(child: Text('hub content'))));
      await tester.pumpAndSettle();

      expect(find.text('hub content'), findsOneWidget);
    });

    testWidgets(
        'the 5-section bar survives a page pushed through the nested navigator on desktop',
        (tester) async {
      // Regression test: SectionTopBar used to live inside the hub content
      // that NestedNavigator wraps, so pushing a page there (Details,
      // Search, ...) covered the whole content area including the bar.
      // It now lives in AdaptiveNavShell, outside NestedNavigator's scope.
      setSurfaceWidth(tester, 1200);
      late BuildContext hubContentContext;
      await tester.pumpWidget(wrap(AdaptiveNavShell(
        child: NestedNavigator(
          child: Builder(
            builder: (context) {
              hubContentContext = context;
              return const Text('hub content');
            },
          ),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('hub content'), findsOneWidget);

      Navigator.of(hubContentContext).push(MaterialPageRoute<void>(
        builder: (_) => const Text('pushed details page'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('pushed details page'), findsOneWidget);
      expect(find.text('hub content'), findsNothing);
      expect(find.text('Movies'), findsOneWidget,
          reason: 'the 5-section bar must stay visible above pushed pages');
    });
  });
}
