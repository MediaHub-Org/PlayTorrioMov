import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_kit/media_kit.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:window_manager/window_manager.dart';

import './services/addon/addon_manager.dart';
import './services/cast/cast_service.dart';
import './services/theme/app_theme_service.dart';
import './services/updater/app_updater_service.dart';
import './services/backup/cloud_backup_settings.dart';
import './services/download/download_service.dart';
import './services/continue_watching/continue_watching_service.dart';
import './services/iptv/favorite_channels_service.dart';
import './services/iptv/iptv_controller.dart';
import './services/iptv/iptv_settings.dart';
import './services/media_session/media_session_service.dart';
import './services/my_list/my_list_service.dart';
import './services/player/player_settings.dart';
import './services/tmdb/tmdb_settings.dart';
import './services/stream/torrent_stream_service.dart';
import './services/config/env_service.dart';
import './services/window/window_service.dart';
import './services/p2p/p2p_settings_service.dart';
import './services/scraper/builtin_providers_service.dart';
import './services/discord/discord_rpc_service.dart';
import './widgets/updater/update_dialog.dart';
import './pages/hub/hub_page.dart';
import 'app_info.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// A [PathProviderLinux] pinned to the app's original, stable id, independent
/// of whatever the running GApplication's "application-id" property is set
/// to. The public [PathProviderLinux] constructor takes no arguments -- only
/// the `@visibleForTesting` `.private` constructor accepts an explicit
/// [applicationId] -- but using it here is the only way to keep the on-disk
/// data directory from moving if that property ever changes again.
PathProviderLinux _pinnedLinuxPathProvider() {
  // ignore: invalid_use_of_visible_for_testing_member
  return PathProviderLinux.private(
    environment: Platform.environment,
    applicationId: 'com.mediahub.playtorriomov',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    // path_provider_linux (and shared_preferences, which stores its JSON
    // file under the same directory) picks its data directory from the
    // running GApplication's "application-id" property, not from
    // g_set_prgname -- confirmed by reading its FFI source
    // (get_application_id_real.dart calls g_application_get_application_id).
    // my_application.cc intentionally sets that property to the Flatpak's
    // app-id (io.github.MediaHubOrg.PlayTorrioMov) so the desktop/compositor
    // can associate the running window with the installed .desktop file for
    // taskbar icon/pinning -- but that silently forked every existing
    // install's on-disk library into a brand-new, empty directory the
    // moment that change shipped. Pin path_provider back to the original,
    // stable id so the taskbar fix can't move user data again.
    PathProviderPlatform.instance = _pinnedLinuxPathProvider();
    // shared_preferences_linux doesn't read PathProviderPlatform.instance --
    // it builds its own private PathProviderLinux() internally, so it needs
    // the same pin applied directly or its JSON store forks right along
    // with everything else path_provider touches.
    SharedPreferencesStorePlatform.instance = SharedPreferencesLinux()
      // ignore: invalid_use_of_visible_for_testing_member
      ..pathProvider = _pinnedLinuxPathProvider();
    SharedPreferencesAsyncPlatform.instance = SharedPreferencesAsyncLinux()
      // ignore: invalid_use_of_visible_for_testing_member
      ..pathProvider = _pinnedLinuxPathProvider();
  }
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
    AppThemeService.initialize(),
    CastService.initialize(),
    CloudBackupSettings.initialize(),
    ContinueWatchingService.initialize(),
    FavoriteChannelsService.initialize(),
    IptvController.instance.init(),
    IptvSettings.initialize(),
    MyListService.initialize(),
    TmdbSettings.initialize(),
    P2pSettingsService.initialize(),
    // Loads which built-in scrapers the user switched off. Must land before
    // the first scrapeAll, which reads the result synchronously.
    BuiltinProvidersService.initialize(),
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
          home: const HubPage(),
        );
      },
    );
  }
}

