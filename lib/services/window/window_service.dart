import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../playback_coordinator.dart';
import '../stream/torrent_stream_service.dart';

/// Centralized window and fullscreen state manager for desktop and mobile.
class WindowService with WindowListener {
  static final WindowService instance = WindowService._internal();
  WindowService._internal();

  final ValueNotifier<bool> isFullscreenNotifier = ValueNotifier<bool>(false);
  bool _isTransitioning = false;
  bool _isClosing = false;

  bool get isFullscreen => isFullscreenNotifier.value;
  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> initialize() async {
    if (!isDesktop) return;
    try {
      windowManager.addListener(this);
      final isFs = await windowManager.isFullScreen();
      isFullscreenNotifier.value = isFs;
      // Defers the actual close until we call destroy() below, instead of
      // the OS killing the process mid-teardown while LocalStreamProxy's
      // server (and other background services) are still live.
      await windowManager.setPreventClose(true);
    } catch (e) {
      debugPrint('[WindowService] initialize error: $e');
    }
  }

  void dispose() {
    if (isDesktop) {
      windowManager.removeListener(this);
    }
  }

  /// Executes true borderless OS fullscreen toggle covering the Windows taskbar.
  Future<void> toggleFullscreen() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      if (!isDesktop) {
        // Mobile fallback
        final next = !isFullscreenNotifier.value;
        isFullscreenNotifier.value = next;
        if (next) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        return;
      }

      final isCurrentlyFs = await windowManager.isFullScreen();
      if (isCurrentlyFs || isFullscreenNotifier.value) {
        await windowManager.setFullScreen(false);
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
        isFullscreenNotifier.value = false;
      } else {
        // Crucial for Windows: unmaximize first to drop the 8px DWM resize frame
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
        await windowManager.setFullScreen(true);
        isFullscreenNotifier.value = true;
      }
    } catch (e) {
      debugPrint('[WindowService] toggleFullscreen error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  /// Alias for toggleFullscreen
  Future<void> toggleFullScreen() => toggleFullscreen();

  /// Forces exit from fullscreen (e.g. when leaving player screen).
  Future<void> exitFullscreen() async {
    if (!isDesktop) {
      if (isFullscreenNotifier.value) {
        isFullscreenNotifier.value = false;
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      return;
    }
    if (_isTransitioning) return;
    _isTransitioning = true;
    try {
      final isCurrentlyFs = await windowManager.isFullScreen();
      if (isCurrentlyFs || isFullscreenNotifier.value) {
        await windowManager.setFullScreen(false);
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        }
        isFullscreenNotifier.value = false;
      }
    } catch (e) {
      debugPrint('[WindowService] exitFullscreen error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  // ── WindowListener Callbacks (Synchronize OS events) ──

  /// Graceful shutdown: stops background services holding live resources
  /// (the local stream proxy's HTTP server, the torrent engine) before
  /// actually closing the window, instead of letting the OS kill the
  /// process out from under them.
  @override
  void onWindowClose() {
    if (_isClosing) return;
    _isClosing = true;
    _shutdownAndClose();
  }

  Future<void> _shutdownAndClose() async {
    try {
      PlaybackCoordinator.stopActive();
      await TorrentStreamService().stop();
    } catch (e) {
      debugPrint('[WindowService] shutdown cleanup error: $e');
    } finally {
      // destroy() calls the native PostQuitMessage(0) directly, which tears
      // down the Win32 message loop before the engine's own plugins (video
      // decoder threads, WebView2, etc.) get their normal teardown --
      // reproducibly access-violates in flutter_windows.dll on close.
      // close() re-posts a real WM_CLOSE, which the engine's own WndProc
      // handles through its expected DestroyWindow/WM_DESTROY chain; the
      // resulting second onWindowClose() re-entry is a no-op via _isClosing.
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  @override
  void onWindowEnterFullScreen() {
    isFullscreenNotifier.value = true;
  }

  @override
  void onWindowLeaveFullScreen() {
    isFullscreenNotifier.value = false;
  }

  @override
  void onWindowRestore() {
    windowManager.isFullScreen().then((isFs) {
      isFullscreenNotifier.value = isFs;
    });
  }

  @override
  void onWindowUnmaximize() {
    windowManager.isFullScreen().then((isFs) {
      isFullscreenNotifier.value = isFs;
    });
  }

  @override
  void onWindowMaximize() {
    windowManager.isFullScreen().then((isFs) {
      isFullscreenNotifier.value = isFs;
    });
  }
}
