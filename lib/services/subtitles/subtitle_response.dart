// lib/services/subtitles/subtitle_response.dart
import 'dart:convert';

/// The `{"subtitles": [...]}` body that OpenSubtitles and every Stremio
/// subtitle addon answer with.
///
/// This is a *format*, not a website: the Stremio addon protocol defines it,
/// and an addon written by a stranger is expected to honour it. That makes it
/// worth testing offline in a way a scraped HTML page is not — a fixture here
/// pins the contract rather than one day's markup.
///
/// Everything above this line is network and belongs to the provider; this
/// only reads bytes that have already arrived.
abstract final class StremioSubtitlesBody {
  /// The usable entries in [body], or an empty list if there are none.
  ///
  /// Never throws. Every reason a body can be unusable — not JSON at all (a
  /// captive portal's login page, an addon returning an HTML error), a root
  /// that is not an object, a missing or wrongly-typed `subtitles` key — is
  /// the same answer to the caller: this endpoint gave us nothing, try the
  /// next one. Entries that are not objects, or that carry no `url`, are
  /// dropped for the same reason: there is nothing to download.
  static List<Map<String, dynamic>> entries(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      // Not JSON. An addon that is down often answers with an HTML error page.
      return const [];
    }
    if (decoded is! Map) return const [];

    final list = decoded['subtitles'];
    if (list is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) continue;
      out.add(map);
    }
    return out;
  }
}
