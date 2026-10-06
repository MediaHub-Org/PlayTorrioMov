@Tags(['network'])
library;

// Regression guard for two real, stable AniList ids `AnimeMedia.episodeInfo`'s
// offset detection was built and corrected against:
//  - My Hero Academia (21459): a sequel season numbered as a franchise
//    continuation -- this season's own episode 1 is titled "Episode 139".
//  - One Piece (21): the opposite failure mode, caught on a second pass --
//    a small, internally consistent but unrelated fragment of streamingEpisodes
//    (69 entries numbered 62-130, out of over 1000) that a naive offset
//    confidently matched to episode 1, showing episode 130's art instead.
// This pins the live API still agreeing with the unit tests built against a
// snapshot of it.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/anime/anilist_service.dart';

void main() {
  test('My Hero Academia (AniList 21459): episode 1 resolves through the offset',
      () async {
    final anime = await AnilistService.instance.fetchAnimeDetails(21459);
    expect(anime, isNotNull);
    expect(anime!.streamingEpisodes, isNotEmpty,
        reason: 'AniList dropped this show\'s streaming episodes -- '
            'nothing left to regress against, not a failure of the offset '
            'logic itself');
    expect(
        anime.episodeInfo(1, seasonEpisodes: anime.totalEpisodes),
        isNotNull,
        reason: 'episode 1 did not resolve -- the continuation-numbering '
            'offset this show is the known example of is not being applied');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test(
      'One Piece (AniList 21): a small unrelated fragment of streamingEpisodes '
      'is not mistaken for the start of a 1000+ episode season', () async {
    final anime = await AnilistService.instance.fetchAnimeDetails(21);
    expect(anime, isNotNull);
    expect(anime!.streamingEpisodes, isNotEmpty,
        reason: 'the real fixture this guards against -- a small, oddly '
            'placed fragment -- is gone; nothing left to regress against');
    // AniList does not know One Piece's own episode count (an ongoing
    // 1000+ episode show); the app reads that from AniDB instead, so a
    // plausible real count stands in for it here.
    expect(anime.episodeInfo(1, seasonEpisodes: 1180), isNull,
        reason: 'matched something for episode 1 out of a tiny unrelated '
            'fragment of the real season -- showing the wrong episode\'s '
            'art is worse than showing none');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
