// Movy's stream cipher, lifted out of the scraper so it can be tested
// without the network.
//
// It was five private statics inside `MovyScraper`, reachable only by running
// the whole fetch-decrypt pipeline against a live site -- which is a
// `@Tags(['network'])` test, excluded from CI. So the one part of that scraper
// that is pure, deterministic arithmetic, and the part most likely to break
// silently under a Dart change to integer semantics, was the part never
// checked by a run that gates a merge.
//
// Nothing here is changed from the original: same constants, same order, same
// masking. The point is only that it is now reachable.

import 'dart:typed_data';

/// Mutable keystream state. `next` advances it, so a generator is single-use.
class MovyKeyState {
  MovyKeyState(this.s, this.isSet, this.acc);

  final List<int> s;
  final List<bool> isSet;
  int acc;
}

abstract final class MovyCipher {
  static const int _mask = 0xFFFFFFFF;

  /// The magic prefix a decrypted payload must start with: "mvm1". A body
  /// that decrypts to anything else means the wrong seed, not corrupt input.
  static const List<int> magic = [109, 118, 109, 49];

  /// MurmurHash3's finalizer, 32-bit.
  static int mix(int e) {
    var v = e & _mask;
    v = (v ^ (v >>> 16)) & _mask;
    v = (v * 0x85ebca6b) & _mask;
    v = (v ^ (v >>> 13)) & _mask;
    v = (v * 0xc2b2ae35) & _mask;
    return (v ^ (v >>> 16)) & _mask;
  }

  /// Rotate left, 32-bit. A shift of 0 is the identity -- shifting right by
  /// 32 would be undefined, which is why the branch exists.
  static int rotl(int e, int t) {
    final shift = t & 31;
    if (shift == 0) return e & _mask;
    return (((e << shift) & _mask) | ((e & _mask) >>> (32 - shift))) & _mask;
  }

  /// FNV-1a over the code units, finished through [mix].
  static int fnv1a(String str) {
    var t = 0x811c9dc5;
    for (var i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      t = (((t ^ code) & _mask) * 0x1000193) & _mask;
    }
    return mix(t);
  }

  /// Seed the 61-slot table from the site's seed and the TMDB id.
  static MovyKeyState initKeyState(String seed, int tmdbId) {
    final s = List<int>.filled(61, 0);
    final isSet = List<bool>.filled(61, false);
    var r = mix(fnv1a(seed) ^ mix((tmdbId & _mask) ^ 0x9e3779b9));

    for (var e = 0; e < 8; e++) {
      final t = r % 61;
      r = rotl((r + 0x9e3779b9) & _mask, 7 + (7 & e));
      s[t] = (r ^ mix(r)) & _mask;
      isSet[t] = true;
      r = mix((r + t) & _mask);
    }

    return MovyKeyState(s, isSet, mix(0xa5a5a5a5 ^ r));
  }

  /// One 32-bit word, advancing [state].
  static int nextKeystreamWord(MovyKeyState state, int t) {
    final r = state.s;
    var nState = state.acc;
    final i = nState % 61;
    final oVal = state.isSet[i] ? -1 : 0;
    final d = state.isSet[i] ? r[i] : 0;
    final c = ((t + 1) * 0x9e3779b9) & _mask;
    final a = nState;
    final sVal = d ^ c;
    final h = ((a ^ sVal) | (a & sVal & oVal)) & _mask;
    final term1 = rotl((h + nState) & _mask, 31 & i);
    final term2 = rotl(nState, 31 & (i * 7));
    nState = mix(((term1 ^ term2) + 0x9e3779b9) & _mask);
    r[i] = nState;
    state.isSet[i] = true;
    state.acc = nState;
    return nState & _mask;
  }

  /// [len] keystream bytes, little-endian within each word.
  static Uint8List keyStream(String seed, int tmdbId, int len) {
    final state = initKeyState(seed, tmdbId);
    final out = Uint8List(len);
    var wordIdx = 0;
    var byteIdx = 0;

    while (byteIdx < len) {
      final word = nextKeystreamWord(state, wordIdx++);
      out[byteIdx++] = word & 0xFF;
      if (byteIdx < len) out[byteIdx++] = (word >>> 8) & 0xFF;
      if (byteIdx < len) out[byteIdx++] = (word >>> 16) & 0xFF;
      if (byteIdx < len) out[byteIdx++] = (word >>> 24) & 0xFF;
    }
    return out;
  }
}
