import '../../models/stream/stream_model.dart';
import '../player/video_quality_preference.dart';

/// Orders [sources] best first for this viewer and this connection.
///
/// A list in arrival order, with the heaviest release first, is a list that
/// opens on whatever answered quickest. A streaming app opens on what will
/// play: in the viewer's language, at a size the connection carries. The keys,
/// most important first:
///
/// 1. **Language.** [preferredAudio] is the viewer's own list, or their device
///    language (see `SourceFilterSettings.effectiveAudioRank`). A release that
///    names a preferred language comes before one tagged MULTI -- which
///    plausibly carries it, but does not say -- and that before the rest. It
///    orders; it never hides.
/// 2. **Already on the debrid service.** [cachedHashes] is the set the viewer's
///    provider listed as cached (null when debrid is not in use). A cached
///    release starts in a second or two and does not depend on its swarm, so
///    among releases the viewer would accept in their language it leads. It sits
///    *after* language on purpose: a Spanish release that has to be fetched
///    first is still the Spanish release.
/// 3. **Weight.** A release whose bitrate is known to be above [maxKbps] goes
///    behind the ones that fit. Unknown bitrates are not penalized: the title
///    often just does not say.
/// 4. **Quality tier**, closest to the viewer's setting, higher quality
///    winning a tie (see [qualityDistanceComparator]).
/// 5. **Seeders**, more first. Torrents with a hundred seeds start sooner and
///    stall less than the same release with three.
/// 6. Arrival order, so equal sources do not shuffle between rebuilds.
List<StreamSource> rankSources(
  List<StreamSource> sources, {
  required VideoQualityTier tier,
  List<String> preferredAudio = const [],
  String? mediaTitle,
  int? maxKbps,
  int? runtimeMinutes,
  Set<String>? cachedHashes,
}) {
  final tierOrder = qualityDistanceComparator(tier);

  int audioScore(StreamSource s) {
    if (preferredAudio.isEmpty) return 0;
    final languages = s.getAudioLanguages(mediaTitle: mediaTitle);
    for (var i = 0; i < preferredAudio.length; i++) {
      if (languages.contains(preferredAudio[i])) return i;
    }
    return languages.contains('multi')
        ? preferredAudio.length
        : preferredAudio.length + 1;
  }

  int cachedScore(StreamSource s) {
    if (cachedHashes == null || cachedHashes.isEmpty) return 0;
    final hash = s.infoHash?.toLowerCase();
    return hash != null && cachedHashes.contains(hash) ? 0 : 1;
  }

  int weightScore(StreamSource s) {
    if (maxKbps == null) return 0;
    final kbps = s.estimatedBitrateKbps(runtimeMinutes);
    return kbps != null && kbps > maxKbps ? 1 : 0;
  }

  // Decorated once: the scores parse titles, and a comparator that parsed on
  // every comparison would do it n log n times.
  final entries = <_Ranked>[
    for (var i = 0; i < sources.length; i++)
      _Ranked(
        sources[i],
        i,
        audioScore(sources[i]),
        cachedScore(sources[i]),
        weightScore(sources[i]),
      ),
  ];

  entries.sort((a, b) {
    if (a.audio != b.audio) return a.audio.compareTo(b.audio);
    if (a.cached != b.cached) return a.cached.compareTo(b.cached);
    if (a.weight != b.weight) return a.weight.compareTo(b.weight);
    final byTier = tierOrder(a.source, b.source);
    if (byTier != 0) return byTier;
    final seedsA = a.source.seeders ?? -1;
    final seedsB = b.source.seeders ?? -1;
    if (seedsA != seedsB) return seedsB.compareTo(seedsA);
    // Dart's sort is not stable; the index makes it so.
    return a.index.compareTo(b.index);
  });

  return [for (final e in entries) e.source];
}

class _Ranked {
  final StreamSource source;
  final int index;
  final int audio;
  final int cached;
  final int weight;

  const _Ranked(this.source, this.index, this.audio, this.cached, this.weight);
}
