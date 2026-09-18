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
              // The SDK default waits for a first tap on *its own* native
              // Cast button before it will discover anything. This app draws
              // its own button and opens `PlayerCastSheet`, so that tap never
              // happens and the wait would never end.
              startDiscoveryAfterFirstTapOnCastButton: false,
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

  /// Begins scanning the local network for receivers.
  ///
  /// **[devicesStream] stays empty until this is called.** Nothing in the
  /// plugin starts discovery on its own: on Android `onAttachedToEngine` only
  /// wires up the method channel, and the `MediaRouter.addCallback` that
  /// actually scans lives solely inside the native `startDiscovery`, which is
  /// reachable only from here. iOS is the same through `GCKDiscoveryManager`.
  ///
  /// Scanning costs battery and radio, so this is called when the device
  /// picker opens rather than at startup, and stopped again when it closes.
  static Future<void> startDiscovery() async {
    if (!isSupported || !_initialized) return;
    try {
      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e) {
      // A device without Play Services, or a Cast context that failed to
      // initialize. The picker then shows its empty state, which is honest.
      debugPrint('[CastService] startDiscovery error: $e');
    }
  }

  /// Stops scanning. Safe to call whether or not discovery was running.
  static Future<void> stopDiscovery() async {
    if (!isSupported || !_initialized) return;
    try {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (e) {
      debugPrint('[CastService] stopDiscovery error: $e');
    }
  }

  static Stream<GoogleCastSession?> get sessionStream =>
      GoogleCastSessionManager.instance.currentSessionStream;

  static bool get isConnected =>
      GoogleCastSessionManager.instance.connectionState ==
      GoogleCastConnectState.connected;

  static Future<void> connect(GoogleCastDevice device) =>
      GoogleCastSessionManager.instance.startSessionWithDevice(device);

  static Future<void> disconnect() =>
      GoogleCastSessionManager.instance.endSessionAndStopCasting();

  /// Whether a Cast receiver on the network could actually fetch [url].
  ///
  /// The receiver is a separate box: it opens the URL itself, over the LAN.
  /// So anything served from this device's own loopback is unreachable to
  /// it -- a downloaded file played from disk, the local Mega proxy, or a
  /// torrent server bound to 127.0.0.1 -- and so is a `file://` path.
  ///
  /// Deliberately a host test rather than the old "is this a torrent"
  /// test. A torrent source is not inherently uncastable: plenty resolve
  /// through a debrid or a torrent server on another machine, and those
  /// URLs are as fetchable as any other. What makes a stream uncastable is
  /// where it lives, which is exactly what the host says.
  static bool canCastUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'file' || uri.scheme.isEmpty) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    if (host == '::1' || host == '[::1]') return false;

    // 127.0.0.0/8 -- the whole block, not just 127.0.0.1: media servers
    // bind to 127.0.0.2 and friends often enough to matter.
    final octets = host.split('.');
    if (octets.length == 4) {
      final first = int.tryParse(octets.first);
      if (first == 127) return false;
      if (first == 0) return false;
    }

    return true;
  }

  /// Best-effort guess from the URL -- the Cast receiver needs a content
  /// type to pick a demuxer. Most sources here are progressive MP4; HLS/DASH
  /// playlists and raw transport streams are the exceptions worth detecting.
  ///
  /// `.ts` matters now that Live TV can cast: IPTV portals serve MPEG-TS
  /// constantly, and calling one `video/mp4` hands the receiver a demuxer
  /// that cannot read it.
  @visibleForTesting
  static String contentTypeFor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'application/x-mpegurl';
    if (lower.contains('.mpd')) return 'application/dash+xml';
    if (lower.contains('.mkv')) return 'video/x-matroska';
    if (lower.contains('.ts')) return 'video/mp2t';
    return 'video/mp4';
  }

  /// Loads [url] onto the connected receiver. Note: the Cast SDK has no
  /// sender-side way to attach custom HTTP headers (Referer/User-Agent) to
  /// the request the receiver makes for the media -- a scraper source that
  /// requires them (many do) will fail to play on the TV even though it
  /// plays fine locally, where this app's own player sends those headers
  /// itself. Direct/CDN sources are the ones most likely to work.
  /// [isLive] picks the receiver's stream type. A live channel announced as
  /// `buffered` gets a seek bar and a duration the receiver cannot honour;
  /// the Cast SDK has a `live` type precisely for this. It was hardcoded to
  /// `buffered` when only Movies/Series/Anime could cast, and casting a
  /// Live TV channel is what made that wrong.
  static Future<void> loadMedia({
    required String url,
    required String title,
    String? posterUrl,
    bool isLive = false,
  }) {
    final mediaInfo = GoogleCastMediaInformation(
      contentId: url,
      streamType: isLive
          ? CastMediaStreamType.live
          : CastMediaStreamType.buffered,
      contentUrl: Uri.parse(url),
      contentType: contentTypeFor(url),
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
