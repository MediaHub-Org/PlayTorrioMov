// test/services/anime_extractor_parsing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/anime/extractors/luna_extractor.dart';
import 'package:playtorriomov/services/anime/extractors/voe_cipher.dart';

/// The anime extractors' pure parts, tested without a network.
///
/// The last of the three candidates the roadmap named, and the one it was
/// most cautious about: these read pages that change without notice, so a
/// captured fixture pins one day's markup and says nothing about the next.
/// That caution applies to the *scraping* — finding the script tag, matching
/// the slug. It does not apply to what is inside:
///
/// VOE's payload is a chain of six reversible steps. Like `MovyCipher`, it is
/// arithmetic on a string, and because it is reversible a test can build a
/// payload and check it survives the round trip — pinning every step against
/// its own inverse rather than against a capture. Luna's transport is a
/// Next.js RSC stream, which is a framework's format, not Luna's markup.
///
/// Before this, reaching either meant running the whole fetch-and-decrypt
/// pipeline against a live host.
void main() {
  group('VoeCipher.rot13', () {
    test('is its own inverse', () {
      const sample = 'Hello, World! 123 +/=';
      expect(VoeCipher.rot13(VoeCipher.rot13(sample)), sample);
    });

    test('rotates letters and leaves everything else alone', () {
      expect(VoeCipher.rot13('abcnop'), 'nopabc');
      expect(VoeCipher.rot13('ABCNOP'), 'NOPABC');
      // Digits and base64 punctuation have to survive: the very next step
      // feeds this to a base64 decoder.
      expect(VoeCipher.rot13('0123456789+/='), '0123456789+/=');
    });
  });

  group('VoeCipher.shiftCodeUnits', () {
    test('shifting up then down gets the original back', () {
      const sample = 'YWJjZGVmZ2g=';
      expect(
        VoeCipher.shiftCodeUnits(VoeCipher.shiftCodeUnits(sample, 3), -3),
        sample,
      );
    });
  });

  group('VoeCipher.decode', () {
    test('unwraps a payload built by its own inverse', () {
      // The round trip is the point: it pins all six steps, in order, without
      // a fixture that would go stale the next time the site is touched.
      final payload = VoeCipher.obfuscate({
        'file': 'https://cdn.example/stream.m3u8',
        'title': 'Episode 1',
      });

      final decoded = VoeCipher.decode(payload);

      expect(decoded, isA<Map>());
      expect(decoded['file'], 'https://cdn.example/stream.m3u8');
      expect(VoeCipher.streamUrl(decoded), 'https://cdn.example/stream.m3u8');
    });

    test('junk markers sprinkled through the payload are stripped', () {
      // They exist to break a naive base64 decode, and the page inserts them
      // under the outer rot13 -- so undoing rot13 first and stripping second
      // is the order that has to work. Built by rot13-ing back to the base64,
      // splicing markers in, and re-rot13-ing, which is what the page does.
      final clean = VoeCipher.obfuscate({'source': 'https://cdn.example/a.mp4'});
      final inner = VoeCipher.rot13(clean);
      final spliced =
          '${inner.substring(0, 4)}${VoeCipher.junk.join()}${inner.substring(4)}';

      expect(
        VoeCipher.streamUrl(VoeCipher.decode(VoeCipher.rot13(spliced))),
        'https://cdn.example/a.mp4',
      );
    });

    test('a page whose obfuscation moved on decodes to null, not a throw', () {
      // Each of the six steps can fail, and the caller's answer to all of
      // them is the same: no stream here, try the next extractor.
      expect(VoeCipher.decode(''), isNull);
      expect(VoeCipher.decode('not base64 at all ???'), isNull);
      expect(VoeCipher.decode('<html>410 Gone</html>'), isNull);
    });

    test('valid JSON that is not a stream payload yields no URL', () {
      final payload = VoeCipher.obfuscate({'error': 'gone'});

      expect(VoeCipher.decode(payload), isA<Map>());
      expect(VoeCipher.streamUrl(VoeCipher.decode(payload)), isNull);
    });
  });

  group('VoeCipher.streamUrl', () {
    test('file and source are the same field spelled two ways', () {
      expect(VoeCipher.streamUrl({'file': 'https://a'}), 'https://a');
      expect(VoeCipher.streamUrl({'source': 'https://b'}), 'https://b');
    });

    test('file wins when a page sends both', () {
      expect(
        VoeCipher.streamUrl({'file': 'https://a', 'source': 'https://b'}),
        'https://a',
      );
    });

    test('nothing usable is null rather than an empty URL', () {
      expect(VoeCipher.streamUrl(null), isNull);
      expect(VoeCipher.streamUrl('a string'), isNull);
      expect(VoeCipher.streamUrl({}), isNull);
      expect(VoeCipher.streamUrl({'file': ''}), isNull);
    });
  });

  group('LunaExtractor.parseRscResponse', () {
    test('reads the row keyed 1 out of an RSC stream', () {
      const body = '0:{"bookkeeping":true}\n'
          '1:{"sources":[{"url":"https://cdn.example/a.m3u8"}]}\n'
          '2:["more react state"]';

      final parsed = LunaExtractor.parseRscResponse(body);

      expect(parsed, isNotNull);
      expect(parsed!['sources'], isA<List>());
    });

    test('rows that are not JSON are skipped, not fatal', () {
      // React's own rows are not always valid JSON, and one of them appearing
      // before the payload must not end the search.
      const body = '1:I am not JSON\n'
          '1:{"sources":[]}';

      expect(LunaExtractor.parseRscResponse(body), isNotNull);
    });

    test('a row keyed 1 holding an array is not the payload', () {
      // The payload is an object. An array on that key is React's, not ours.
      expect(LunaExtractor.parseRscResponse('1:["a","b"]'), isNull);
    });

    test('no row keyed 1 means no payload', () {
      expect(LunaExtractor.parseRscResponse('0:{"a":1}\n2:{"b":2}'), isNull);
      expect(LunaExtractor.parseRscResponse(''), isNull);
      expect(LunaExtractor.parseRscResponse('<html>error</html>'), isNull);
    });
  });

  group('LunaExtractor.cleanUrl', () {
    test('undoes a doubled origin', () {
      // The API sometimes concatenates its own base onto an already-absolute
      // URL. Left alone the host does not resolve and the stream fails with
      // nothing to say why.
      expect(
        LunaExtractor.cleanUrl(
          'https://api.luna-stream.mehttps://api.luna-stream.me/v1/a.m3u8',
        ),
        'https://api.luna-stream.me/v1/a.m3u8',
      );
    });

    test('a normal URL is untouched', () {
      const url = 'https://cdn.example/a.m3u8';
      expect(LunaExtractor.cleanUrl(url), url);
      expect(LunaExtractor.cleanUrl(''), '');
    });
  });
}
