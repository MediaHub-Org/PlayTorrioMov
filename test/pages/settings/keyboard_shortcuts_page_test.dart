// test/pages/settings/keyboard_shortcuts_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/pages/settings/keyboard_shortcuts_page.dart';

/// Pumps the page with the real delegates, so the assertions below are about
/// the translated strings rather than the no-delegate English fallback.
Future<void> pumpPage(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const KeyboardShortcutsPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('KeyboardShortcutsPage', () {
    testWidgets('renders every shortcut row', (tester) async {
      await pumpPage(tester);

      // Twelve rows, one per entry in the page's list. The count is asserted
      // rather than the individual labels because the labels are the thing
      // under test below.
      expect(find.byType(Row), findsNWidgets(12));
    });

    testWidgets('translates the action column but not the key column', (tester) async {
      await pumpPage(tester, locale: const Locale('es'));

      // The action is translated...
      expect(find.text('Reproducir / Pausar'), findsOneWidget);
      expect(find.text('Play / Pause'), findsNothing);

      // ...while the physical key is not. A translated key name would name a
      // key that is not on the keyboard.
      expect(find.text('Space / K'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
    });

    testWidgets('translates the app bar title', (tester) async {
      await pumpPage(tester, locale: const Locale('es'));

      expect(find.text('Atajos de teclado'), findsOneWidget);
    });
  });
}
