import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/music/music_track.dart';
import 'convertytmp3_client.dart';
import 'youtube_audio_extractor.dart';
import 'youtube_rate_limit_guard.dart';

class YoutubeStreamResolver {
  static final YoutubeStreamResolver instance = YoutubeStreamResolver._internal();
  YoutubeStreamResolver._internal();

  final Map<String, String> _cache = <String, String>{}; // trackId -> videoId
  final Map<String, ({String url, String userAgent})> _streamCache = {};

  Future<({String url, String? userAgent})?> resolveUrl(
    MusicTrack track, {
    bool verifyStream = false,
  }) async {
    YoutubeRateLimitGuard.throwIfLimited();

    // 1. Check in-memory stream cache
    if (_streamCache.containsKey(track.id)) {
      final cached = _streamCache[track.id]!;
      return (url: cached.url, userAgent: cached.userAgent);
    }

    // 2. If track has a cached videoId, try resolving that directly
    final cachedVid = _cache[track.id];
    if (cachedVid != null) {
      try {
        final res = await YoutubeAudioExtractor.instance.getAudioUrl(
          cachedVid,
          verifyStream: verifyStream,
        ).timeout(const Duration(seconds: 8), onTimeout: () => null);
        if (res != null) {
          _streamCache[track.id] = res;
          return (url: res.url, userAgent: res.userAgent);
        }
      } catch (_) {
        _cache.remove(track.id);
      }
    }

    // 3. Fast extraction via YoutubeAudioExtractor (InnerTube)
    try {
      final res = await YoutubeRateLimitGuard.runLowRequest(
        () => YoutubeAudioExtractor.instance.extract(
          track.title,
          track.artist,
          targetDuration: track.durationSeconds > 0
              ? Duration(seconds: track.durationSeconds)
              : null,
          verifyStream: verifyStream,
        ).timeout(const Duration(seconds: 12), onTimeout: () => null),
      );

      if (res != null) {
        _cache[track.id] = res.videoId;
        _streamCache[track.id] = (url: res.audioUrl, userAgent: res.userAgent);
        return (url: res.audioUrl, userAgent: res.userAgent);
      }
    } catch (e) {
      debugPrint('YoutubeAudioExtractor error for ${track.title}: $e');
    }

    // 4. Convertytmp3 fallback
    final vidId = _cache[track.id];
    if (vidId != null) {
      try {
        final streamUrl = await Convertytmp3Client.getStreamUrl(vidId);
        if (streamUrl != null && streamUrl.isNotEmpty) {
          return (
            url: streamUrl,
            userAgent:
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
          );
        }
      } catch (e) {
        debugPrint('Convertytmp3 fallback error: $e');
      }
    }

    // 5. Deezer preview fallback if available
    if (track.previewUrl != null && track.previewUrl!.isNotEmpty) {
      debugPrint('Falling back to Deezer preview for ${track.title}');
      return (
        url: track.previewUrl!,
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      );
    }

    return null;
  }
}
