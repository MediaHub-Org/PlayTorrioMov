// test/widgets/player_menus_l10n_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations.dart';
import 'package:playtorriomov/services/player/sleep_timer_service.dart';
import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/widgets/common/error_view.dart';
import 'package:playtorriomov/widgets/player/player_aspect_menu.dart';
import 'package:playtorriomov/widgets/player/player_center_controls.dart';
import 'package:playtorriomov/widgets/player/player_episodes_panel.dart';
import 'package:playtorriomov/widgets/player/player_audio_menu.dart';
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

  testWidgets('the aspect ratio menu follows the app language', (tester) async {
    await tester.pumpWidget(inLocale(
      'es',
      PlayerAspectMenu(
        currentFit: BoxFit.contain,
        onFitSelected: (_) {},
        onRatioSelected: (_) {},
        onClose: () {},
      ),
    ));

    expect(find.text('RELACIÓN DE ASPECTO'), findsOneWidget);
    expect(find.text('Original (mantiene la forma de la fuente)'), findsOneWidget);
    expect(find.text('Forzar 16:9 (panorámico)'), findsOneWidget);
    expect(find.textContaining('Force'), findsNothing);
  });

  testWidgets('the audio menu follows the app language', (tester) async {
    await tester.pumpWidget(inLocale(
      'pt',
      PlayerAudioMenu(
        audioTracks: const [],
        selectedIndex: 0,
        delaySec: 0,
        onTrackSelected: (_) {},
        onDelayChanged: (_) {},
      ),
    ));

    expect(find.text('Reproduzindo o áudio padrão.'), findsOneWidget);
    expect(find.text('Deslocamento do áudio'), findsOneWidget);
  });

  testWidgets('the episodes panel follows the app language, and fits a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final videos = [
      for (var e = 1; e <= 3; e++)
        Video(id: 'tt1:1:$e', title: '', season: 1, episode: e),
    ];
    await tester.pumpWidget(inLocale(
      'es',
      PlayerEpisodesPanel(
        videos: videos,
        onEpisodeSelected: (_) {},
        onClose: () {},
      ),
    ));
    // The panel schedules an auto-scroll to the current episode; let it run,
    // so no Timer is left pending at teardown.
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Temporada 1 • 3 episodios'), findsOneWidget);
    expect(find.text('Episodio 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the center controls tooltips follow the app language',
      (tester) async {
    await tester.pumpWidget(inLocale(
      'pt',
      PlayerCenterControls(
        isPlaying: true,
        onPlayPause: () {},
        onSeekBack30: () {},
        onSeekForward30: () {},
      ),
    ));

    expect(find.byTooltip('Voltar 30 segundos'), findsOneWidget);
    expect(find.byTooltip('Avançar 30 segundos'), findsOneWidget);
  });

  testWidgets('the shared error view follows the app language', (tester) async {
    await tester.pumpWidget(inLocale(
      'es',
      ErrorView(title: 'x', error: null, onRetry: () {}),
    ));

    expect(find.text('Error desconocido'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
