import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../services/cast/cast_service.dart';
import '../../utils/navigation/adaptive_sheet.dart';
import 'player_glass.dart';

/// Device picker for Cast -- shown from the player's Cast button. Only ever
/// opened when [CastService.isSupported] is true (mobile only); callers must
/// guard that before showing this.
///
/// **Never seen with a device listed in it (#28).** A bug found by reading the
/// plugin's source on 2026-09-15 explains the "searches forever" report
/// exactly -- the picker subscribed to a device stream nothing had started
/// producing -- but whether that was the only cause needs a receiver on the
/// network. What to check, in order: that a device appears within a few
/// seconds; that a movie from a direct or CDN source reaches the TV (a scraper
/// source needing Referer or User-Agent will not, because the Cast SDK has no
/// sender-side way to attach either); that a Live TV channel shows as live with
/// no seek bar or phantom duration; and that disconnect returns playback
/// cleanly.
///
/// The sheet's own layout is probed -- see `text_scale_overflow_test.dart`,
/// which is how the 567px overflow in it was found without a receiver.
class PlayerCastSheet extends StatefulWidget {
  final String title;
  final String? posterUrl;
  final String streamUrl;

  /// A live channel, so the receiver is told `live` rather than `buffered`
  /// and does not offer a seek bar over a stream with no end.
  final bool isLive;

  const PlayerCastSheet({
    super.key,
    required this.title,
    required this.streamUrl,
    this.isLive = false,
    this.posterUrl,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String streamUrl,
    bool isLive = false,
    String? posterUrl,
  }) {
    showAdaptiveSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerCastSheet(
        title: title,
        streamUrl: streamUrl,
        isLive: isLive,
        posterUrl: posterUrl,
      ),
    );
  }

  @override
  State<PlayerCastSheet> createState() => _PlayerCastSheetState();
}

class _PlayerCastSheetState extends State<PlayerCastSheet> {
  @override
  void initState() {
    super.initState();
    // The device list is empty until something asks the plugin to scan, and
    // nothing else does: this sheet showing "Looking for Cast devices..."
    // forever was that call never being made.
    CastService.startDiscovery();
  }

  @override
  void dispose() {
    // Scanning holds the radio awake. The session, once started, does not
    // depend on discovery still running.
    CastService.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: PlayerGlassCard(
          padding: const EdgeInsets.all(16),
          // The sheet had no scrollable at all: a Column(min) straight into
          // the card. Its height is decided by the modal, not by its content,
          // so a long device list or a large text setting simply painted past
          // the bottom -- 567px at 3x. Scrolling rather than clamping, because
          // the content genuinely needs the room and a viewer who asked for 3x
          // text should get it (#69).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cast_rounded, color: PlayerTheme.accent, size: 20),
                    const SizedBox(width: 10),
                    // Expanded, not Text + Spacer. Laid out flat the title
                    // demanded its natural width and pushed the close button
                    // past the edge -- 321px of overflow at 3x text scale, and
                    // this string is translated, so a longer language narrows
                    // the margin before any accessibility setting is involved.
                    // Taking the Spacer's job means the title gives way first,
                    // which is the same fix the Continue Watching header needed.
                    Expanded(
                      child: Text(
                        context.l10n.playerCastToDevice.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PlayerTheme.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    PlayerIconButton(
                      size: 28,
                      iconSize: 14,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: context.l10n.playerClose,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                StreamBuilder<GoogleCastSession?>(
                  stream: CastService.sessionStream,
                  builder: (context, sessionSnapshot) {
                    final connected = CastService.isConnected;
                    return StreamBuilder<List<GoogleCastDevice>>(
                      stream: CastService.devicesStream,
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? const [];
                        if (devices.isEmpty) {
                          // A real scan is running behind this now, so it gets
                          // a spinner. Before, the same words sat there
                          // motionless forever because nothing was searching.
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PlayerTheme.accent,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  context.l10n.playerCastLooking,
                                  style: const TextStyle(
                                    color: PlayerTheme.inkSubtle,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  context.l10n.playerCastSameWifi,
                                  style: const TextStyle(
                                    color: PlayerTheme.inkSubtle,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: devices.map((device) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await CastService.connect(device);
                                  await CastService.loadMedia(
                                    url: widget.streamUrl,
                                    isLive: widget.isLive,
                                    title: widget.title,
                                    posterUrl: widget.posterUrl,
                                  );
                                },
                                child: Container(
                                  // A floor, not a fixed height: the device name grows with text scale.
                                  constraints: const BoxConstraints(minHeight: 48),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        connected
                                            ? Icons.cast_connected_rounded
                                            : Icons.tv_rounded,
                                        size: 20,
                                        color: PlayerTheme.inkMuted,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          device.friendlyName,
                                          style: const TextStyle(
                                            color: PlayerTheme.ink,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            )
          ),
        ),
      ),
    );
  }
}
