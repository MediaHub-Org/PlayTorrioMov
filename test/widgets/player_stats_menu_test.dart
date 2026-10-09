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

    testWidgets('the copy action fires and hides without a link', (
      tester,
    ) async {
      var copies = 0;
      await tester.pumpWidget(wrap(PlayerStatsMenu(
        sourceLabel: 'Torrentio · 1080p',
        streamKind: 'HTTPS',
        host: 'cdn.example.com',
        onCopyLink: () => copies++,
      )));
      await tester.pump();

      await tester.tap(find.text('Copy Stream URL'));
      expect(copies, 1);

      await tester.pumpWidget(wrap(const PlayerStatsMenu(
        sourceLabel: 'Torrentio · 1080p',
        streamKind: 'HTTPS',
        host: 'cdn.example.com',
      )));
      await tester.pump();

      expect(find.text('Copy Stream URL'), findsNothing);
    });
  });

  group('the diagnosis', () {
    // "Slow, worse on the TV" is either the link or the decoder, and the panel
    // says which in a sentence.
    Future<void> pumpWith(
      WidgetTester tester, {
      required Map<String, String> properties,
      required Duration buffered,
      int? sourceBitrateKbps,
    }) async {
      final notifier = ValueNotifier<Duration?>(buffered);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(wrap(PlayerStatsMenu(
        sourceLabel: 'Torrentio · 1080p',
        streamKind: 'HTTPS',
        buffered: notifier,
        sourceBitrateKbps: sourceBitrateKbps,
        readProperty: (name) async => properties[name],
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('a starved cache on a slow link says the link is the limit', (
      tester,
    ) async {
      await pumpWith(
        tester,
        buffered: const Duration(seconds: 1),
        properties: {
          'cache-speed': '1125000', // 9 Mb/s
          'video-bitrate': '18000000', // 18 Mb/s
          'hwdec-current': 'mediacodec',
          'frame-drop-count': '0',
          'decoder-frame-drop-count': '0',
        },
      );

      expect(find.textContaining('needs about 18.0 Mb/s'), findsOneWidget);
      expect(find.textContaining('about 9.0 Mb/s'), findsOneWidget);
      expect(find.text('mediacodec'), findsOneWidget);
    });

    testWidgets('a healthy cache and dropped frames blame the device', (
      tester,
    ) async {
      var dropped = 0;
      final notifier = ValueNotifier<Duration?>(const Duration(seconds: 40));
      addTearDown(notifier.dispose);
      await tester.pumpWidget(wrap(PlayerStatsMenu(
        sourceLabel: 'Torrentio · 4K',
        streamKind: 'HTTPS',
        buffered: notifier,
        readProperty: (name) async => switch (name) {
          'cache-speed' => '100',
          'video-bitrate' => '40000000',
          'hwdec-current' => 'no',
          'decoder-frame-drop-count' => '${dropped += 8}',
          'frame-drop-count' => '0',
          _ => null,
        },
      )));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.textContaining('struggling to decode'), findsOneWidget);
      expect(find.text('Software'), findsOneWidget,
          reason: 'mpv says "no"; a bare "no" under Decoder reads as a refusal');
    });

    testWidgets('a healthy playback says so', (tester) async {
      await pumpWith(
        tester,
        buffered: const Duration(seconds: 30),
        properties: {
          'cache-speed': '0',
          'video-bitrate': '8000000',
          'hwdec-current': 'mediacodec',
          'frame-drop-count': '0',
          'decoder-frame-drop-count': '0',
        },
      );

      expect(find.text('Playing normally.'), findsOneWidget);
    });

    testWidgets('falls back to the source bitrate before mpv has measured', (
      tester,
    ) async {
      await pumpWith(
        tester,
        buffered: const Duration(seconds: 1),
        sourceBitrateKbps: 12000,
        properties: {'cache-speed': '250000'}, // 2 Mb/s
      );

      expect(find.textContaining('needs about 12.0 Mb/s'), findsOneWidget);
    });

    testWidgets('does nothing without a way to read the player', (tester) async {
      final notifier = ValueNotifier<Duration?>(const Duration(seconds: 3));
      addTearDown(notifier.dispose);
      await tester.pumpWidget(wrap(PlayerStatsMenu(
        sourceLabel: 'x',
        streamKind: 'HTTPS',
        buffered: notifier,
      )));
      await tester.pump();

      expect(find.text('Needs'), findsNothing);
      expect(find.text('Dropped frames'), findsNothing);
    });
  });
}
