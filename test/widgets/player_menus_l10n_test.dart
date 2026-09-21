// test/widgets/player_menus_l10n_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/player/sleep_timer_service.dart';
import 'package:playtorriomov/widgets/player/player_speed_menu.dart';
import 'package:playtorriomov/widgets/player/player_top_bar.dart';
import 'package:playtorriomov/widgets/player/sleep_timer_menu.dart';

Widget inLocale(String code, Widget child) => MaterialApp(
      locale: Locale(code),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  tearDown(() => SleepTimerService.instance.cancel());

  testWidgets('the sleep timer menu follows the app language', (tester) async {
    await tester.pumpWidget(inLocale('es', const SleepTimerMenu()));

    expect(find.text('TEMPORIZADOR DE APAGADO'), findsOneWidget);
    expect(find.text('Personalizado'), findsOneWidget);
    expect(find.textContaining('se pausa a las'), findsWidgets);
    expect(find.textContaining('pauses at'), findsNothing);
  });

  testWidgets('the speed menu follows the app language, and fits a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Spanish and Portuguese titles are the longest of the four.
    for (final code in ['es', 'pt', 'ar']) {
      await tester.pumpWidget(inLocale(
        code,
        PlayerSpeedMenu(currentRate: 1.0, onRateSelected: (_) {}, onClose: () {}),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: code);
    }
    expect(find.textContaining('PLAYBACK'), findsNothing);
  });

  testWidgets('the top bar tooltips follow the app language', (tester) async {
    await tester.pumpWidget(inLocale(
      'pt',
      PlayerTopBar(
        title: 'A Film',
        onBack: () {},
        onCopyStreamUrl: () {},
        onDownload: () {},
        onCast: () {},
      ),
    ));

    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.byTooltip('Baixar'), findsOneWidget);
    expect(find.byTooltip('Copiar URL da transmissão'), findsOneWidget);
    expect(find.byTooltip('Transmitir'), findsOneWidget);
  });
}
