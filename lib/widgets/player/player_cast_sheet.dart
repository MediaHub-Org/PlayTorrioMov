import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../services/cast/cast_service.dart';
import 'player_glass.dart';

/// Device picker for Cast -- shown from the player's Cast button. Only ever
/// opened when [CastService.isSupported] is true (mobile only); callers must
/// guard that before showing this.
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
    showModalBottomSheet(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cast_rounded, color: PlayerTheme.accent, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.playerCastToDevice.toUpperCase(),
                    style: const TextStyle(
                      color: PlayerTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
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
                                height: 48,
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
          ),
        ),
      ),
    );
  }
}
