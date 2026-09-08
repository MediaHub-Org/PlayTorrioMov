import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../../services/cast/cast_service.dart';
import 'player_glass.dart';

/// Device picker for Cast -- shown from the player's Cast button. Only ever
/// opened when [CastService.isSupported] is true (mobile only); callers must
/// guard that before showing this.
class PlayerCastSheet extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final String streamUrl;

  const PlayerCastSheet({
    super.key,
    required this.title,
    required this.streamUrl,
    this.posterUrl,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String streamUrl,
    String? posterUrl,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerCastSheet(
        title: title,
        streamUrl: streamUrl,
        posterUrl: posterUrl,
      ),
    );
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
                  const Icon(Icons.cast_rounded, color: PlayerTheme.accent, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'CAST TO DEVICE',
                    style: TextStyle(
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
                    tooltip: 'Close',
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
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Looking for Cast devices on your network...',
                              style: TextStyle(
                                color: PlayerTheme.inkSubtle,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                                  url: streamUrl,
                                  title: title,
                                  posterUrl: posterUrl,
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
