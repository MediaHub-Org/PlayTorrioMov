// An embedded track must survive an appearance change.
//
// `applySubtitleStyling` used to take a `forceLibass` flag, and every
// appearance setter -- font, size, colour, position, and twenty more --
// called it without the flag. So changing the font size while an embedded
// track was on turned that track back off: the styling call honoured the
// `useLibass` preference, which is off by default, and set
// `sub-visibility=no`.
//
// The flag is gone. Whether libass is used is read from
// `PlayerSettings.shouldUseLibass`, which reads one piece of state set in one
// place -- so no call site can forget it.
//
// The predicate is tested rather than the call, because the call needs a real
// media_kit `Player` and a real libmpv behind it. The decision is the part
// that was wrong; the property writes are the part that was always right.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/player/player_settings.dart';

void main() {
  setUp(() {
    // Both are global, so a test that sets one must not leak into the next.
    PlayerSettings.embeddedSubtitleActive.value = false;
    PlayerSettings.useLibass.value = false;
  });

  tearDown(() {
    PlayerSettings.embeddedSubtitleActive.value = false;
    PlayerSettings.useLibass.value = false;
  });

  group('shouldUseLibass', () {
    test('is off by default', () {
      // The Flutter overlay draws online subtitles, and mpv's own rendering
      // has to be off for that to look right.
      expect(PlayerSettings.shouldUseLibass, isFalse);
    });

    test('is on when the viewer asked for libass', () {
      PlayerSettings.useLibass.value = true;
      expect(PlayerSettings.shouldUseLibass, isTrue);
    });

    test('is on for an embedded track even with the preference off', () {
      // The regression. An embedded ASS track is drawn by libass and never
      // emitted as text, so it has no other way to reach the screen -- and
      // the preference being off must not turn it off.
      PlayerSettings.embeddedSubtitleActive.value = true;
      expect(PlayerSettings.shouldUseLibass, isTrue);
    });

    test('goes back off when the embedded track is cleared', () {
      // What happens when the viewer picks an online subtitle or turns
      // subtitles off: the next styling call must not keep libass on for a
      // track that is no longer selected.
      PlayerSettings.embeddedSubtitleActive.value = true;
      expect(PlayerSettings.shouldUseLibass, isTrue);

      PlayerSettings.embeddedSubtitleActive.value = false;
      expect(PlayerSettings.shouldUseLibass, isFalse);
    });

    test('the preference alone keeps it on after the track is cleared', () {
      // The two reasons are independent: clearing the embedded state must
      // not override a viewer who asked for libass.
      PlayerSettings.useLibass.value = true;
      PlayerSettings.embeddedSubtitleActive.value = true;
      PlayerSettings.embeddedSubtitleActive.value = false;

      expect(PlayerSettings.shouldUseLibass, isTrue);
    });
  });
}
