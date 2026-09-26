// The Forced and CC/SDH filters had nothing to find on an embedded track.
//
// Both are read off a track's *title* -- "forced" and "SDH"/"CC" are words a
// muxer writes there, and there is no other place they appear. But the player
// overwrote the container's title with the language name before building the
// track, so the sniff ran against "Spanish" and could never match. The
// filters were not broken; they were looking in a field that had been
// emptied.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';

PlayerEmbeddedSubtitle track({
  String title = 'Spanish',
  String? language = 'Spanish',
  String? containerTitle,
  bool isForcedTrack = false,
}) => PlayerEmbeddedSubtitle(
  index: 1,
  title: title,
  language: language,
  containerTitle: containerTitle,
  isForcedTrack: isForcedTrack,
);

void main() {
  group('an embedded track reads forced and SDH from its container title', () {
    test('a title saying "forced" marks the track forced', () {
      expect(
        track(containerTitle: 'Spanish (Forced)').isForced,
        isTrue,
      );
      expect(
        track(containerTitle: 'Forced').isForced,
        isTrue,
      );
    });

    test('the display name alone does not mark it forced', () {
      // The regression: the display name is the language, so sniffing it
      // found nothing. This is what the player used to pass.
      expect(track(title: 'Spanish', language: 'Spanish').isForced, isFalse);
    });

    test('the container flag marks it forced with no title at all', () {
      expect(track(isForcedTrack: true).isForced, isTrue);
    });

    test('a title saying SDH or CC marks it hearing-impaired', () {
      for (final title in [
        'English (SDH)',
        'English CC',
        'Movie.2020.SDH',
        'Movie_CC',
        'Hearing Impaired',
      ]) {
        expect(
          track(containerTitle: title).isHearingImpaired,
          isTrue,
          reason: title,
        );
      }
    });

    test('an ordinary title marks neither', () {
      final plain = track(containerTitle: 'Spanish (Latin America)');
      expect(plain.isForced, isFalse);
      expect(plain.isHearingImpaired, isFalse);
    });

    test('the display name still prefers the language', () {
      // The fix must not undo the reason the title was overwritten: a
      // container title is routinely technical noise, and the language name
      // is what a viewer reads.
      expect(
        track(
          title: 'Spanish',
          language: 'Spanish',
          containerTitle: 'spa [Full] SDH',
        ).displayName,
        'Spanish',
      );
    });

    test('an untagged track falls back to its title for display', () {
      expect(
        track(title: 'Signs & Songs', language: null).displayName,
        'Signs & Songs',
      );
    });

    test('withFlags keeps the container title', () {
      // The flags arrive from a second, asynchronous read of mpv's track
      // list. Rebuilding the track without the title would put the sniff
      // back where it started.
      final flagged = track(containerTitle: 'Spanish (Forced)').withFlags(
        isDefault: true,
        isForcedTrack: false,
      );

      expect(flagged.containerTitle, 'Spanish (Forced)');
      expect(flagged.isForced, isTrue);
      expect(flagged.isDefault, isTrue);
    });
  });
}
