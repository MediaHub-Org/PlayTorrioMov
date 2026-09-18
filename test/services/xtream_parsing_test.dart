// test/services/xtream_parsing_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/iptv/iptv_models.dart';
import 'package:playtorriomov/services/iptv/iptv_network.dart';

/// Xtream's `player_api.php`, parsed offline.
///
/// This is a format rather than a website: hundreds of separate panel
/// installations answer it, which is exactly why it is worth pinning. They
/// disagree with each other constantly -- on which key holds the id, on
/// whether a number arrives as a number or a string, on whether EPG text is
/// base64 -- and every one of those disagreements is already handled in the
/// parser. None of it was covered, because reaching any of it needed a live
/// portal with working credentials.
///
/// What makes the gap matter: every one of these returns an empty list on
/// anything it cannot read. A panel whose shape we mishandle is
/// indistinguishable, in the UI, from a panel with no channels.
void main() {
  String b64(String s) => base64.encode(utf8.encode(s));

  group('parseLogin', () {
    test('accepts the user_info wrapper most panels send', () {
      final info = IptvClient.parseLogin(
        '{"user_info":{"username":"bob","auth":1,"status":"Active"}}',
      );

      expect(info, isNotNull);
      expect(info!['username'], 'bob');
    });

    test('accepts a flat response too', () {
      // Some panels answer without the wrapper. Rejecting those would read as
      // a wrong password to the user.
      final info = IptvClient.parseLogin('{"username":"bob","auth":"1"}');

      expect(info, isNotNull);
      expect(info!['username'], 'bob');
    });

    test('status Active alone is enough, and so is auth 1 alone', () {
      expect(IptvClient.parseLogin('{"status":"Active"}'), isNotNull);
      expect(IptvClient.parseLogin('{"auth":"1"}'), isNotNull);
    });

    test('a rejected login is null, not an empty account', () {
      expect(IptvClient.parseLogin('{"user_info":{"auth":0}}'), isNull);
      expect(
        IptvClient.parseLogin('{"user_info":{"auth":1,"status":"Expired"}}'),
        isNotNull,
        reason: 'auth 1 still counts, whatever status says',
      );
      expect(IptvClient.parseLogin('{"user_info":{"status":"Banned"}}'), isNull);
    });

    test('a parked domain answering HTML is a failed login, not a crash', () {
      expect(IptvClient.parseLogin('<html><body>For sale</body></html>'), isNull);
      expect(IptvClient.parseLogin(''), isNull);
      expect(IptvClient.parseLogin('[]'), isNull);
    });
  });

  group('formatExpiry', () {
    test('formats Unix seconds', () {
      // Midday UTC on purpose: the formatter renders in local time, so a
      // midnight timestamp would land on the previous day for any runner west
      // of UTC and make this test a travel hazard rather than a check.
      expect(IptvClient.formatExpiry('1893499200'), '01 Jan 2030');
    });

    test('a line with no expiry reads as Unlimited', () {
      expect(IptvClient.formatExpiry(null), 'Unlimited');
      expect(IptvClient.formatExpiry(''), 'Unlimited');
      expect(IptvClient.formatExpiry('null'), 'Unlimited');
    });
  });

  group('parseCategories', () {
    test('reads id and name', () {
      final cats = IptvClient.parseCategories(
        '[{"category_id":"1","category_name":"Sports"},'
        '{"category_id":2,"category_name":"News"}]',
      );

      expect(cats.map((c) => c.id), ['1', '2']);
      expect(cats.map((c) => c.name), ['Sports', 'News']);
    });

    test('an error object instead of an array yields nothing', () {
      expect(IptvClient.parseCategories('{"error":"no access"}'), isEmpty);
      expect(IptvClient.parseCategories('not json'), isEmpty);
    });
  });

  group('parseStreams', () {
    test('live streams default to a ts container', () {
      // The container extension is what streamUrl builds the playback path
      // from, so an absent one has to become something playable rather than
      // leaving a URL ending in a dot.
      final streams = IptvClient.parseStreams(
        '[{"stream_id":5,"name":"BBC One","stream_icon":"https://x/i.png",'
        '"category_id":"1","epg_channel_id":"bbc.uk"}]',
        IptvSection.live,
      );

      expect(streams.single.streamId, '5');
      expect(streams.single.containerExt, 'ts');
      expect(streams.single.kind, 'live');
      expect(streams.single.epgChannelId, 'bbc.uk');
    });

    test('VOD keeps its own container and falls back to mp4', () {
      final streams = IptvClient.parseStreams(
        '[{"stream_id":1,"name":"A","container_extension":"mkv"},'
        '{"stream_id":2,"name":"B"},'
        '{"stream_id":3,"name":"C","container_extension":""}]',
        IptvSection.vod,
      );

      expect(streams.map((s) => s.containerExt), ['mkv', 'mp4', 'mp4']);
    });

    test('series are identified by series_id', () {
      final streams = IptvClient.parseStreams(
        '[{"series_id":77,"name":"A Show","cover":"https://x/c.png"}]',
        IptvSection.series,
      );

      expect(streams.single.streamId, '77');
      expect(streams.single.icon, 'https://x/c.png');
      expect(streams.single.kind, 'series');
    });

    test('the second spelling of every field is accepted', () {
      // id/title/cover instead of stream_id/name/stream_icon. A panel using
      // these is not broken, it is different panel software -- and before the
      // fallbacks it produced a list of blank rows that played nothing.
      final streams = IptvClient.parseStreams(
        '[{"id":9,"title":"Channel Nine","cover":"https://x/c.png"}]',
        IptvSection.live,
      );

      expect(streams.single.streamId, '9');
      expect(streams.single.name, 'Channel Nine');
      expect(streams.single.icon, 'https://x/c.png');
    });

    test('an error object yields nothing', () {
      expect(IptvClient.parseStreams('{"error":1}', IptvSection.live), isEmpty);
    });
  });

  group('parseSeriesEpisodes', () {
    const body = '''
    {"episodes":{
      "2":[{"id":"20","title":"S2E2","episode_num":2,
            "container_extension":"mkv","info":{"plot":"Later","movie_image":"https://x/2.png"}},
           {"id":"19","title":"S2E1","episode_num":"1"}],
      "1":[{"id":"10","title":"S1E1","episode_num":1}]
    }}''';

    test('the season comes from the object key, not a field', () {
      final eps = IptvClient.parseSeriesEpisodes(body);

      expect(eps.map((e) => '${e.season}x${e.episode}'), [
        '1x1',
        '2x1',
        '2x2',
      ], reason: 'sorted by season then episode, whatever key order arrived');
    });

    test('episode_num is read as a number or a string', () {
      final eps = IptvClient.parseSeriesEpisodes(body);
      final s2 = eps.where((e) => e.season == 2).toList();

      expect(s2.map((e) => e.episode), [1, 2]);
    });

    test('nested info is optional', () {
      final eps = IptvClient.parseSeriesEpisodes(body);
      final withInfo = eps.firstWhere((e) => e.id == '20');
      final without = eps.firstWhere((e) => e.id == '10');

      expect(withInfo.plot, 'Later');
      expect(withInfo.image, 'https://x/2.png');
      expect(without.plot, '');
      expect(without.containerExt, 'mp4', reason: 'default when absent');
    });

    test('a series with no episodes object yields nothing', () {
      expect(IptvClient.parseSeriesEpisodes('{"info":{}}'), isEmpty);
      expect(IptvClient.parseSeriesEpisodes('[]'), isEmpty);
    });
  });

  group('parseShortEpg', () {
    test('reads the epg_listings wrapper', () {
      final epg = IptvClient.parseShortEpg(
        '{"epg_listings":[{"title":"${b64('The News')}",'
        '"description":"${b64('Headlines')}",'
        '"start_timestamp":"1893456000","stop_timestamp":"1893459600"}]}',
      );

      expect(epg.single.title, 'The News');
      expect(epg.single.description, 'Headlines');
    });

    test('reads a bare array too', () {
      final epg = IptvClient.parseShortEpg(
        '[{"title":"${b64('The News')}","description":"",'
        '"start_timestamp":"1893456000","stop_timestamp":"1893459600"}]',
      );

      expect(epg, hasLength(1));
    });

    test('text that is not base64 is kept as it is', () {
      // Not every panel encodes. Decoding blindly turned a readable title into
      // mojibake, so the raw string stands when the decode fails.
      final epg = IptvClient.parseShortEpg(
        '[{"title":"Plain Title","description":"",'
        '"start_timestamp":"1893456000","stop_timestamp":"1893459600"}]',
      );

      expect(epg.single.title, 'Plain Title');
    });

    test('the datetime spelling of the times works as well as epoch', () {
      final epg = IptvClient.parseShortEpg(
        '[{"title":"","description":"",'
        '"start":"2030-01-01 00:00:00","end":"2030-01-01 01:00:00"}]',
      );

      expect(epg, hasLength(1));
      expect(epg.single.stop.difference(epg.single.start).inMinutes, 60);
    });

    test('entries are sorted, and ones without usable times are dropped', () {
      // A program shown at the wrong time is worse than one not shown.
      final epg = IptvClient.parseShortEpg(
        '[{"title":"","description":"","start_timestamp":"1893459600","stop_timestamp":"1893463200"},'
        '{"title":"","description":"","start_timestamp":"1893456000","stop_timestamp":"1893459600"},'
        '{"title":"","description":"","start_timestamp":"not a time"}]',
      );

      expect(epg, hasLength(2));
      expect(epg.first.start.isBefore(epg.last.start), isTrue);
    });

    test('an unreadable body yields nothing', () {
      expect(IptvClient.parseShortEpg('<html>error</html>'), isEmpty);
      expect(IptvClient.parseShortEpg('{"epg_listings":null}'), isEmpty);
    });
  });

  group('playback URLs', () {
    const portal = IptvPortal(
      url: 'http://panel.example:8080',
      username: 'user name',
      password: 'p@ss/word',
      source: 'test',
    );

    test('credentials with URL-unsafe characters are encoded', () {
      // A password with a slash in it would otherwise invent a path segment.
      final url = IptvClient.streamUrl(
        portal,
        const IptvStream(
          streamId: '5',
          name: 'A',
          icon: '',
          categoryId: '1',
          containerExt: 'ts',
          kind: 'live',
          epgChannelId: '',
        ),
      );

      expect(url, 'http://panel.example:8080/live/user%20name/p%40ss%2Fword/5.ts');
    });

    test('VOD and series use their own path segments', () {
      final vod = IptvClient.streamUrl(
        portal,
        const IptvStream(
          streamId: '7',
          name: 'A',
          icon: '',
          categoryId: '1',
          containerExt: 'mp4',
          kind: 'vod',
          epgChannelId: '',
        ),
      );
      final episode = IptvClient.episodeUrl(
        portal,
        const IptvEpisode(
          id: '9',
          title: 'E',
          containerExt: 'mkv',
          season: 1,
          episode: 1,
          plot: '',
          image: '',
        ),
      );

      expect(vod, contains('/movie/'));
      expect(vod, endsWith('/7.mp4'));
      expect(episode, contains('/series/'));
      expect(episode, endsWith('/9.mkv'));
    });

    test('a series row has no direct stream URL', () {
      // Series are containers; the episode is what plays.
      final url = IptvClient.streamUrl(
        portal,
        const IptvStream(
          streamId: '7',
          name: 'A',
          icon: '',
          categoryId: '1',
          containerExt: '',
          kind: 'series',
          epgChannelId: '',
        ),
      );

      expect(url, isEmpty);
    });
  });
}
