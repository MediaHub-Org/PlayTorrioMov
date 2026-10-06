import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/stream/stream_model.dart';

/// A data-usage tier, the way a streaming app's own settings usually frame
/// it rather than as a bare resolution: what it costs per hour matters more
/// to most people picking this than the pixel count does.
enum VideoQualityTier {
  /// Smallest files this app's sources are commonly found in -- 720p.
  good,

  /// 1080p: the common middle ground.
  better,

  /// 4K where a source has one, otherwise the highest available.
  best;

  /// [StreamSource.qualityRank] this tier aims for. Sources page cannot
  /// *change* what quality a release was encoded at -- there is no
  /// transcoding here, only a choice among whatever releases exist -- so
  /// this is a target to sort toward, not a ceiling that hides anything.
  int get targetQualityRank => switch (this) {
    good => 2, // 720p
    better => 3, // 1080p
    best => 4, // 4K
  };
}

/// How much video at roughly this tier's resolution costs per hour of
/// playback, as a rough guide a viewer on a data cap can plan around --
/// not a promise about any specific release, which can sit well above or
/// below it depending on its own bitrate and codec.
double gbPerHourFor(VideoQualityTier tier) => switch (tier) {
  VideoQualityTier.good => 0.38,
  VideoQualityTier.better => 1.40,
  VideoQualityTier.best => 6.84,
};

/// Orders [StreamSource]s by closeness to [tier]'s target rank, highest
/// quality first as the tiebreak among sources equally far from it.
///
/// A standalone comparator rather than an inline sort, so the one rule --
/// "closest to the tier, ties go to the higher one" -- has one place to be
/// tested without standing up `WatchScreen`'s whole scraping/loading
/// machinery. At [VideoQualityTier.best] this sorts identically to always
/// putting the highest quality first: distance from the top rank (4) is
/// already descending by rank, which is what every install saw before this
/// setting existed.
int Function(StreamSource, StreamSource) qualityDistanceComparator(
  VideoQualityTier tier,
) {
  final target = tier.targetQualityRank;
  return (a, b) {
    final da = (a.qualityRank - target).abs();
    final db = (b.qualityRank - target).abs();
    if (da != db) return da.compareTo(db);
    return b.qualityRank.compareTo(a.qualityRank);
  };
}

/// The global default for how the Sources list is *sorted* when a viewer
/// has not chosen a size sort or a quality filter of their own on this
/// title -- never a filter itself, and never hides a source. "Browsing
/// choices for this title stay on the sources screen" (see ROADMAP) is
/// about filters; this is the one thing that is a standing preference
/// instead, the same way a streaming app's own data-usage setting is.
abstract final class VideoQualityPreference {
  VideoQualityPreference._();

  static const _key = 'video_quality_preference_tier';

  /// Defaults to [VideoQualityTier.best] -- the sort this replaces always
  /// put the highest quality first, so an installed app that has not
  /// touched this setting keeps behaving exactly as it did before.
  static final ValueNotifier<VideoQualityTier> tier =
      ValueNotifier<VideoQualityTier>(VideoQualityTier.best);

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        tier.value = VideoQualityTier.values.firstWhere(
          (t) => t.name == saved,
          orElse: () => VideoQualityTier.best,
        );
      }
    } catch (e) {
      debugPrint('[VideoQualityPreference] Error initializing: $e');
    }
  }

  static Future<void> setTier(VideoQualityTier value) async {
    tier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (e) {
      debugPrint('[VideoQualityPreference] Error saving: $e');
    }
  }
}
