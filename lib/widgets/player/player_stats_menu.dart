import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/stream/torrent_stream_service.dart';
import 'player_glass.dart';

/// Live statistics for the stream being played, behind the transport bar's
/// info button.
///
/// A torrent shows its swarm the way a client does -- download speed, peers
/// and how much of the file has arrived -- while an HLS playlist or a plain
/// HTTPS stream shows what there is to know about it instead: its host and
/// how much is buffered. The kind names stay technical (`Torrent`, `HLS`,
/// `HTTPS`): they are protocol names, not sentences, so they are data rather
/// than UI.
class PlayerStatsMenu extends StatefulWidget {
  /// Who serves this stream, e.g. the addon and quality that produced it.
  final String sourceLabel;

  /// Technical kind token: `Torrent`, `Debrid`, `HLS`, `DASH`, `HTTPS` or
  /// `File`. A token, never a sentence, so it needs no translation.
  final String streamKind;

  final bool isLive;

  /// The host the player opened, without scheme or path. Null when there is
  /// no remote URL behind the stream (a local file, a P2P torrent served
  /// from this device).
  final String? host;

  /// The torrent's info hash, when the stream is one. Shown whole and
  /// ellipsized rather than truncated by hand, so what is on screen is
  /// visibly a prefix of the real value.
  final String? infoHash;

  /// The magnet TorrServer is serving, set only for a P2P torrent played
  /// through the local engine. Null for everything else, including a
  /// torrent resolved through debrid -- there is no swarm on this device to
  /// poll for that one.
  final String? torrentMagnet;

  /// Swarm figures to paint before the first poll answers. The production
  /// caller leaves this null and the menu reads the engine; tests pass a
  /// canned value instead, so no test has to start TorrServer to cover the
  /// torrent rows.
  final TorrentStats? initialStats;

  /// What the player has buffered. Rebuilt live so the figure moves while
  /// the menu is open.
  final ValueListenable<Duration?>? buffered;

  /// Copies the resolved stream URL. Null hides the action, for streams
  /// with no URL worth passing on.
  final VoidCallback? onCopyLink;

  const PlayerStatsMenu({
    super.key,
    required this.sourceLabel,
    required this.streamKind,
    this.isLive = false,
    this.host,
    this.infoHash,
    this.torrentMagnet,
    this.initialStats,
    this.buffered,
    this.onCopyLink,
  });

  @override
  State<PlayerStatsMenu> createState() => _PlayerStatsMenuState();
}

class _PlayerStatsMenuState extends State<PlayerStatsMenu> {
  /// The swarm poll, owned by this menu rather than the player screen: it
  /// starts when the menu opens and its subscription dies with the menu, so
  /// closing the panel is what stops the once-a-second polling. A field on
  /// the screen would need every site that clears the active menu to
  /// remember to cancel it too.
  Stream<TorrentStats>? _statsStream;
  TorrentStats? _firstStats;

  @override
  void initState() {
    super.initState();
    final magnet = widget.torrentMagnet;
    if (magnet != null) {
      _statsStream = TorrentStreamService().statsStream(magnet);
      // A synchronous cache read, not I/O: paints something on the first
      // frame instead of dashes until the first one-second tick lands.
      _firstStats =
          widget.initialStats ?? TorrentStreamService().getTorrentStats(magnet);
    } else {
      _firstStats = widget.initialStats;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showSwarm =
        widget.torrentMagnet != null || widget.initialStats != null;
    final host = widget.host;
    final hash = widget.infoHash;

    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      padding: EdgeInsets.all(context.rem(0.625)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlayerMenuHeader(title: l10n.playerStats.toUpperCase()),
          SizedBox(height: context.rem(AppRem.snug)),
          _StatRow(label: l10n.playerStatsSource, value: widget.sourceLabel),
          _StatRow(
            label: l10n.playerStatsType,
            value: widget.isLive
                ? '${widget.streamKind} · ${l10n.iptvLive}'
                : widget.streamKind,
          ),
          if (host != null && host.isNotEmpty)
            _StatRow(label: l10n.playerStatsHost, value: host),
          if (showSwarm)
            StreamBuilder<TorrentStats?>(
              stream: _statsStream,
              initialData: _firstStats,
              builder: (context, snapshot) {
                final stats = snapshot.data;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatRow(
                      label: l10n.playerStatsSpeed,
                      value: stats?.speedLabel,
                    ),
                    _StatRow(
                      label: l10n.playerStatsPeers,
                      value: stats?.peersLabel,
                    ),
                    _StatRow(
                      label: l10n.playerStatsCompleted,
                      value: stats?.cacheLabel,
                    ),
                  ],
                );
              },
            ),
          if (widget.buffered != null)
            ValueListenableBuilder<Duration?>(
              valueListenable: widget.buffered!,
              builder: (context, buffered, _) => _StatRow(
                label: l10n.playerStatsBuffered,
                value: buffered == null ? null : '${buffered.inSeconds} s',
              ),
            ),
          if (hash != null && hash.isNotEmpty)
            _StatRow(label: l10n.playerStatsHash, value: hash),
          // The URL copier lives with the data it copies: the top bar kept
          // it beside download, where it squeezed the title for a clipboard
          // action used once per stream at most.
          if (widget.onCopyLink != null) ...[
            SizedBox(height: context.rem(AppRem.xs)),
            const Divider(color: PlayerTheme.edgeSoft, height: 1), // px: a hairline, not a layout size
            TextButton.icon(
              onPressed: widget.onCopyLink,
              icon: Icon(
                Icons.link_rounded,
                size: context.rem(AppRem.iconSm),
              ),
              label: Text(l10n.playerCopyStreamUrl),
              style: TextButton.styleFrom(
                foregroundColor: PlayerTheme.inkSubtle,
                minimumSize: Size(0, context.rem(2.25)),
                textStyle: const TextStyle(fontSize: AppType.caption),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One read-only label/value line. A dash while the figure is unknown, so a
/// torrent whose engine has not answered yet reads as waiting rather than
/// as zero -- zero peers would say the swarm is empty, which is a claim.
class _StatRow extends StatelessWidget {
  final String label;
  final String? value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rem(0.3125)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PlayerTheme.inkSubtle,
                fontSize: AppType.caption,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: context.rem(AppRem.sm)),
          Flexible(
            child: Text(
              value ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: PlayerTheme.ink,
                fontSize: AppType.captionPlus,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
