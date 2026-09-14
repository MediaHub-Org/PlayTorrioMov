import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/iptv/m3u_parser.dart';

/// `M3uParser` was already pure and already had no test. It reads every IPTV
/// playlist the app loads — a user's own URL, a portal's export, a file off
/// disk — so the shapes it has to survive are written by strangers.
void main() {
  group('M3uParser.parse', () {
    test('reads name, url and attributes off one entry', () {
      final channels = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 tvg-id="bbc1.uk" tvg-name="BBC One" tvg-logo="http://x/l.png" group-title="UK",BBC One HD
http://example.test/bbc1.m3u8
''');

      expect(channels, hasLength(1));
      final c = channels.single;
      expect(c.name, 'BBC One HD');
      expect(c.url, 'http://example.test/bbc1.m3u8');
      expect(c.tvgId, 'bbc1.uk');
      expect(c.tvgName, 'BBC One');
      expect(c.logo, 'http://x/l.png');
      expect(c.group, 'UK');
    });

    test('the name after the comma wins over tvg-name', () {
      final c = M3uParser.parse(
        '#EXTINF:-1 tvg-name="Feed 4",Channel Four\nhttp://x/4',
      ).single;
      expect(c.name, 'Channel Four');
    });

    test('falls back to tvg-name, then to a placeholder', () {
      expect(
        M3uParser.parse('#EXTINF:-1 tvg-name="Feed 4",\nhttp://x/4').single.name,
        'Feed 4',
      );
      expect(
        M3uParser.parse('#EXTINF:-1,\nhttp://x/4').single.name,
        'Unknown',
      );
    });

    test('accepts single-quoted and unquoted attribute values', () {
      final c = M3uParser.parse(
        "#EXTINF:-1 tvg-id='a.b' group-title=Sports,Name\nhttp://x/1",
      ).single;
      expect(c.tvgId, 'a.b');
      expect(c.group, 'Sports');
    });

    test('#EXTGRP sets the group for the entry that follows', () {
      final c = M3uParser.parse(
        '#EXTINF:-1,Name\n#EXTGRP:News\nhttp://x/1',
      ).single;
      expect(c.group, 'News');
    });

    test('survives CRLF and stray blank lines', () {
      final channels = M3uParser.parse(
        '#EXTM3U\r\n\r\n#EXTINF:-1,A\r\nhttp://x/a\r\n\r\n#EXTINF:-1,B\r\nhttp://x/b\r\n',
      );
      expect(channels.map((c) => c.name), ['A', 'B']);
      expect(channels.map((c) => c.url), ['http://x/a', 'http://x/b']);
    });

    test('keeps the non-HTTP stream protocols IPTV actually uses', () {
      for (final scheme in ['rtmp', 'rtmps', 'rtsp', 'udp', 'rtp', 'mms', 'mmsh']) {
        final channels = M3uParser.parse('#EXTINF:-1,C\n$scheme://host/path');
        expect(channels.single.url, startsWith(scheme),
            reason: '$scheme is a stream URL and must not be dropped');
      }
    });

    test('metadata does not leak onto a later channel', () {
      // A line that is neither a tag nor a URL discards the EXTINF above it.
      // Without that reset, "Two" below would have been published under
      // One's name and logo.
      final channels = M3uParser.parse('''
#EXTINF:-1 tvg-logo="http://x/one.png",One
not-a-url-at-all
#EXTINF:-1,Two
http://x/two
''');
      expect(channels, hasLength(1));
      expect(channels.single.name, 'Two');
      expect(channels.single.logo, isEmpty);
    });

    test('a URL with no EXTINF is kept, named after itself', () {
      final c = M3uParser.parse('http://x/bare').single;
      expect(c.name, 'http://x/bare');
      expect(c.url, 'http://x/bare');
    });

    test('unknown # directives are ignored, not treated as URLs', () {
      final channels = M3uParser.parse(
        '#EXTM3U\n#EXTVLCOPT:network-caching=1000\n#EXTINF:-1,A\nhttp://x/a',
      );
      expect(channels, hasLength(1));
    });

    group('rejects what is not a playlist', () {
      test('empty input', () {
        expect(() => M3uParser.parse(''), throwsFormatException);
      });

      test('text with no channel in it', () {
        // An HTML error page from a dead portal is the common case, and the
        // message a user sees comes from here.
        expect(
          () => M3uParser.parse('<html><body>404 Not Found</body></html>'),
          throwsFormatException,
        );
      });

      test('a header with nothing under it', () {
        expect(() => M3uParser.parse('#EXTM3U\n'), throwsFormatException);
      });
    });
  });
}
