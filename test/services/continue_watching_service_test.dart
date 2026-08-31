import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorrio/models/movie/movie_detail.dart';
import 'package:playtorrio/models/stream/stream_model.dart';
import 'package:playtorrio/services/continue_watching/continue_watching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final detail = MovieDetail(
    id: 'tt0137523',
    type: 'movie',
    name: 'Fight Club',
  );
  final source = StreamSource(name: 'Test', addonName: 'Test');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ContinueWatchingService.activeItems.value = [];
    ContinueWatchingService.historyItems.value = [];
    await ContinueWatchingService.initialize();
  });

  group('ContinueWatchingService history log', () {
    testWidgets('saveProgress keeps a history entry even once finished (>=90%)', (tester) async {
      // Unfinished: shows up in both activeItems and historyItems.
      await ContinueWatchingService.saveProgress(
        detail: detail,
        source: source,
        positionSeconds: 45 * 60,
        totalDurationSeconds: 139 * 60,
      );
      await tester.pump(); // flush the addPostFrameCallback that applies the write
      expect(ContinueWatchingService.activeItems.value.length, 1);
      expect(ContinueWatchingService.getHistoryProgress('tt0137523')?.positionSeconds, 45 * 60);

      // Finished (>=90%): activeItems drops it, but historyItems keeps it --
      // this is the exact behavior PlaybackHistoryService used to provide
      // and ContinueWatchingService did not, before the two were merged.
      await ContinueWatchingService.saveProgress(
        detail: detail,
        source: source,
        positionSeconds: 135 * 60,
        totalDurationSeconds: 139 * 60,
      );
      await tester.pump();
      expect(ContinueWatchingService.activeItems.value, isEmpty);
      expect(ContinueWatchingService.getHistoryProgress('tt0137523')?.positionSeconds, 135 * 60);
    });

    testWidgets('removeHistoryItem deletes only from the history log', (tester) async {
      await ContinueWatchingService.saveProgress(
        detail: detail,
        source: source,
        positionSeconds: 45 * 60,
        totalDurationSeconds: 139 * 60,
      );
      await tester.pump();
      final item = ContinueWatchingService.getHistoryProgress('tt0137523')!;

      await ContinueWatchingService.removeHistoryItem(item);
      expect(ContinueWatchingService.getHistoryProgress('tt0137523'), isNull);
      // activeItems is a separate list, untouched by a history-only removal.
      expect(ContinueWatchingService.activeItems.value.length, 1);
    });
  });
}
