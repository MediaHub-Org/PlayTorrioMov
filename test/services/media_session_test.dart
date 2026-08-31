// test/services/media_session_test.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/services/media_session/media_session_service.dart';
import 'package:playtorrio/services/playback_coordinator.dart';

void main() {
  // PlaybackCoordinator._notify reaches for SchedulerBinding.instance to
  // decide whether it can notify synchronously.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildMediaControls', () {
    test('compact indices always address a real control', () {
      // The Android shade indexes into the control list. An index past the
      // end throws on the platform channel, and a stale one shows the wrong
      // button -- so check every combination, not just the common case.
      for (final playing in [true, false]) {
        for (final canPrevious in [true, false]) {
          for (final canNext in [true, false]) {
            final b = buildMediaControls(
              playing: playing,
              canPrevious: canPrevious,
              canNext: canNext,
            );
            for (final i in b.compactIndices) {
              expect(i, greaterThanOrEqualTo(0));
              expect(i, lessThan(b.controls.length));
            }
            expect(b.compactIndices.length, lessThanOrEqualTo(3),
                reason: 'the collapsed shade row shows at most three');
          }
        }
      }
    });

    test('shows pause while playing and play while paused', () {
      expect(
        buildMediaControls(playing: true, canPrevious: false, canNext: false)
            .controls,
        contains(MediaControl.pause),
      );
      expect(
        buildMediaControls(playing: false, canPrevious: false, canNext: false)
            .controls,
        contains(MediaControl.play),
      );
    });

    test('skip buttons appear only when the source can skip', () {
      final none =
          buildMediaControls(playing: true, canPrevious: false, canNext: false)
              .controls;
      expect(none, isNot(contains(MediaControl.skipToNext)));
      expect(none, isNot(contains(MediaControl.skipToPrevious)));

      final both =
          buildMediaControls(playing: true, canPrevious: true, canNext: true)
              .controls;
      expect(both, contains(MediaControl.skipToNext));
      expect(both, contains(MediaControl.skipToPrevious));
    });

    test('stop is present but kept out of the collapsed row', () {
      final b =
          buildMediaControls(playing: true, canPrevious: true, canNext: true);
      expect(b.controls.last, MediaControl.stop);
      expect(b.compactIndices, isNot(contains(b.controls.length - 1)));
    });
  });

  group('PlaybackCoordinator skip callbacks', () {
    tearDown(() => PlaybackCoordinator.dismiss());

    test('a source without a queue reports no skip targets', () {
      PlaybackCoordinator.activate('video:1', () {}, kind: 'video');
      expect(PlaybackCoordinator.canSkipNext, isFalse);
      expect(PlaybackCoordinator.canSkipPrevious, isFalse);
      // Calling them anyway must be a no-op, not a null dereference.
      PlaybackCoordinator.skipToNext();
      PlaybackCoordinator.skipToPrevious();
    });

    test('a queued source forwards skips to its own callbacks', () {
      var next = 0;
      var previous = 0;
      PlaybackCoordinator.activate(
        'music:1',
        () {},
        kind: 'music',
        onNext: () => next++,
        onPrevious: () => previous++,
      );

      expect(PlaybackCoordinator.canSkipNext, isTrue);
      expect(PlaybackCoordinator.canSkipPrevious, isTrue);

      PlaybackCoordinator.skipToNext();
      PlaybackCoordinator.skipToPrevious();
      expect(next, 1);
      expect(previous, 1);
    });

    test('release clears the skip callbacks with the rest of the source', () {
      PlaybackCoordinator.activate('music:2', () {},
          kind: 'music', onNext: () {}, onPrevious: () {});
      PlaybackCoordinator.release('music:2');
      expect(PlaybackCoordinator.canSkipNext, isFalse);
      expect(PlaybackCoordinator.canSkipPrevious, isFalse);
    });

    test('switching sources does not inherit the old queue', () {
      PlaybackCoordinator.activate('music:3', () {},
          kind: 'music', onNext: () {}, onPrevious: () {});
      PlaybackCoordinator.activate('video:3', () {}, kind: 'video');
      expect(PlaybackCoordinator.canSkipNext, isFalse,
          reason: 'a single video has nothing to skip to');
      expect(PlaybackCoordinator.canSkipPrevious, isFalse);
    });
  });
}
