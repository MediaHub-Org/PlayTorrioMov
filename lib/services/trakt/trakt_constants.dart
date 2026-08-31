/// Trakt API constants dynamically loaded from environment.
library;

import '../config/env_service.dart';

String get kTraktClientId => EnvService.traktClientId;
String get kTraktClientSecret => EnvService.traktClientSecret;

const String kTraktApiBaseUrl = 'https://api.trakt.tv';
const String kTraktTokenUrl = '$kTraktApiBaseUrl/oauth/token';

const String kTraktDeviceCodeUrl = '$kTraktApiBaseUrl/oauth/device/code';
const String kTraktDeviceTokenUrl = '$kTraktApiBaseUrl/oauth/device/token';

const String kTraktApiVersion = '2';
