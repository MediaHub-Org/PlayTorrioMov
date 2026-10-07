/// Simkl API constants.
library;

import 'simkl_settings.dart';

/// The client ID every Simkl request carries: the user's own if they set
/// one, else whatever `.env` gave this build, else empty.
///
/// Empty is the case that matters -- it is what every published build has,
/// and what made Connect fail with no explanation. Call sites should check
/// [SimklSettings.isConfigured] before starting an auth flow rather than
/// sending an empty id and reading the error.
///
/// There is deliberately no client *secret* here. Simkl's PIN flow
/// authenticates with the id alone, and the `kSimklClientSecret` this
/// replaced was never read by anything -- it only made the setup look like
/// it needed two values when it needs one.
String get kSimklClientId => SimklSettings.effectiveClientId ?? '';

const String kSimklApiBaseUrl = 'https://api.simkl.com';

const String kSimklAppName = 'debrify';
const String kSimklAppVersion = '1.0';

/// CDN host for the pre-built trending data files (public, no auth).
const String kSimklTrendingUrl =
    'https://data.simkl.in/discover/trending/today_100.json';

/// CDN calendar file (public, no auth): upcoming episode air dates for all TV shows.
const String kSimklCalendarTvUrl = 'https://data.simkl.in/calendar/tv.json';

/// RFC 8628 device authorization grant -- the flow every newly-registered
/// Simkl app now gets. The old `GET /oauth/pin` this replaced answers
/// `{"error":"unauthorized_client", "message":"This client_id is an OAuth
/// 2.0 app: use POST /oauth2/device instead"}` for any app Simkl created
/// today, verified against a real client ID rather than assumed from docs.
const String kSimklDeviceUrl = '$kSimklApiBaseUrl/oauth2/device';
const String kSimklTokenUrl = '$kSimklApiBaseUrl/oauth2/token';
