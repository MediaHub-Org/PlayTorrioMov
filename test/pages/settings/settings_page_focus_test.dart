import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/pages/settings/settings_page.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';

/// The Settings overview hands its first tile the focus on a TV only: a
/// remote has no pointer, so without a starting point the first D-pad press
/// lands somewhere arbitrary, while a phone or desktop viewer never asked for
/// a selected tile.
void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(),
    ));
    // A few frames, not a settle: the page kicks off async state loads whose
    // timers would otherwise outlive the test.
    await tester.pump();
    await tester.pump();
  }

  /// Whether any tile's InkWell holds the primary focus.
  bool anyTileFocused(WidgetTester tester) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return find
        .ancestor(
          of: find.byElementPredicate((e) => e == focused),
          matching: find.byType(InkWell),
        )
        .evaluate()
        .isNotEmpty;
  }

  tearDown(() => TvModeService.isTv.value = false);

  testWidgets('on a TV a tile holds focus on open', (tester) async {
    TvModeService.isTv.value = true;
    await pumpSettings(tester);

    expect(anyTileFocused(tester), isTrue);
  });

  testWidgets('off a TV nothing is focused on open', (tester) async {
    TvModeService.isTv.value = false;
    await pumpSettings(tester);

    expect(anyTileFocused(tester), isFalse);
  });
}
