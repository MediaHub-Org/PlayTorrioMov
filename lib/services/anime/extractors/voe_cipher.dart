// lib/services/anime/extractors/voe_cipher.dart
import 'dart:convert';

/// The obfuscation VOE wraps its stream payload in, on its own.
///
/// Six reversible steps, each one undoing something the page's JavaScript
/// did. Lifted out of `AniHQExtractor._extractVoe` unchanged, for the same
/// reason `MovyCipher` was lifted out of `MovyScraper`: it is arithmetic on a
/// string, it has no business needing a live site to exercise, and the only
/// way to reach it before was to run the whole fetch-decrypt pipeline against
/// a host that rewrites its obfuscation whenever it feels like it.
///
/// Being reversible is what makes it testable without a fixture: a test can
/// build a payload with [obfuscate] and check that [decode] gets the original
/// back, which pins every step against its own inverse rather than against
/// one day's capture.
abstract final class VoeCipher {
  /// Markers sprinkled through the payload purely to break naive base64
  /// decoding. They are removed, never decoded.
  static const junk = ['@\$', '^^', '~@', '%?', '*~', '!!', '#&'];

  /// Letters rotated by 13; everything else, punctuation and digits included,
  /// passes through. Its own inverse.
  static String rot13(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        out.writeCharCode(((code - 65 + 13) % 26) + 65);
      } else if (code >= 97 && code <= 122) {
        out.writeCharCode(((code - 97 + 13) % 26) + 97);
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  /// Shifts every code unit by [by]. The payload shifts down by 3 on the way
  /// out, so the page shifted up by 3 on the way in.
  static String shiftCodeUnits(String s, int by) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      out.writeCharCode(s.codeUnitAt(i) + by);
    }
    return out.toString();
  }

  /// Unwraps [raw] — the contents of the page's `application/json` script tag
  /// — back to the decoded JSON, or null if it is not a VOE payload.
  ///
  /// Never throws. Every step can fail on a page whose obfuscation has moved
  /// on, and the caller's answer to all of them is the same: this extractor
  /// has no stream, try the next.
  static dynamic decode(String raw) {
    try {
      var str = rot13(raw);
      for (final j in junk) {
        str = str.replaceAll(j, '');
      }

      final once = utf8.decode(base64.decode(base64.normalize(str)));
      final shifted = shiftCodeUnits(once, -3);
      final reversed = shifted.split('').reversed.join();

      return jsonDecode(utf8.decode(base64.decode(base64.normalize(reversed))));
    } catch (_) {
      // The site changed its obfuscation, or this was never a VOE payload.
      return null;
    }
  }

  /// The stream URL out of a decoded payload.
  ///
  /// VOE spells the same field `file` on some pages and `source` on others.
  static String? streamUrl(dynamic decoded) {
    if (decoded is! Map) return null;
    final url = decoded['file'] ?? decoded['source'];
    if (url == null) return null;
    final text = url.toString();
    return text.isEmpty ? null : text;
  }

  /// The inverse of [decode], so a test can build a payload rather than
  /// capture one. Not used in production.
  /// Named for the step of [decode] each value feeds, read bottom-up: the
  /// inner base64 is what decode's last step reads, and so on outwards.
  static String obfuscate(Object json) {
    final innerBase64 = base64.encode(utf8.encode(jsonEncode(json)));
    final beforeReversing = innerBase64.split('').reversed.join();
    final beforeShiftingDown = shiftCodeUnits(beforeReversing, 3);
    return rot13(base64.encode(utf8.encode(beforeShiftingDown)));
  }
}
