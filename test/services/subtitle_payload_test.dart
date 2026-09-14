import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/subtitles/subtitle_payload.dart';

/// Offline cover for the part of subtitle downloading that decides what the
/// bytes are. It used to sit between an HTTP GET and a file write inside
/// `SubtitleExtractor`, reachable only by a tagged `network` test that CI
/// skips — so the archive handling, the likeliest thing to meet a shape
/// nobody anticipated, was never checked by a run that gates a merge.
List<int> _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

// dart:io's gzip rather than the archive package's encoder: standard gzip
// either way, and no question about the encoder's nullability or constness.
List<int> _gzip(String content) => gzip.encode(utf8.encode(content));

const _srt = '1\n00:00:01,000 --> 00:00:02,000\nHello\n';

void main() {
  group('SubtitlePayload.decode', () {
    test('a bare body is the subtitle', () {
      final payload = SubtitlePayload.decode(utf8.encode(_srt), url: 'x/a.srt');
      expect(payload.text, _srt);
      expect(payload.extension, 'srt');
    });

    test('unwraps a gzipped body', () {
      final payload = SubtitlePayload.decode(_gzip(_srt), url: 'x/a.srt');
      expect(payload.text, _srt);
    });

    test('unwraps a zipped body', () {
      final payload =
          SubtitlePayload.decode(_zip({'movie.srt': _srt}), url: 'x/a.zip');
      expect(payload.text, _srt);
      expect(payload.extension, 'srt');
    });

    test('picks the largest subtitle, not the first', () {
      // A release zip often carries a short "forced" track for signs next to
      // the full dialogue. Someone turning subtitles on wants the dialogue.
      const forced = '1\n00:00:01,000 --> 00:00:02,000\n[sign]\n';
      final full = _srt * 40;
      final payload = SubtitlePayload.decode(
        _zip({'forced.srt': forced, 'full.srt': full}),
        url: 'x/a.zip',
      );
      expect(payload.text, full);
    });

    test('skips macOS metadata that looks like a subtitle', () {
      // `__MACOSX/._movie.srt` ends in .srt and is not a subtitle. It is also
      // often larger than nothing, so "largest wins" alone would pick it when
      // it is the only entry left.
      final payload = SubtitlePayload.decode(
        _zip({
          '__MACOSX/._movie.srt': 'junk junk junk junk junk junk junk junk',
          'movie.srt': _srt,
        }),
        url: 'x/a.zip',
      );
      expect(payload.text, _srt);
    });

    test('reads the extension from the file inside the archive', () {
      final vtt = SubtitlePayload.decode(
        _zip({'movie.vtt': 'WEBVTT\n\n$_srt'}),
        url: 'x/a.zip',
      );
      expect(vtt.extension, 'vtt');

      final ass = SubtitlePayload.decode(
        _zip({'movie.ass': '[Script Info]\n'}),
        url: 'x/a.zip',
      );
      expect(ass.extension, 'ass');
    });

    test('.sub is taken as a subtitle but saved as srt', () {
      // `.sub` names a container, not a format; the player reads the content.
      final payload =
          SubtitlePayload.decode(_zip({'movie.sub': _srt}), url: 'x/a.zip');
      expect(payload.text, _srt);
      expect(payload.extension, 'srt');
    });

    test('the URL extension outranks the archive', () {
      // Providers serving WebVTT still name the file inside the zip
      // `subtitle.srt`. The provider named the format it is serving.
      final payload = SubtitlePayload.decode(
        _zip({'subtitle.srt': 'WEBVTT\n\n$_srt'}),
        url: 'https://example.test/track.vtt',
      );
      expect(payload.extension, 'vtt');
    });

    test('an archive with no subtitle in it falls back to the raw body', () {
      final zip = _zip({'readme.txt': 'nothing to see'});
      final payload = SubtitlePayload.decode(zip, url: 'x/a.zip');
      // Not a crash, and not an empty file: the bytes are handed on as-is for
      // whatever can be made of them.
      expect(payload.extension, 'srt');
    });

    test('a corrupt archive does not throw', () {
      // A truncated download keeps the PK magic and loses the rest. This used
      // to be a try/catch around the whole download; the fallback is now the
      // same either way.
      final truncated = _zip({'movie.srt': _srt}).sublist(0, 20);
      expect(() => SubtitlePayload.decode(truncated, url: 'x/a.zip'),
          returnsNormally);
    });

    test('empty bytes decode to empty text', () {
      final payload = SubtitlePayload.decode(const [], url: 'x/a.srt');
      expect(payload.text, isEmpty);
    });

    group('legacy encodings reach UTF-8', () {
      test('a UTF-8 BOM is stripped rather than kept as a character', () {
        final payload = SubtitlePayload.decode(
          [0xEF, 0xBB, 0xBF, ...utf8.encode('Hola')],
          url: 'x/a.srt',
        );
        expect(payload.text, 'Hola');
      });

      test('UTF-16LE is decoded, not mangled', () {
        final payload = SubtitlePayload.decode(
          [0xFF, 0xFE, 0x48, 0x00, 0x69, 0x00],
          url: 'x/a.srt',
        );
        expect(payload.text, 'Hi');
      });

      test('a non-UTF-8 byte does not throw', () {
        // Windows-1256 and Latin-1 subtitles are common and are not valid
        // UTF-8. Before the fallback ladder this threw and the download was
        // reported as a failure.
        expect(
          () => SubtitlePayload.decode([0x48, 0xE9, 0x6C], url: 'x/a.srt'),
          returnsNormally,
        );
      });
    });
  });
}
