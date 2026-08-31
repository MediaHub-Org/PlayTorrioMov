import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_kit/media_kit.dart';

import 'package:window_manager/window_manager.dart';

import './services/addon/addon_manager.dart';
import './services/theme/app_theme_service.dart';
import './services/updater/app_updater_service.dart';
import './services/audiobook/audiobook_library_service.dart';
import './services/backup/cloud_backup_settings.dart';
import './services/download/download_service.dart';
import './services/books/continue_reading_service.dart';
import './services/books/reader_settings.dart';
import './services/continue_watching/continue_watching_service.dart';
import './services/theme/custom_background_service.dart';
import './services/theme/glass_settings.dart';
import './services/audiobook/audiobook_settings.dart';
import './services/iptv/iptv_controller.dart';
import './services/iptv/iptv_settings.dart';
import './services/manga/manga_settings.dart';
import './services/media_session/media_session_service.dart';
import './services/music/music_download_service.dart';
import './services/music/music_settings.dart';
import './services/music/qobuz_music_service.dart';
import './services/my_list/my_list_service.dart';
import './services/player/player_settings.dart';
import './services/tmdb/tmdb_settings.dart';
import './services/stream/torrent_stream_service.dart';
import './services/config/env_service.dart';
import './services/window/window_service.dart';
import './services/p2p/p2p_settings_service.dart';
import './services/discord/discord_rpc_service.dart';
import './widgets/updater/update_dialog.dart';
import './widgets/common/global_shortcuts.dart';
import './pages/hub/hub_page.dart';
import 'app_info.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await WindowService.instance.initialize();
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await EnvService.initialize();
  await PlayerSettings.initialize();
  await Future.wait([
    AddonManager.instance.initialize(),
    AudiobookLibraryService.instance.init(),
    AppThemeService.initialize(),
    AudiobookSettings.initialize(),
    CloudBackupSettings.initialize(),
    ContinueWatchingService.initialize(),
    ContinueReadingService.initialize(),
    ReaderSettings.initialize(),
    CustomBackgroundService.initialize(),
    GlassSettings.initialize(),
    IptvController.instance.init(),
    IptvSettings.initialize(),
    MangaSettings.initialize(),
    MusicSettings.initialize(),
    MusicDownloadService.instance.init(),
    QobuzMusicService.instance.initialize(),
    MyListService.initialize(),
    TmdbSettings.initialize(),
    P2pSettingsService.initialize(),
    DownloadService.instance.initialize(),
    TorrentStreamService().start(),
    // Publishes the active source to the Android/iOS media session. Awaited
    // with the rest so the session exists before anything can start playing,
    // but it never throws -- a missing session costs the notification
    // controls, not startup.
    MediaSessionService.init(),
    DiscordRpcService.instance.initialize(),
  ]);
  runApp(const PlayTorrioApp());
}

class PlayTorrioApp extends StatefulWidget {
  const PlayTorrioApp({super.key});

  @override
  State<PlayTorrioApp> createState() => _PlayTorrioAppState();
}

class _PlayTorrioAppState extends State<PlayTorrioApp>
    with WidgetsBindingObserver {
  static bool _hasCheckedInitialUpdate = false;
  static bool _isShowingUpdateDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedInitialUpdate) {
        _hasCheckedInitialUpdate = true;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _checkForUpdates();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (_isShowingUpdateDialog) return;
    if (!await AppUpdaterService.isAutoCheckEnabled()) return;
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdates();
      if (updateInfo == null) return;

      BuildContext? context = navigatorKey.currentContext;
      for (int i = 0; i < 6 && (context == null || !context.mounted); i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        context = navigatorKey.currentContext;
      }

      if (context != null && context.mounted && !_isShowingUpdateDialog) {
        _isShowingUpdateDialog = true;
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
        _isShowingUpdateDialog = false;
      }
    } catch (e) {
      _isShowingUpdateDialog = false;
      debugPrint('Error checking for app updates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,
          theme: AppThemeService.createThemeData(palette),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
          ),
          home: const GlobalShortcuts(child: HubPage()),
        );
      },
    );
  }
}

