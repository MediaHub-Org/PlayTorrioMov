import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-provider on/off for the app's built-in scrapers.
///
/// Upstream PlayTorrioV3 ships this as a hardcoded roster of 46 provider
/// names. That list cannot be copied here: Mov's scrapers were ported at
/// different times and its registered set does not match V3's, so a
/// hardcoded copy would show providers the app does not have and hide ones
/// it does. Instead the settings page enumerates
/// `ScraperManager.instance.scrapers` -- the scrapers actually registered --
/// and this service only stores the *exceptions*: which of them the user
/// turned off, keyed by [StreamScraper.id].
///
/// Storing exceptions rather than the full roster is what makes it safe to
/// add or remove a scraper: an unknown id is simply enabled, so a newly
/// ported scraper is live the moment it is registered without a migration,
/// and an id left behind by a scraper that was deleted is inert.
class BuiltinProvidersService {
  BuiltinProvidersService._();

  static const String _kDisabledKey = 'playtorrio_builtin_providers_disabled';

  /// Ids the user has switched off. Read on the hot path in
  /// `ScraperManager.scrapeAll`, so it is kept in memory rather than behind
  /// an await.
  static Set<String> _disabled = <String>{};

  /// Bumped on every change so widgets can rebuild off a single listenable
  /// without this service having to know about them.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Loads the saved exceptions. Safe to call before any scraper has been
  /// registered -- it stores ids, not scrapers.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _disabled = (prefs.getStringList(_kDisabledKey) ?? const <String>[]).toSet();
      revision.value++;
    } catch (e) {
      debugPrint('[BuiltinProvidersService] Error initializing: $e');
    }
  }

  /// Whether a provider should be scraped. Unknown ids are enabled, so a
  /// scraper added after these preferences were written is on by default.
  static bool isEnabled(String id) => !_disabled.contains(id);

  /// How many of [ids] are switched off, for the settings badge.
  static int disabledCountAmong(Iterable<String> ids) =>
      ids.where(_disabled.contains).length;

  static Future<void> setEnabled(String id, bool enabled) async {
    if (enabled) {
      _disabled.remove(id);
    } else {
      _disabled.add(id);
    }
    revision.value++;
    await _persist();
  }

  /// Turns every provider in [ids] on. Only clears the ids passed in, so a
  /// provider that is off but not currently on screen stays off.
  static Future<void> enableAll(Iterable<String> ids) async {
    _disabled.removeAll(ids);
    revision.value++;
    await _persist();
  }

  static Future<void> disableAll(Iterable<String> ids) async {
    _disabled.addAll(ids);
    revision.value++;
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kDisabledKey, _disabled.toList()..sort());
    } catch (e) {
      debugPrint('[BuiltinProvidersService] Error saving: $e');
    }
  }

  /// Test seam: drops in-memory state without touching disk.
  @visibleForTesting
  static void resetForTest() {
    _disabled = <String>{};
    revision.value = 0;
  }
}
