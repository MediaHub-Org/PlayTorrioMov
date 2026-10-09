// The app has had a debrid setting for a long time, unconfigured and
// unmentioned. The card says once, plainly, why it matters for torrents, and
// goes away: it never pushes a purchase, it remembers "Not now", and it is
// gone once debrid is on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/widgets/sources/debrid_hint_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app({required Future<void> Function() onSetUp}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: DebridHintCard(onSetUp: onSetUp))),
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('shows for a viewer with no debrid', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);

    expect(find.text('Torrents depend on seeders'), findsOneWidget);
    expect(find.text('Set up debrid'), findsOneWidget);
  });

  testWidgets('"Not now" hides it for good', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);

    await tester.tap(find.text('Not now'));
    await settle(tester);
    expect(find.text('Torrents depend on seeders'), findsNothing);

    // A new screen, the same viewer.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);
    expect(find.text('Torrents depend on seeders'), findsNothing);
  });

  testWidgets('already dismissed never shows', (tester) async {
    SharedPreferences.setMockInitialValues({
      DebridHintCard.dismissedKey: true,
    });
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);

    expect(find.text('Torrents depend on seeders'), findsNothing);
  });

  testWidgets('is gone once debrid is on for streams', (tester) async {
    SharedPreferences.setMockInitialValues({
      'debrid_service': 'TorBox',
      'torbox_api_key': 'KEY',
      'use_debrid_for_streams': true,
    });
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);

    expect(find.text('Torrents depend on seeders'), findsNothing);
  });

  testWidgets('a service with a key but the stream switch off still shows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'debrid_service': 'TorBox',
      'torbox_api_key': 'KEY',
    });
    await tester.pumpWidget(app(onSetUp: () async {}));
    await settle(tester);

    expect(find.text('Torrents depend on seeders'), findsOneWidget);
  });

  testWidgets('"Set up" opens the settings and re-checks on the way back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var opened = 0;
    await tester.pumpWidget(app(onSetUp: () async {
      opened++;
      // The viewer turns debrid on while in settings.
      SharedPreferences.setMockInitialValues({
        'debrid_service': 'TorBox',
        'torbox_api_key': 'KEY',
        'use_debrid_for_streams': true,
      });
    }));
    await settle(tester);

    await tester.tap(find.text('Set up debrid'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(opened, 1);
    expect(find.text('Torrents depend on seeders'), findsNothing,
        reason: 'it should not be waiting there once debrid is on');
  });
}
