// test/widgets/glass_back_button_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/app_spacing.dart';
import 'package:playtorriomov/widgets/common/glass_back_button.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('GlassBackButton', () {
    testWidgets('pops the route by default', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(body: GlassBackButton()),
                  ),
                ),
                child: const Text('push'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(GlassBackButton), findsNothing);
    });

    testWidgets('an explicit onPressed overrides the default pop',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        GlassBackButton(onPressed: () => taps++),
      ));
      await tester.tap(find.byType(GlassBackButton));
      expect(taps, 1);
    });

    testWidgets('renders the shared icon', (tester) async {
      await tester.pumpWidget(wrap(const GlassBackButton()));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  group('FloatingBackButton', () {
    testWidgets('clears the status bar on a device with a notch', (
      tester,
    ) async {
      // Regression test: Anime Details pinned its button at a flat top: 24,
      // which on a notched phone put it under the system clock.
      const inset = EdgeInsets.only(top: 59);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(padding: inset),
            child: Scaffold(
              body: Stack(children: [FloatingBackButton()]),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(GlassBackButton)).dy,
        greaterThanOrEqualTo(inset.top),
      );
    });

    testWidgets('sits at the shared page inset', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Stack(children: [FloatingBackButton()])),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(GlassBackButton)).dx,
        AppSpacing.pageInset(tester.element(find.byType(GlassBackButton))),
      );
    });
  });

  test('no details/search page hand-rolls its own back button', () {
    // Four pages each built their own frosted-circle or bare-icon back
    // button, split between `arrow_back_ios_rounded` and
    // `arrow_back_ios_new_rounded`, some circular and some not. This catches
    // the next one.
    //
    // The signal is a back arrow icon paired with a Navigator pop within a
    // short distance -- that combination is a navigation back button, unlike
    // a lone `arrow_back_ios_new_rounded` used as a horizontal-scroll arrow
    // (those call a scroll controller, never Navigator.pop).
    final backButton = RegExp(
      r'Icon\(\s*Icons\.arrow_back[\s\S]{0,200}?Navigator\.(of\(context\)\.)?pop',
    );
    final offenders = <String>[];
    for (final file in Directory('lib/pages')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Settings pages form their own already-consistent AppBar-leading
      // family; the player and IPTV portal browser use overlay controls in
      // a genuinely different visual context. Neither is part of the
      // details/search page family GlassBackButton unifies.
      if (file.path.contains('/settings/')) continue;
      if (file.path.contains('/player/')) continue;
      if (file.path.contains('iptv_player_page.dart')) continue;
      if (file.path.contains('iptv_portal_browser_page.dart')) continue;
      final source = file.readAsStringSync();
      if (backButton.hasMatch(source)) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'use GlassBackButton so the icon and styling stay in step');
  });
}
