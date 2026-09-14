import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/scraper/sites/movy_cipher.dart';

/// Offline cover for Movy's stream cipher — roadmap item 3's named next
/// candidate, and the last of the three it listed.
///
/// It was five private statics inside `MovyScraper`, reachable only by running
/// the whole fetch-and-decrypt pipeline against the live site. That test is
/// tagged `network` and excluded from CI, so pure deterministic arithmetic —
/// the part most likely to break silently under a change to Dart's integer or
/// shift semantics — was never checked by a run that gates a merge.
///
/// **If one of these constants ever disagrees with the code, the code is
/// right.** The expected values were derived by transcribing the algorithm and
/// evaluating it independently; the Dart is what has been decrypting real
/// responses. A mismatch means the transcription was wrong, not the cipher —
/// fix the constant, and only suspect the cipher if a real stream also fails.
void main() {
  group('MovyCipher.mix (MurmurHash3 finalizer)', () {
    test('holds its fixed points and known values', () {
      expect(MovyCipher.mix(0), 0);
      expect(MovyCipher.mix(1), 1364076727);
      expect(MovyCipher.mix(0xdeadbeef), 233162409);
    });

    test('stays inside 32 bits even for inputs that do not', () {
      // Dart ints are 64-bit; every step masks. Without the masks this would
      // silently drift once a multiply overflowed 32 bits.
      for (final input in [0xFFFFFFFF, 0x1FFFFFFFF, -1]) {
        final out = MovyCipher.mix(input);
        expect(out, greaterThanOrEqualTo(0));
        expect(out, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });
  });

  group('MovyCipher.rotl', () {
    test('rotates rather than shifts', () {
      expect(MovyCipher.rotl(1, 1), 2);
      // The bit that falls off the top comes back at the bottom. A plain <<
      // would give 0 here, and the keystream would quietly lose entropy.
      expect(MovyCipher.rotl(0x80000000, 1), 1);
      expect(MovyCipher.rotl(0xdeadbeef, 8), 2914971614);
    });

    test('a zero shift is the identity, not an undefined 32-bit shift', () {
      expect(MovyCipher.rotl(0xdeadbeef, 0), 0xdeadbeef);
      // 32 wraps to 0 through the & 31, so it must behave the same.
      expect(MovyCipher.rotl(0xdeadbeef, 32), 0xdeadbeef);
    });
  });

  group('MovyCipher.fnv1a', () {
    test('known values, including the empty string', () {
      expect(MovyCipher.fnv1a(''), 2872998923);
      expect(MovyCipher.fnv1a('movy'), 4279590934);
      expect(MovyCipher.fnv1a('seed-42'), 1659647982);
    });

    test('one character apart is not one bit apart', () {
      expect(MovyCipher.fnv1a('seed-42'), isNot(MovyCipher.fnv1a('seed-43')));
    });
  });

  group('MovyCipher.keyStream', () {
    test('matches a known stream', () {
      expect(
        MovyCipher.keyStream('seed-42', 603, 8),
        [26, 246, 253, 247, 61, 158, 103, 208],
      );
      expect(MovyCipher.keyStream('', 0, 6), [229, 179, 64, 96, 164, 45]);
    });

    test('a length that is not a multiple of four is respected', () {
      // Each word yields four bytes, so the tail is where an off-by-one would
      // live: a stream one byte too long shifts every XOR after it.
      expect(MovyCipher.keyStream('seed-42', 603, 3), [26, 246, 253]);
      expect(MovyCipher.keyStream('seed-42', 603, 5), [26, 246, 253, 247, 61]);
      expect(MovyCipher.keyStream('seed-42', 603, 0), isEmpty);
    });

    test('is deterministic for the same seed and id', () {
      expect(
        MovyCipher.keyStream('seed-42', 603, 32),
        MovyCipher.keyStream('seed-42', 603, 32),
      );
    });

    test('both the seed and the id change the stream', () {
      expect(
        MovyCipher.keyStream('seed-43', 603, 8),
        [116, 120, 192, 155, 181, 140, 4, 90],
      );
      expect(
        MovyCipher.keyStream('seed-42', 604, 8),
        [48, 65, 129, 88, 66, 66, 1, 153],
      );
    });

    test('a prefix of a longer stream is the shorter stream', () {
      final long = MovyCipher.keyStream('seed-42', 603, 16);
      expect(MovyCipher.keyStream('seed-42', 603, 5), long.sublist(0, 5));
    });
  });

  group('MovyCipher state', () {
    test('each word advances the state', () {
      final state = MovyCipher.initKeyState('seed-42', 603);
      expect(MovyCipher.nextKeystreamWord(state, 0), 4160615962);
      expect(MovyCipher.nextKeystreamWord(state, 1), 3496451645);
    });

    test('a fresh state restarts the stream', () {
      final a = MovyCipher.initKeyState('seed-42', 603);
      final b = MovyCipher.initKeyState('seed-42', 603);
      expect(
        MovyCipher.nextKeystreamWord(a, 0),
        MovyCipher.nextKeystreamWord(b, 0),
      );
    });
  });

  test('the magic prefix is "mvm1"', () {
    // A payload decrypting to anything else means the wrong seed, which the
    // scraper treats as a miss rather than as corrupt input.
    expect(String.fromCharCodes(MovyCipher.magic), 'mvm1');
  });
}
