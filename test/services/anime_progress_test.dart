// test/services/anime_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
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
}
