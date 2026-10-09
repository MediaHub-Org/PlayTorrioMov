import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'debrid_service.dart';

/// Which torrents the viewer's debrid service already has, so the source list
/// can say so and put them first.
///
/// This is the difference between a torrent that starts in a second or two, as
/// a plain file from the provider's servers, and one the provider has to
/// download first -- minutes, and the app waits for it. Seeders stop
/// mattering for a cached one, which is the whole case for debrid on a slow
/// connection or a TV.
///
/// **It only ever says yes.** A source is marked cached when the provider
/// listed it; a source it did not list is simply not marked. A provider whose
/// lookup is down, changed shape or does not exist yields no marks at all
/// rather than a wrong "not cached", and the list looks as it did before.
///
/// **Provider support, and how sure each is.** Real-Debrid has no lookup: it
/// switched its `instantAvailability` endpoint off in November 2024 and, as
/// far as could be found, has not restored it, so the service does not ask. TorBox, Premiumize, AllDebrid and Debrid-Link are
/// implemented against their documented lookups, but none of the four has been
/// called with a real account from here, so the parsers below read the
/// responses tolerantly (an unrecognized shape is "no marks", logged) and a
/// failing provider is left alone for [_backoff] instead of being asked again
/// for every batch of sources.
class DebridCacheService {
  DebridCacheService._();
  static final DebridCacheService instance = DebridCacheService._();

  /// How long an answer is trusted. A torrent cached now stays cached for much
  /// longer than this; the limit is so one that was not cached when the list
  /// opened can show up as the viewer comes back to it.
  static const Duration _ttl = Duration(minutes: 15);

  /// Hashes per request. The providers cap this (TorBox at 100); well under
  /// keeps every URL short.
  static const int _chunk = 40;

  /// After a provider fails, how long before it is asked again.
  static const Duration _backoff = Duration(minutes: 10);

  static const Duration _timeout = Duration(seconds: 15);

  /// Bumped when new answers arrive, for a list that needs to re-rank.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final Map<String, _Answer> _answers = {};
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};

  /// Whether [infoHash] is known to be cached on the viewer's service, or null
  /// when nothing is known (not asked, not listed, or the lookup failed).
  bool? isCached(String? infoHash) {
    final hash = normalizeInfoHash(infoHash);
    if (hash == null) return null;
    final answer = _answers[hash];
    if (answer == null || _isStale(answer)) return null;
    return answer.cached ? true : null;
  }

  /// Every hash currently known to be cached, for ranking.
  Set<String> get cachedHashes => {
    for (final e in _answers.entries)
      if (e.value.cached && !_isStale(e.value)) e.key,
  };

  bool _isStale(_Answer a) => DateTime.now().difference(a.at) > _ttl;

  /// Asks the viewer's debrid service about [infoHashes] it has not answered
  /// yet. Returns when done; safe to call with a hash twice and from several
  /// places. Does nothing without a configured service.
  Future<void> prefetch(Iterable<String?> infoHashes) async {
    final wanted = <String>{
      for (final raw in infoHashes)
        if (normalizeInfoHash(raw) case final hash?)
          if (!_inFlight.contains(hash) &&
              (_answers[hash] == null || _isStale(_answers[hash]!)))
            hash,
    };
    if (wanted.isEmpty) return;

    final debrid = DebridService();
    final service = await debrid.getSelectedService();
    if (service == 'None' || service.isEmpty) return;
    if (!await debrid.hasKeyForService(service)) return;
    final failed = _failedAt[service];
    if (failed != null && DateTime.now().difference(failed) < _backoff) return;

    final key = await _keyFor(debrid, service);
    if (key == null) return;

    final hashes = wanted.toList();
    _inFlight.addAll(hashes);
    try {
      for (var i = 0; i < hashes.length; i += _chunk) {
        final chunk = hashes.sublist(
          i,
          i + _chunk > hashes.length ? hashes.length : i + _chunk,
        );
        final cached = await _lookup(service, key, chunk);
        if (cached == null) {
          _failedAt[service] = DateTime.now();
          return;
        }
        final now = DateTime.now();
        for (final hash in chunk) {
          _answers[hash] = _Answer(cached.contains(hash), now);
        }
        changes.value++;
      }
    } finally {
      _inFlight.removeAll(hashes);
    }
  }

  /// Marks [infoHashes] cached without asking anyone, for tests of what the
  /// answer changes.
  @visibleForTesting
  void debugMarkCached(Iterable<String> infoHashes) {
    final now = DateTime.now();
    for (final raw in infoHashes) {
      final hash = normalizeInfoHash(raw);
      if (hash != null) _answers[hash] = _Answer(true, now);
    }
    changes.value++;
  }

  /// Forgets every answer, for a viewer who changed service.
  void clear() {
    _answers.clear();
    _failedAt.clear();
    changes.value++;
  }

  Future<String?> _keyFor(DebridService debrid, String service) async {
    return switch (service) {
      'TorBox' => await debrid.torBox.getKey(),
      'Premiumize' => await debrid.premiumize.getKey(),
      'AllDebrid' => await debrid.allDebrid.getKey(),
      'Debrid-Link' => await debrid.debridLink.getKey(),
      // Real-Debrid: no lookup exists, so there is nothing to ask.
      _ => null,
    };
  }

  /// The hashes of [chunk] the service lists as cached, or null when the
  /// lookup failed or came back in a shape this does not recognize.
  Future<Set<String>?> _lookup(
    String service,
    String key,
    List<String> chunk,
  ) async {
    try {
      final request = buildRequest(service, key, chunk);
      if (request == null) return null;
      final res = await http
          .get(request.uri, headers: request.headers)
          .timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('[DebridCache] $service answered ${res.statusCode}');
        return null;
      }
      final parsed = parseResponse(service, json.decode(res.body), chunk);
      if (parsed == null) {
        debugPrint('[DebridCache] $service answered in an unknown shape');
      }
      return parsed;
    } catch (e) {
      debugPrint('[DebridCache] $service lookup failed: $e');
      return null;
    }
  }

  // ── Pure parts, kept apart so they can be tested without a network ────────

  /// A 40-character hex info hash, lower-cased, or null for anything else (a
  /// base-32 hash, a magnet link, nothing).
  @visibleForTesting
  static String? normalizeInfoHash(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || !RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  /// The request for [service], or null when it has no lookup.
  @visibleForTesting
  static ({Uri uri, Map<String, String> headers})? buildRequest(
    String service,
    String key,
    List<String> hashes,
  ) {
    switch (service) {
      case 'TorBox':
        return (
          uri: Uri.https('api.torbox.app', '/v1/api/torrents/checkcached', {
            'hash': hashes.join(','),
            'format': 'object',
            'list_files': 'false',
          }),
          headers: {'Authorization': 'Bearer $key'},
        );
      case 'Premiumize':
        // The repeated `items[]` key is how the API takes a list; Uri's map
        // form cannot repeat a key, so the query is written out.
        final items = hashes.map((h) => 'items%5B%5D=$h').join('&');
        return (
          uri: Uri.parse(
            'https://www.premiumize.me/api/cache/check'
            '?apikey=${Uri.encodeQueryComponent(key)}&$items',
          ),
          headers: const <String, String>{},
        );
      case 'AllDebrid':
        final magnets = hashes.map((h) => 'magnets%5B%5D=$h').join('&');
        return (
          uri: Uri.parse(
            'https://api.alldebrid.com/v4/magnet/instant'
            '?agent=PlayTorrio&$magnets',
          ),
          headers: {'Authorization': 'Bearer $key'},
        );
      case 'Debrid-Link':
        return (
          uri: Uri.https('debrid-link.com', '/api/v2/seedbox/cached', {
            'url': hashes.join(','),
          }),
          headers: {'Authorization': 'Bearer $key'},
        );
      default:
        return null;
    }
  }

  /// The cached hashes in a decoded [body] from [service], or null when it is
  /// not the shape that service's lookup documents. [asked] is the list the
  /// request carried, which Premiumize answers by position.
  @visibleForTesting
  static Set<String>? parseResponse(
    String service,
    dynamic body,
    List<String> asked,
  ) {
    if (body is! Map) return null;
    switch (service) {
      case 'TorBox':
        if (body['success'] != true) return null;
        return _hashesIn(body['data'], allowEmpty: true);
      case 'Premiumize':
        if (body['status'] != 'success') return null;
        final flags = body['response'];
        if (flags is! List || flags.length != asked.length) return null;
        return {
          for (var i = 0; i < flags.length; i++)
            if (flags[i] == true) asked[i],
        };
      case 'AllDebrid':
        if (body['status'] != 'success') return null;
        final data = body['data'];
        final magnets = data is Map ? data['magnets'] : null;
        if (magnets is! List) return null;
        final out = <String>{};
        for (final entry in magnets) {
          if (entry is! Map || entry['instant'] != true) continue;
          final hash = _firstHash(entry['hash']) ?? _firstHash(entry['magnet']);
          if (hash != null) out.add(hash);
        }
        return out;
      case 'Debrid-Link':
        if (body['success'] != true) return null;
        return _hashesIn(body['value'], allowEmpty: true);
      default:
        return null;
    }
  }

  /// Hashes named by a provider's "what is cached" payload, which is a map
  /// keyed by hash or a list of them (or of objects carrying one). Nothing
  /// cached comes back as an empty collection, `null` or `false`, all of which
  /// are "none"; anything else is not understood.
  static Set<String>? _hashesIn(dynamic value, {required bool allowEmpty}) {
    if (value == null || value == false) return allowEmpty ? <String>{} : null;
    if (value is Map) {
      return {
        for (final k in value.keys)
          if (_firstHash(k.toString()) case final h?) h,
      };
    }
    if (value is List) {
      final out = <String>{};
      for (final item in value) {
        final hash = item is Map
            ? _firstHash(item['hash'])
            : _firstHash(item.toString());
        if (hash != null) out.add(hash);
      }
      return out;
    }
    return null;
  }

  /// The info hash in [value]: itself when it is one, or the one inside a
  /// magnet link.
  static String? _firstHash(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    final direct = normalizeInfoHash(text);
    if (direct != null) return direct;
    final inMagnet = RegExp(
      r'btih:([0-9a-fA-F]{40})',
    ).firstMatch(text)?.group(1);
    return inMagnet?.toLowerCase();
  }
}

class _Answer {
  final bool cached;
  final DateTime at;

  const _Answer(this.cached, this.at);
}
