// The synopsis, the audio and the subtitles follow one language. With the
// interface left on the device default, the app asked for "no locale" and so
// fell through to English: a Spanish phone read an English description.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/locale/system_language.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';

void main() {
  tearDown(() {
    SystemLanguage.debugDeviceLocale = null;
    AppThemeService.locale.value = null;
  });

  test('follows the device when the app language was left on default', () {
    SystemLanguage.debugDeviceLocale = const Locale('es', 'MX');
    AppThemeService.locale.value = null;

    expect(SystemLanguage.code, 'es');
  });

  test('an explicit app language wins over the device', () {
    SystemLanguage.debugDeviceLocale = const Locale('es');
    AppThemeService.locale.value = const Locale('pt');

    expect(SystemLanguage.code, 'pt');
  });

  test('is always lowercase', () {
    SystemLanguage.debugDeviceLocale = const Locale('FR');

    expect(SystemLanguage.deviceCode, 'fr');
  });
}
