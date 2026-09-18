/// Builds the obfuscated master-playlist URL that cinesrc.st, cine.su and
/// bcine all resolve to.
///
/// The three sites are one backend behind three front ends: same host, same
/// embedded key, same salt table, same bit-mixing. Each scraper carried its
/// own byte-identical copy of all of it -- about 55 lines of deliberately
/// unreadable arithmetic, three times over, where a change to any one of
/// them (a rotated key, an altered mixing constant) would have had to be
/// found and applied in the other two by someone who noticed they existed.
///
/// The port is 1:1 from the sites' own player bundle, which is why the
/// names are short and the arithmetic is opaque: it has to match theirs
/// bit for bit, so it is transcribed rather than tidied. What differs
/// between the three scrapers is only where they say they came from -- the
/// Referer and Origin headers -- and that stays with each scraper.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

const String _nD = '4860ac8bfddb';
const String _aD =
    '224eff10e662e9635c9f671cf46351dcd69af42b1edd56f5e5fa21751f44b9c8';
const List<int> _ls = [
  17, 91, 203, 44, 8, 177, 62, 239, 119, 3, 154, 81, 28, 210, 101, 7, //
];
const String _wa =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

const String glendaleHost = 'https://glendale-plumbing.com';

/// The cache-busting query the cinesrc front end appends. cine.su does not
/// send it, which is the one behavioral difference between those two.
const String glendaleVersionParam = '_v=34403446';

int _ab(int e) {
  var t = e & 0xFFFFFFFF;
  t ^= (t >> 16);
  t = (t * 2146121005) & 0xFFFFFFFF;
  t ^= (t >> 15);
  t = (t * 2221713035) & 0xFFFFFFFF;
  return (t ^ (t >> 16)) & 0xFFFFFFFF;
}

Uint8List _sD(int e) {
  final t = utf8.encode(_aD);
  final r = (e + 17).clamp(32, 128);
  final n = Uint8List(r);
  var a = 2166136261;
  for (var s = 0; s < r; s++) {
    a ^= t[s % t.length];
    a = _ab(
      (a + _ls[s % _ls.length] + ((2654435761 * s) & 0xFFFFFFFF)) & 0xFFFFFFFF,
    );
    n[s] = a & 255;
  }
  return n;
}

String _iD(Uint8List e) {
  var t = '';
  for (var r = 0; r < e.length; r += 3) {
    final n = e[r];
    final a = (r + 1 < e.length) ? e[r + 1] : null;
    final s = (r + 2 < e.length) ? e[r + 2] : null;
    t += _wa[n >> 2];
    t += _wa[((3 & n) << 4) | ((a ?? 0) >> 4)];
    if (a == null) break;
    t += _wa[((15 & a) << 2) | ((s ?? 0) >> 6)];
    if (s == null) break;
    t += _wa[63 & s];
  }
  return t;
}

/// The master.m3u8 URL for a title, by TMDB id.
///
/// Pass both [season] and [episode] for a series; either being null means
/// a film, which the payload encodes as season 0 episode 0.
String glendaleMasterUrl(int tmdbId, int? season, int? episode) {
  final isTv = season != null && episode != null;
  // Named in full rather than `s`/`e`: the payload below also contains a
  // literal 's'/'m' discriminator, and one-letter names next to it read as
  // the same thing.
  final seasonPart = isTv ? season : 0;
  final episodePart = isTv ? episode : 0;

  final str = '$_nD:${isTv ? 's' : 'm'}:$tmdbId:$seasonPart:$episodePart';
  final a = utf8.encode(str);
  final sArr = _sD(a.length);
  final i = Uint8List(a.length + 2);
  i[0] = a.length & 255;
  i[1] = (a.length >> 8) & 255;
  var o = (2654435769 ^ a.length) & 0xFFFFFFFF;
  for (var l = 0; l < a.length; l++) {
    o = _ab((o + sArr[l % sArr.length] + _ls[l % _ls.length] + l) & 0xFFFFFFFF);
    i[l + 2] = (a[l] ^ (255 & o)) ^ sArr[(7 * l + 3) % sArr.length];
  }

  return '$glendaleHost/c/v1/${_iD(i)}/master.m3u8';
}
