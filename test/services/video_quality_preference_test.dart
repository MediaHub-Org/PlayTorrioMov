// test/services/video_quality_preference_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/tv_mode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/services/player/video_quality_preference.dart';

StreamSource source(String title) => StreamSource(
      title: title,
      addonName: 'test',
    );

void main() {
  group('qualityDistanceComparator', () {
    test('Best: identical to the old always-highest-first sort', () {
      final list = [source('480p'), source('1080p'), source('4K'), source('720p')];
      list.sort(qualityDistanceComparator(VideoQualityTier.best));
      expect(list.map((s) => s.quality), ['4K', '1080p', '720p', '480p']);
    });

    test('Good: 720p leads, then closer-to-720p before farther', () {
      final list = [source('480p'), source('4K'), source('1080p'), source('720p')];
      list.sort(qualityDistanceComparator(VideoQualityTier.good));
      // Distances from 720p (rank 2): 480p=1, 1080p=1, 4K=2, 720p=0.
      // 480p and 1080p tie on distance; the higher rank (1080p) wins the tie.
      expect(list.map((s) => s.quality), ['720p', '1080p', '480p', '4K']);
    });

    test('Better: 1080p leads', () {
      final list = [source('4K'), source('720p'), source('1080p'), source('480p')];
      list.sort(qualityDistanceComparator(VideoQualityTier.better));
      expect(list.first.quality, '1080p');
    });

    test('an unreadable quality (rank 0) sorts last at every tier', () {
      final list = [source('no quality tag here'), source('1080p')];
      list.sort(qualityDistanceComparator(VideoQualityTier.better));
      expect(list.first.quality, '1080p');
    });

    test('never hides anything -- every source survives the sort', () {
      final list = [source('480p'), source('720p'), source('1080p'), source('4K'), source('unknown')];
      for (final t in VideoQualityTier.values) {
        final sorted = List.of(list)..sort(qualityDistanceComparator(t));
        expect(sorted.length, list.length);
      }
    });
  });

  group('gbPerHourFor', () {
    test('increases with the tier', () {
      final values = VideoQualityTier.values.map(gbPerHourFor).toList();
      expect(values, [values[0], values[1], values[2]]..sort());
    });
  });

  group('VideoQualityPreference on a TV', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      TvModeService.isTv.value = false;
    });
    tearDown(() => TvModeService.isTv.value = false);

    test('a TV that never chose opens on 1080p, a phone on the best', () async {
      await VideoQualityPreference.initialize();
      expect(VideoQualityPreference.tier.value, VideoQualityTier.best);

      TvModeService.isTv.value = true;
      expect(VideoQualityPreference.tier.value, VideoQualityTier.better,
          reason: 'detection answers after startup; the default follows it');
    });

    test('a tier somebody chose is never overridden by the device', () async {
      await VideoQualityPreference.initialize();
      await VideoQualityPreference.setTier(VideoQualityTier.best);

      TvModeService.isTv.value = true;

      expect(VideoQualityPreference.tier.value, VideoQualityTier.best);
    });
  });
}
