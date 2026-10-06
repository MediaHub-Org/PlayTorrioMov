// test/models/anime_streaming_episode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';

AnimeStreamingEpisode parse(String title, {String? thumbnail}) =>
    AnimeStreamingEpisode.fromJson({'title': title, 'thumbnail': thumbnail});

void main() {
  group('AnimeStreamingEpisode.fromJson', () {
    test('AniList\'s own convention: "Episode N - Title"', () {
      final ep = parse('Episode 3 - A Dim Light Amid Despair');
      expect(ep.number, 3);
      expect(ep.title, 'A Dim Light Amid Despair');
    });

    test('a colon instead of a dash', () {
      final ep = parse('Ep. 12: The Boy from That Day');
      expect(ep.number, 12);
      expect(ep.title, 'The Boy from That Day');
    });

    test('a bare leading number', () {
      final ep = parse('1. To You, 2000 Years From Now');
      expect(ep.number, 1);
      expect(ep.title, 'To You, 2000 Years From Now');
    });

    test('no recognizable number: kept whole, unmatched', () {
      final ep = parse('Attack on Titan OVA');
      expect(ep.number, isNull);
      expect(ep.title, 'Attack on Titan OVA');
    });

    test('a number with nothing after it falls back to the raw title', () {
      final ep = parse('Episode 5');
      expect(ep.number, 5);
      expect(ep.title, 'Episode 5');
    });

    test('the thumbnail passes through, null when absent', () {
      expect(parse('Episode 1 - X', thumbnail: 'https://x/y.jpg').thumbnail,
          'https://x/y.jpg');
      expect(parse('Episode 1 - X').thumbnail, isNull);
    });
  });

  group('AnimeMedia.episodeInfo', () {
    test('a standalone season: numbers already match 1:1', () {
      const anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [
          AnimeStreamingEpisode(number: 1, title: 'First'),
          AnimeStreamingEpisode(number: 2, title: 'Second'),
        ],
      );
      expect(anime.episodeInfo(2, seasonEpisodes: 2)?.title, 'Second');
      expect(anime.episodeInfo(9, seasonEpisodes: 2), isNull);
    });

    test('an empty list (the common case) always misses', () {
      const anime = AnimeMedia(id: 1);
      expect(anime.episodeInfo(1, seasonEpisodes: 1), isNull);
    });

    test('seasonEpisodes of 0 (unknown, before AniDB resolves it) misses rather than divides by it', () {
      const anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [AnimeStreamingEpisode(number: 1, title: 'First')],
      );
      expect(anime.episodeInfo(1, seasonEpisodes: 0), isNull);
    });

    test(
        'a sequel season numbered as a franchise continuation (My Hero '
        'Academia\'s later seasons, Solo Leveling S2 -- confirmed against '
        'the live AniList API while building this)', () {
      // This season has 3 real episodes; AniList's list for it continues the
      // whole franchise's count, so its own episode 1 is titled "Episode
      // 159". The ids and exact numbers are the real ones for My Hero
      // Academia (AniList 21459): season episodes 1-13 are titled
      // "Episode 139" through "Episode 151" in the real data, this is just
      // a short stand-in with the same shape.
      const anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [
          AnimeStreamingEpisode(number: 159, title: 'Battle Without a Quirk'),
          AnimeStreamingEpisode(number: 160, title: 'Deku vs. Kacchan 2'),
          AnimeStreamingEpisode(number: 161, title: 'Game Over'),
        ],
      );
      expect(anime.episodeInfo(1, seasonEpisodes: 3)?.title, 'Battle Without a Quirk');
      expect(anime.episodeInfo(3, seasonEpisodes: 3)?.title, 'Game Over');
      expect(anime.episodeInfo(4, seasonEpisodes: 3), isNull);
    });

    test('a small fragment of a much longer show is not mistaken for its start '
        '(One Piece: the real streaming data for it is 69 entries numbered '
        '62-130, out of over 1000 episodes)', () {
      // Perfectly self-consistent -- every number is one more than the last
      // -- which is exactly why this is the case worth a test: internal
      // consistency alone said nothing about whether it starts at this
      // season's real episode 1.
      final numbers = List.generate(69, (i) => 62 + i);
      final anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [
          for (final n in numbers) AnimeStreamingEpisode(number: n, title: 'Ep $n'),
        ],
      );
      expect(anime.episodeInfo(1, seasonEpisodes: 1180), isNull);
      expect(anime.episodeInfo(62, seasonEpisodes: 1180), isNull);
    });

    test('a few unrelated numbers do not drag a real offset below the coverage bar', () {
      // This season has 3 real episodes (25-27); one unrelated recap special
      // (numbered 500, from some other continuity entirely) sits alongside
      // them. It does not count against the 3/3 coverage the real episodes
      // give the correct offset, and is itself simply never matched.
      const anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [
          AnimeStreamingEpisode(number: 500, title: 'Recap Special'),
          AnimeStreamingEpisode(number: 25, title: 'First'),
          AnimeStreamingEpisode(number: 26, title: 'Second'),
          AnimeStreamingEpisode(number: 27, title: 'Third'),
        ],
      );
      expect(anime.episodeInfo(1, seasonEpisodes: 3)?.title, 'First');
      expect(anime.episodeInfo(2, seasonEpisodes: 3)?.title, 'Second');
      expect(anime.episodeInfo(3, seasonEpisodes: 3)?.title, 'Third');
    });

    test('an entry with no parsable number is simply never matched', () {
      const anime = AnimeMedia(
        id: 1,
        streamingEpisodes: [
          AnimeStreamingEpisode(number: 1, title: 'First'),
          AnimeStreamingEpisode(title: 'A bonus short with no number'),
        ],
      );
      expect(anime.episodeInfo(1, seasonEpisodes: 2)?.title, 'First');
      expect(anime.episodeInfo(2, seasonEpisodes: 2), isNull);
    });
  });
}
