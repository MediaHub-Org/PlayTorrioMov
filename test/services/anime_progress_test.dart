// test/services/anime_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/continue_watching/continue_watching_item.dart';
import 'package:playtorriomov/models/movie/movie_detail.dart';
import 'package:playtorriomov/models/movie/video.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/anime/anime_library_service.dart';
import 'package:playtorriomov/services/continue_watching/continue_watching_service.dart';

/// The detail an anime plays through: AnimeScraperService.toDetail stamps
/// this id shape, which is what ties playback progress back to the show.
MovieDetail animeDetail() =>
    MovieDetail(id: 'anilist:1535', type: 'anime', name: 'Death Note');

Video episode(int n) => Video(
  id: 'anilist:1535:$n',
  season: 1,
  episode: n,
  title: 'Episode $n',
);

final source = StreamSource(name: 'Test', addonName: 'Test');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ContinueWatchingService.activeItems.value = [];
    ContinueWatchingService.historyItems.value = [];
    await ContinueWatchingService.initialize();
  });

  group('ContinueWatchingService.lastWatchedEpisodeFor', () {
    test('a show that has never been played has no episode', () {
      expect(
        ContinueWatchingService.lastWatchedEpisodeFor('anilist:1535'),
        isNull,
      );
    });

    testWidgets('reads the episode the player actually saved', (tester) async {
      // Anime plays through the shared PlayerScreen, so its progress lands
      // here under `anilist:<id>`. The anime details page used to ask
      // AnimeLibraryService.lastWatchedEpisode instead -- a field no code
      // path writes -- so Play always offered episode 1.
      await ContinueWatchingService.saveProgress(
        detail: animeDetail(),
        source: source,
        episode: episode(7),
        positionSeconds: 300,
        totalDurationSeconds: 1400,
      );
      await tester.pump();

      expect(ContinueWatchingService.lastWatchedEpisodeFor('anilist:1535'), 7);
    });

    testWidgets('still resolves once the show falls off Continue Watching', (
      tester,
    ) async {
      // Finishing an episode (>=90%) drops it from activeItems but keeps it
      // in the history log, and "what episode am I on" must survive that.
      await ContinueWatchingService.saveProgress(
        detail: animeDetail(),
        source: source,
        episode: episode(12),
        positionSeconds: 1350,
        totalDurationSeconds: 1400,
      );
      await tester.pump();

      expect(ContinueWatchingService.activeItems.value, isEmpty);
      expect(ContinueWatchingService.lastWatchedEpisodeFor('anilist:1535'), 12);
    });

    testWidgets('does not report another show\'s progress', (tester) async {
      await ContinueWatchingService.saveProgress(
        detail: animeDetail(),
        source: source,
        episode: episode(3),
        positionSeconds: 300,
        totalDurationSeconds: 1400,
      );
      await tester.pump();

      expect(
        ContinueWatchingService.lastWatchedEpisodeFor('anilist:9999'),
        isNull,
      );
    });
  });

  group('AnimeLibraryService.clearListStatus', () {
    const anime = AnimeMedia(id: 1535, titleRomaji: 'Death Note');

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AnimeLibraryService.instance.removeFromWatchlist(anime.id);
    });

    test('drops an entry that carries no progress', () async {
      await AnimeLibraryService.instance.setWatchlistStatus(
        anime,
        AnimeWatchStatus.planToWatch,
      );
      expect(AnimeLibraryService.instance.getWatchlistItem(anime.id), isNotNull);

      await AnimeLibraryService.instance.clearListStatus(anime.id);

      expect(AnimeLibraryService.instance.getWatchlistItem(anime.id), isNull);
    });

    test('clearing a status is not a reason to forget progress', () async {
      // The watchlist entry is the only carrier of lastWatchedEpisode, so
      // deleting it to clear a list status would take the resume point with
      // it. Taking a show off your watchlist means "not planning to watch
      // this", not "forget that I watched 12 episodes of it".
      await AnimeLibraryService.instance.setWatchlistStatus(
        anime,
        AnimeWatchStatus.planToWatch,
      );
      AnimeLibraryService.instance.seedProgressForTest(anime.id, episode: 12);
      expect(AnimeLibraryService.instance.hasResumableProgress(anime.id), isTrue);

      await AnimeLibraryService.instance.clearListStatus(anime.id);

      final kept = AnimeLibraryService.instance.getWatchlistItem(anime.id);
      expect(kept, isNotNull);
      expect(kept!.lastWatchedEpisode, 12);
    });

    test('an unknown show is a no-op, not a crash', () async {
      await AnimeLibraryService.instance.clearListStatus(424242);
      expect(AnimeLibraryService.instance.hasResumableProgress(424242), isFalse);
    });
  });

  group('ContinueWatchingService.matchesTypeFilter', () {
    // Anime is not identifiable by `type` alone: entries arrive from the
    // AniList catalogue, the Arabic catalogue, and addons reporting
    // type == 'anime', and are told apart by id prefix and addon name. This
    // lived inside the slider until the history view needed the same answer.
    ContinueWatchingItem item({
      String id = 'tt1',
      String type = 'movie',
      String? addonName,
    }) => ContinueWatchingItem(
      id: id,
      title: 'T',
      type: type,
      positionSeconds: 1,
      totalDurationSeconds: 100,
      lastWatchedAt: DateTime(2026),
      addonName: addonName,
      isTorrent: false,
    );

    test('a null filter matches everything', () {
      expect(
        ContinueWatchingService.matchesTypeFilter(item(), null),
        isTrue,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(
          item(id: 'anilist:1', type: 'anime'),
          null,
        ),
        isTrue,
      );
    });

    test('"main" excludes anime from all three of its sources', () {
      expect(ContinueWatchingService.matchesTypeFilter(item(), 'main'), isTrue);
      for (final anime in [
        item(type: 'anime'),
        item(id: 'anilist:1535'),
        item(id: 'arabic_anime:99'),
        item(addonName: 'ArabicAnime'),
      ]) {
        expect(
          ContinueWatchingService.matchesTypeFilter(anime, 'main'),
          isFalse,
          reason: 'main must not show ${anime.id}/${anime.addonName}',
        );
      }
    });

    test('"anime" takes all three sources', () {
      for (final anime in [
        item(type: 'anime'),
        item(id: 'anilist:1535'),
        item(id: 'arabic_anime:99'),
        item(addonName: 'ArabicAnime'),
      ]) {
        expect(
          ContinueWatchingService.matchesTypeFilter(anime, 'anime'),
          isTrue,
        );
      }
      expect(
        ContinueWatchingService.matchesTypeFilter(item(), 'anime'),
        isFalse,
      );
    });

    test('arabic and general anime partition the anime set', () {
      final arabic = item(id: 'arabic_anime:99');
      final general = item(id: 'anilist:1535');

      expect(
        ContinueWatchingService.matchesTypeFilter(arabic, 'arabic_anime'),
        isTrue,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(general, 'arabic_anime'),
        isFalse,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(general, 'general_anime'),
        isTrue,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(arabic, 'general_anime'),
        isFalse,
      );
    });

    test('movie and series filter on type', () {
      expect(
        ContinueWatchingService.matchesTypeFilter(item(type: 'movie'), 'movie'),
        isTrue,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(item(type: 'series'), 'movie'),
        isFalse,
      );
      expect(
        ContinueWatchingService.matchesTypeFilter(
          item(type: 'series'),
          'series',
        ),
        isTrue,
      );
    });
  });
}
