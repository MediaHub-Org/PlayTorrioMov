import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/stream/torrent_stream_service.dart';
import 'package:playtorriomov/widgets/player/player_stats_menu.dart';

/// The transport bar's info button opens this: swarm figures for a torrent,
/// host and buffer for anything else.
Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

const _swarm = TorrentStats(
  speedMbps: 2.5,
  activePeers: 4,
  totalPeers: 12,
  cachePercent: 37.5,
  loadedBytes: 300,
  totalBytes: 800,
  hash: '0123456789abcdef',
  isConnected: true,
);

void main() {
  group('PlayerStatsMenu', () {
    testWidgets('a direct stream shows source, type, host and buffer',
        (tester) async {
      // No magnet behind it, so no swarm rows: peers and speed would be
      // claims about a swarm that does not exist on this device.
      final buffered = ValueNotifier<Duration?>(const Duration(seconds: 42));
      addTearDown(buffered.dispose);

      await tester.pumpWidget(wrap(PlayerStatsMenu(
        sourceLabel: 'Torrentio · 1080p',
        streamKind: 'HTTPS',
        host: 'cdn.example.com',
        buffered: buffered,
      )));
      await tester.pump();

      expect(find.text('Torrentio · 1080p'), findsOneWidget);
      expect(find.text('HTTPS'), findsOneWidget);
      expect(find.text('cdn.example.com'), findsOneWidget);
      expect(find.text('42 s'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a torrent shows peers, speed, completed and hash',
        (tester) async {
      await tester.pumpWidget(wrap(const PlayerStatsMenu(
        sourceLabel: 'Torrentio · 1080p',
        streamKind: 'Torrent',
        infoHash: '0123456789abcdef',
        initialStats: _swarm,
      )));
      await tester.pump();

      expect(find.text('2.50 MB/s'), findsOneWidget);
      expect(find.text('4 / 12'), findsOneWidget);
      expect(find.text('37.5%'), findsOneWidget);
      expect(find.text('0123456789abcdef'), findsOneWidget);
    });

    testWidgets('a live stream marks the type as live', (tester) async {
      await tester.pumpWidget(wrap(const PlayerStatsMenu(
        sourceLabel: 'Portal · Sports',
        streamKind: 'HLS',
        isLive: true,
      )));
      await tester.pump();

      expect(find.text('HLS · Live'), findsOneWidget);
    });
  });
}
