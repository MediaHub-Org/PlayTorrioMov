import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/stream/stream_model.dart';
import '../../services/app_units.dart';
import '../../services/player/playback_diagnosis.dart';
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

  /// Reads one of the player's own properties by name (`cache-speed`,
  /// `hwdec-current`), or null when it is not available. Null hides the
  /// diagnosis; the panel works without it.
  ///
  /// A callback, not the player: the menu is a plain widget that tests pump
  /// bare, and a fake of this is one line.
  final Future<String?> Function(String property)? readProperty;

  /// The source's own bitrate when it states one (or it can be estimated), for
  /// when the player has not measured the stream yet.
  final int? sourceBitrateKbps;

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
    this.readProperty,
    this.sourceBitrateKbps,
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

  /// What the player reports about itself, read once a second while the panel
  /// is open and stopped with it, like the swarm poll above.
  Timer? _poll;
  int? _haveKbps;
  int? _measuredNeedKbps;
  String? _decoder;
  int _dropped = 0;
  final List<int> _droppedHistory = [];

  /// Frames dropped over the last few seconds, not since the start: a burst
  /// while seeking is not a problem the viewer has now.
  int get _droppedRecently =>
      _droppedHistory.length < 2 ? 0 : _droppedHistory.last - _droppedHistory.first;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _readPlayer() async {
    final read = widget.readProperty;
    if (read == null) return;
    Future<double?> number(String name) async =>
        double.tryParse(await read(name) ?? '');

    final cacheSpeed = await number('cache-speed');
    final videoBitrate = await number('video-bitrate');
    final decoder = await read('hwdec-current');
    final dropped = (await number('decoder-frame-drop-count') ?? 0) +
        (await number('frame-drop-count') ?? 0);
    if (!mounted) return;
    setState(() {
      _haveKbps = cacheSpeed == null ? null : (cacheSpeed * 8 / 1000).round();
      _measuredNeedKbps =
          videoBitrate == null ? null : (videoBitrate / 1000).round();
      _decoder = decoder;
      _dropped = dropped.round();
      _droppedHistory.add(_dropped);
      if (_droppedHistory.length > 10) _droppedHistory.removeAt(0);
    });
  }

  /// The panel's figures as plain text, for pasting into a bug report or a
  /// message. "Slow on my TV" is something nobody can act on; these lines are.
  String _report(BuildContext context) {
    final l10n = context.l10n;
    final need = _measuredNeedKbps ?? widget.sourceBitrateKbps;
    String bitrate(int? kbps) =>
        kbps == null ? '-' : StreamSource.formatBitrate(kbps);
    final buffered = widget.buffered?.value;
    final diagnosis = diagnose(
      needKbps: need,
      haveKbps: _haveKbps,
      bufferedSeconds: buffered?.inSeconds.toDouble(),
      droppedRecently: _droppedRecently,
    );
    return [
      '${l10n.playerStatsSource}: ${widget.sourceLabel}',
      '${l10n.playerStatsType}: ${widget.streamKind}',
      if (widget.host != null) '${l10n.playerStatsHost}: ${widget.host}',
      '${l10n.playerStatsNeeds}: ${bitrate(need)}',
      '${l10n.playerStatsDelivering}: ${bitrate(_haveKbps)}',
      '${l10n.playerStatsDecoder}: ${_decoder ?? '-'}',
      '${l10n.playerStatsDropped}: $_dropped',
      '${l10n.playerStatsBuffered}: ${buffered == null ? '-' : '${buffered.inSeconds} s'}',
      'Verdict: ${diagnosis.verdict.name}',
    ].join('\n');
  }

  Future<void> _copyReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.l10n.playerStatsReportCopied;
    await Clipboard.setData(ClipboardData(text: _report(context)));
    messenger?.showSnackBar(
      SnackBar(content: Text(copied), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.readProperty != null) {
      _readPlayer();
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => _readPlayer());
    }
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

  /// The player's own figures and, under them, which of the two usual causes of
  /// a slow playback this looks like.
  List<Widget> _buildDiagnosis(BuildContext context) {
    final l10n = context.l10n;
    final need = _measuredNeedKbps ?? widget.sourceBitrateKbps;
    final buffered = widget.buffered?.value;
    final diagnosis = diagnose(
      needKbps: need,
      haveKbps: _haveKbps,
      bufferedSeconds: buffered?.inSeconds.toDouble(),
      droppedRecently: _droppedRecently,
    );
    final decoder = _decoder;
    final sentence = switch (diagnosis.verdict) {
      PlaybackVerdict.unknown => null,
      PlaybackVerdict.healthy => l10n.playerDiagnosisHealthy,
      PlaybackVerdict.linkTooSlow => l10n.playerDiagnosisLink(
        StreamSource.formatBitrate(need!),
        StreamSource.formatBitrate(_haveKbps!),
      ),
      PlaybackVerdict.decoderStruggling => l10n.playerDiagnosisDecoder,
    };
    final isProblem = diagnosis.verdict == PlaybackVerdict.linkTooSlow ||
        diagnosis.verdict == PlaybackVerdict.decoderStruggling;

    return [
      _StatRow(
        label: l10n.playerStatsNeeds,
        value: need == null ? null : StreamSource.formatBitrate(need),
      ),
      _StatRow(
        label: l10n.playerStatsDelivering,
        value: _haveKbps == null ? null : StreamSource.formatBitrate(_haveKbps!),
      ),
      _StatRow(
        label: l10n.playerStatsDecoder,
        // mpv reports "no" for software decoding; a bare "no" under
        // "Decoder" reads as a refusal.
        value: decoder == null || decoder.isEmpty
            ? null
            : (decoder == 'no' ? l10n.playerDecoderSoftware : decoder),
      ),
      _StatRow(label: l10n.playerStatsDropped, value: '$_dropped'),
      if (sentence != null)
        Padding(
          padding: EdgeInsets.only(top: context.rem(AppRem.xs)),
          child: Text(
            sentence,
            style: TextStyle(
              color: isProblem ? PlayerTheme.accent : PlayerTheme.inkSubtle,
              fontSize: AppType.caption,
              fontWeight: FontWeight.w600,
              height: 1.3, // ratio: a line height, not a size
            ),
          ),
        ),
    ];
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
          if (widget.readProperty != null) ..._buildDiagnosis(context),
          if (hash != null && hash.isNotEmpty)
            _StatRow(label: l10n.playerStatsHash, value: hash),
          if (widget.readProperty != null)
            TextButton.icon(
              onPressed: () => _copyReport(context),
              icon: Icon(
                Icons.copy_all_rounded,
                size: context.rem(AppRem.iconSm),
              ),
              label: Text(l10n.playerStatsCopyReport),
              style: TextButton.styleFrom(
                foregroundColor: PlayerTheme.inkSubtle,
                minimumSize: Size(0, context.rem(2.25)),
                textStyle: const TextStyle(fontSize: AppType.caption),
              ),
            ),
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
