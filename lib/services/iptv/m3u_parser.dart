// Standard M3U / M3U8 extended playlist parser.

import '../../models/iptv/m3u_models.dart';

class M3uParser {
  /// Parse raw playlist text into a list of channels. Throws [FormatException]
  /// if the content does not look like an M3U playlist at all.
  static List<M3uChannel> parse(String content) {
    if (content.isEmpty) {
      throw const FormatException('Playlist is empty');
    }
    final text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');

    final out = <M3uChannel>[];
    String? pendingName;
    String pendingLogo = '';
    String pendingGroup = '';
    String pendingTvgId = '';
    String pendingTvgName = '';

    void resetPending() {
      pendingName = null;
      pendingLogo = '';
      pendingGroup = '';
      pendingTvgId = '';
      pendingTvgName = '';
    }

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTM3U')) {
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        final commaIdx = line.indexOf(',');
        final attrPart = commaIdx > 0
            ? line.substring('#EXTINF'.length, commaIdx)
            : line.substring('#EXTINF'.length);
        final namePart = commaIdx > 0 ? line.substring(commaIdx + 1).trim() : '';

        final attrs = _parseAttrs(attrPart);
        pendingTvgId = attrs['tvg-id'] ?? '';
        pendingTvgName = attrs['tvg-name'] ?? '';
        pendingLogo = attrs['tvg-logo'] ?? '';
        pendingGroup = attrs['group-title'] ?? '';
        pendingName = namePart.isNotEmpty
            ? namePart
            : (pendingTvgName.isNotEmpty ? pendingTvgName : 'Unknown');
        continue;
      }

      if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim();
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      final url = line;
      if (!_looksLikeUrl(url)) {
        // Not a URL we recognize — discard whatever EXTINF metadata was
        // pending so it doesn't leak onto an unrelated line further down.
        resetPending();
        continue;
      }

      out.add(M3uChannel(
        name: pendingName ?? url,
        url: url,
        logo: pendingLogo,
        group: pendingGroup,
        tvgId: pendingTvgId,
        tvgName: pendingTvgName,
      ));
      resetPending();
    }

    if (out.isEmpty) {
      throw const FormatException(
          'No channels found — is this a valid M3U playlist?');
    }
    return out;
  }

  static bool _looksLikeUrl(String s) {
    final lower = s.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('rtmp://') ||
        lower.startsWith('rtmps://') ||
        lower.startsWith('rtsp://') ||
        lower.startsWith('udp://') ||
        lower.startsWith('rtp://') ||
        lower.startsWith('mms://') ||
        lower.startsWith('mmsh://');
  }

  static Map<String, String> _parseAttrs(String input) {
    final result = <String, String>{};
    var s = input.trim();
    if (s.startsWith(':')) s = s.substring(1).trim();
    final durMatch = RegExp(r'^-?\d+(\.\d+)?').firstMatch(s);
    if (durMatch != null) {
      s = s.substring(durMatch.end).trim();
    }

    final re = RegExp(r'''([a-zA-Z0-9_\-]+)=("([^"]*)"|'([^']*)'|([^\s,]+))''');
    for (final m in re.allMatches(s)) {
      final key = m.group(1)!.toLowerCase();
      final v = m.group(3) ?? m.group(4) ?? m.group(5) ?? '';
      result[key] = v;
    }
    return result;
  }
}
