// test/pages/anime_dub_source_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';
import 'package:playtorriomov/pages/anime/anime_stream_sheet.dart';

StreamSource source({String? name, String? description}) => StreamSource(
      name: name,
      description: description,
      addonName: 'MegaPlay',
    );

void main() {
  group('isDubSource', () {
    test('matches the scraper category stamp in either field', () {
      expect(isDubSource(source(name: 'MegaPlay • DUB')), isTrue);
      expect(
        isDubSource(source(description: 'Master HLS • DUB • 3 Subtitles')),
        isTrue,
      );
      expect(isDubSource(source(name: 'MegaPlay • SUB')), isFalse);
    });

    test('a source with no stamp is a sub', () {
      expect(isDubSource(source()), isFalse);
      expect(
        isDubSource(source(name: 'VidHide', description: 'HD • MP4')),
        isFalse,
      );
    });
  });
}
