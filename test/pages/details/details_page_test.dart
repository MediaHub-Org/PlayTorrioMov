import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/pages/details/details_page.dart';

/// The season a details page opens on. Season 0 is specials, and most shows
/// carry little or nothing there -- opening on it reads as an empty episode
/// rail, which is how "no episodes" reports started.
void main() {
  group('DetailsPage.initialSeason', () {
    test('skips the specials for the first real season', () {
      expect(
        DetailsPage.initialSeason([0, 1, 2, 3, 4, 5, 6, 7, 8]),
        1,
      );
    });

    test('a title with only specials still opens on what it has', () {
      expect(DetailsPage.initialSeason([0]), 0);
    });

    test('no seasons is no selection', () {
      expect(DetailsPage.initialSeason(const []), isNull);
    });

    test('a sorted list without specials opens on its first season', () {
      expect(DetailsPage.initialSeason([1, 2, 3]), 1);
      expect(DetailsPage.initialSeason([2]), 2);
    });

    test('null entries are ignored, not selected', () {
      expect(DetailsPage.initialSeason([null, 0, 2]), 2);
      expect(DetailsPage.initialSeason([null]), isNull);
    });
  });

  group('DetailsPage.splitSeasons', () {
    test('specials split off, numbered seasons sorted from 1', () {
      final split = DetailsPage.splitSeasons([0, 8, 1, 2, 0, null]);
      expect(split.numbered, [1, 2, 8]);
      expect(split.hasSpecials, isTrue);
    });

    test('no specials, no special pill', () {
      final split = DetailsPage.splitSeasons([1, 2, 3]);
      expect(split.numbered, [1, 2, 3]);
      expect(split.hasSpecials, isFalse);
    });

    test('only specials leaves the numbered list empty', () {
      final split = DetailsPage.splitSeasons([0, null]);
      expect(split.numbered, isEmpty);
      expect(split.hasSpecials, isTrue);
    });

    test('nothing at all splits to nothing', () {
      final split = DetailsPage.splitSeasons(const <int?>[]);
      expect(split.numbered, isEmpty);
      expect(split.hasSpecials, isFalse);
    });
  });

  group('DetailsPage.episodeWatchState', () {
    ContinueWatchingItem entry({
      required String id,
      int? season,
      int? episode,
    }) {
      return ContinueWatchingItem(
        id: id,
        title: 'A Show',
        type: 'series',
        season: season,
        episode: episode,
        positionSeconds: 30,
        totalDurationSeconds: 100,
        lastWatchedAt: DateTime(2026, 1, 1),
        isTorrent: false,
      );
    }

    test('marks exact pairs watched, only for this show', () {
      final state = DetailsPage.episodeWatchState([
        entry(id: 'tt1', season: 1, episode: 2),
        entry(id: 'tt1', season: 2, episode: 1),
        entry(id: 'tt2', season: 1, episode: 1),
        entry(id: 'tt1'),
      ], 'tt1');

      expect(state.watched, {'1:2', '2:1'});
      expect(state.current, '2:1');
    });

    test('current is the furthest episode, not the latest entry', () {
      final state = DetailsPage.episodeWatchState([
        entry(id: 'tt1', season: 1, episode: 10),
        entry(id: 'tt1', season: 1, episode: 3),
      ], 'tt1');

      expect(state.watched, {'1:10', '1:3'});
      expect(state.current, '1:10');
    });

    test('no history is nothing watched and no current', () {
      final state = DetailsPage.episodeWatchState(const [], 'tt1');

      expect(state.watched, isEmpty);
      expect(state.current, isNull);
    });
  });

  group('DetailsPage.resumeEpisode', () {
    Video video({required int season, required int episode}) {
      return Video(
        id: 'tt1:$season:$episode',
        title: 'Episode $episode',
        season: season,
        episode: episode,
      );
    }

    test('maps the furthest pair back onto its video', () {
      final videos = [video(season: 1, episode: 1), video(season: 2, episode: 3)];
      expect(
        DetailsPage.resumeEpisode(videos, '2:3')?.episode,
        3,
      );
    });

    test('stale history and nothing watched fall back to null', () {
      final videos = [video(season: 1, episode: 1)];
      expect(DetailsPage.resumeEpisode(videos, '9:9'), isNull);
      expect(DetailsPage.resumeEpisode(videos, null), isNull);
      expect(DetailsPage.resumeEpisode(const [], '1:1'), isNull);
    });
  });

  group('the page on a TV', () {
    // The page cannot be pumped here (it fetches), so what a remote lands on
    // is pinned at the source. A remote went to the genre tags before Play:
    // reading order puts anything higher on the screen first, and on a wide
    // layout the tags sit higher than Play does.
    final source = File('lib/pages/details/details_page.dart').readAsStringSync();

    test('has no genre tags to land on before Play', () {
      expect(source, isNot(contains('GenreTagRow')));
      // The genres are still on the page, as the metadata line.
      expect(source, contains("meta.genres.take(3).join(' · ')"));
    });

    test('Play asks for focus on a TV', () {
      expect(source, contains('autofocus: TvModeService.isTv.value'));
    });
  });
}
