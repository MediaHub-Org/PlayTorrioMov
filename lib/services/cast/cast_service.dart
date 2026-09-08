import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

/// Google Cast integration -- Android/iOS only, since no desktop Cast SDK
/// exists. Every call site MUST check [isSupported] first: the underlying
/// package's `GoogleCastContext`/`GoogleCastDiscoveryManager`/etc. pick a
/// platform channel implementation the moment they're first referenced
/// (`Platform.isAndroid ? AndroidImpl() : IOSImpl()`), so merely touching
/// one on desktop would instantiate the iOS method channel there.
abstract final class CastService {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _initialized = false;

  /// Call once at startup, after [isSupported] is confirmed. Never throws --
  /// a Cast SDK failure (e.g. no Google Play Services on the device) should
  /// cost the Cast button, not app startup.
  static Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      final options = Platform.isIOS
          ? IOSGoogleCastOptions(
              GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(
                appId,
              ),
              stopCastingOnAppTerminated: true,
            )
          : GoogleCastOptionsAndroid(
              appId: appId,
              stopCastingOnAppTerminated: true,
            );
      GoogleCastContext.instance.setSharedInstanceWithOptions(options);
      _initialized = true;
    } catch (e) {
      debugPrint('[CastService] initialize error: $e');
    }
  }

  static Stream<List<GoogleCastDevice>> get devicesStream =>
      GoogleCastDiscoveryManager.instance.devicesStream;

  static Stream<GoogleCastSession?> get sessionStream =>
      GoogleCastSessionManager.instance.currentSessionStream;

  static bool get isConnected =>
      GoogleCastSessionManager.instance.connectionState ==
      GoogleCastConnectState.connected;

  static Future<void> connect(GoogleCastDevice device) =>
      GoogleCastSessionManager.instance.startSessionWithDevice(device);

  static Future<void> disconnect() =>
      GoogleCastSessionManager.instance.endSessionAndStopCasting();

  /// Best-effort guess from the URL -- the Cast receiver needs a content
  /// type to pick a demuxer. Most sources here are progressive MP4; HLS/DASH
  /// playlists are the only common exceptions worth detecting explicitly.
  static String _contentTypeFor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'application/x-mpegurl';
    if (lower.contains('.mpd')) return 'application/dash+xml';
    if (lower.contains('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  /// Loads [url] onto the connected receiver. Note: the Cast SDK has no
  /// sender-side way to attach custom HTTP headers (Referer/User-Agent) to
  /// the request the receiver makes for the media -- a scraper source that
  /// requires them (many do) will fail to play on the TV even though it
  /// plays fine locally, where this app's own player sends those headers
  /// itself. Direct/CDN sources are the ones most likely to work.
  static Future<void> loadMedia({
    required String url,
    required String title,
    String? posterUrl,
  }) {
    final mediaInfo = GoogleCastMediaInformation(
      contentId: url,
      streamType: CastMediaStreamType.buffered,
      contentUrl: Uri.parse(url),
      contentType: _contentTypeFor(url),
      metadata: GoogleCastMovieMediaMetadata(
        title: title,
        images: posterUrl == null
            ? []
            : [
                GoogleCastImage(
                  url: Uri.parse(posterUrl),
                  height: 720,
                  width: 480,
                ),
              ],
      ),
    );
    return GoogleCastRemoteMediaClient.instance.loadMedia(mediaInfo);
  }
}
