import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/playback_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PlaybackCoordinator.stopActive);

  test('play and pause use the explicit callbacks, whatever the mirror says', () {
    var played = 0;
    var paused = 0;
    PlaybackCoordinator.activate(
      'a',
      () {},
      onPlay: () => played++,
      onPause: () => paused++,
    );
    // The mirror says "playing" (activate's default), but a Play press from
    // the notification must still reach the player.
    PlaybackCoordinator.play();
    PlaybackCoordinator.pause();
    expect((played, paused), (1, 1));
  });

  test('without explicit callbacks the toggle is guarded by the mirror', () {
    var toggles = 0;
    PlaybackCoordinator.activate('b', () {}, onTogglePlayPause: () => toggles++);
    PlaybackCoordinator.play(); // mirror: playing -> no-op
    expect(toggles, 0);
    PlaybackCoordinator.pause();
    expect(toggles, 1);
    PlaybackCoordinator.setPlaying(false);
    PlaybackCoordinator.pause(); // already paused -> no-op
    expect(toggles, 1);
    PlaybackCoordinator.play();
    expect(toggles, 2);
  });

  test('stopping the source forgets its callbacks', () {
    var played = 0;
    PlaybackCoordinator.activate('c', () {}, onPlay: () => played++);
    PlaybackCoordinator.stopActive();
    PlaybackCoordinator.play();
    expect(played, 0);
  });
}
