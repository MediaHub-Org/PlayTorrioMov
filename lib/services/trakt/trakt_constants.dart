/// Trakt API constants dynamically loaded from environment.
library;

import 'trakt_settings.dart';

/// The ID requests actually send: the user's own pasted credentials first,
/// the build's `.env` values second. Empty when neither exists, which is
/// what the Settings card reads to explain itself instead of failing.
String get kTraktClientId => TraktSettings.effectiveClientId ?? '';
String get kTraktClientSecret => TraktSettings.effectiveClientSecret ?? '';

const String kTraktApiBaseUrl = 'https://api.trakt.tv';
const String kTraktTokenUrl = '$kTraktApiBaseUrl/oauth/token';

const String kTraktDeviceCodeUrl = '$kTraktApiBaseUrl/oauth/device/code';
const String kTraktDeviceTokenUrl = '$kTraktApiBaseUrl/oauth/device/token';

const String kTraktApiVersion = '2';
