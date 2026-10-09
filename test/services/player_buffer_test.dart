// A link slower than the video made the picture jerk: mpv resumes after one
// second of cushion, plays it, runs dry and waits again. Rebuffering to a real
// cushion trades one longer wait for none of the rest. And a short jump back
// should come out of the cache, not the network.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/player_settings.dart';

void main() {
  tearDown(() => PlayerSettings.bufferPreset.value =
      BufferResiliencePreset.standard);

  group('resume cushion', () {
    int resumeFor(BufferResiliencePreset preset) {
      PlayerSettings.bufferPreset.value = preset;
      return PlayerSettings.getEffectiveResumeSecs();
    }

    test('is never mpv\'s own single second', () {
      for (final preset in BufferResiliencePreset.values) {
        expect(resumeFor(preset), greaterThanOrEqualTo(2), reason: '$preset');
      }
    });

    test('grows with the preset and stops short of a freeze', () {
      expect(resumeFor(BufferResiliencePreset.minimal), 2);
      expect(resumeFor(BufferResiliencePreset.standard), 4);
      expect(resumeFor(BufferResiliencePreset.highResilience), 8);
      expect(resumeFor(BufferResiliencePreset.maximum), 10);
    });
  });

  group('rewind cache', () {
    int backFor(BufferResiliencePreset preset) {
      PlayerSettings.bufferPreset.value = preset;
      return PlayerSettings.getEffectiveMaxBackBytes();
    }

    test('is no smaller than it was and scales with the preset', () {
      const mb = 1024 * 1024;
      expect(backFor(BufferResiliencePreset.minimal), 50 * mb);
      expect(backFor(BufferResiliencePreset.standard), 75 * mb);
      expect(backFor(BufferResiliencePreset.highResilience), 150 * mb);
      expect(backFor(BufferResiliencePreset.maximum), 250 * mb);
    });
  });
}
