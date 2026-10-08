import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../theme/app_theme_service.dart';

/// The language this viewer reads, for everything that is not the app's own
/// text: the synopsis, the audio and the subtitles.
///
/// A streaming app plays everything in the device's language, and this app
/// has to ask for it, because its sources and metadata are other people's.
/// The interface follows Settings -> Appearance -> Language, which defaults to
/// the device; this is the same rule for the rest.
///
/// **An explicit choice in Settings wins, then the device.** The two differ
/// when someone picks English for the interface on a Spanish phone, and then
/// the synopsis should be English too: one language, not an interface in one
/// and a description in another.
///
/// This is deliberately *not* `Localizations.localeOf(context)`. The app is
/// translated into four languages and falls back to English for the rest, so
/// asking the interface for the viewer's language gave a French viewer an
/// English description. TMDB has the French one.
abstract final class SystemLanguage {
  /// Replaces the device locale in tests.
  @visibleForTesting
  static Locale? debugDeviceLocale;

  /// The device's language as the lowercase ISO 639-1 code (`es`, `fr`).
  static String get deviceCode =>
      (debugDeviceLocale ?? PlatformDispatcher.instance.locale)
          .languageCode
          .toLowerCase();

  /// The viewer's language: the app locale when one was chosen, else the
  /// device's.
  static String get code =>
      AppThemeService.locale.value?.languageCode.toLowerCase() ?? deviceCode;
}
