// test/services/subtitle_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/subtitles/providers/opensubtitles_provider.dart';
import 'package:playtorriomov/services/subtitles/providers/stremio_subtitle_provider.dart';
import 'package:playtorriomov/services/subtitles/providers/subdl_provider.dart';
import 'package:playtorriomov/services/subtitles/providers/wyzie_provider.dart';
import 'package:playtorriomov/services/subtitles/subtitle_response.dart';

/// The subtitle providers' parsing, tested without a network.
///
/// The roadmap draws a line between two kinds of offline test: one whose
/// input is a *format* and one whose input is a *website*. These are the first
/// kind. The Stremio addon protocol defines the `{"subtitles": [...]}` body,
/// and OpenSubtitles speaks it too, so a fixture here pins the contract rather
/// than one day's markup. Wyzie's bare array is its published API shape.
///
/// What makes them worth having: every one of these providers is reached only
/// through a live HTTP call, so before this the parsing had no cover at all --
/// and each of them silently returns an empty list on anything unexpected,
/// which is indistinguishable from "this title has no subtitles".
void main() {
  group('StremioSubtitlesBody', () {
    test('reads the entries out of a well-formed body', () {
      final entries = StremioSubtitlesBody.entries(
        '{"subtitles":[{"url":"https://x/1.srt","lang":"eng"},'
        '{"url":"https://x/2.srt","lang":"spa"}]}',
      );

      expect(entries, hasLength(2));
      expect(entries.first['url'], 'https://x/1.srt');
    });

    test('an addon that is down returns an HTML page, not JSON', () {
      // The realistic failure, and the reason this never throws: a dead addon
      // host answers 200 with its provider's error page.
      expect(
        StremioSubtitlesBody.entries('<!DOCTYPE html><h1>502 Bad Gateway</h1>'),
        isEmpty,
      );
    });

    test('a body that is valid JSON but the wrong shape yields nothing', () {
      expect(StremioSubtitlesBody.entries('[]'), isEmpty);
      expect(StremioSubtitlesBody.entries('"ok"'), isEmpty);
      expect(StremioSubtitlesBody.entries('{"subtitles":null}'), isEmpty);
      expect(StremioSubtitlesBody.entries('{"subtitles":"none"}'), isEmpty);
      expect(StremioSubtitlesBody.entries('{}'), isEmpty);
    });

    test('entries with nothing to download are dropped', () {
      // A url is the one field that has to be there -- without it the entry
      // cannot become a subtitle no matter what else it carries.
      final entries = StremioSubtitlesBody.entries(
        '{"subtitles":[{"lang":"eng"},{"url":"","lang":"eng"},'
        '"not an object",{"url":"https://x/ok.srt"}]}',
      );

      expect(entries, hasLength(1));
      expect(entries.single['url'], 'https://x/ok.srt');
    });
  });

  group('OpenSubtitlesProvider.parseBody', () {
    test('uses the addon id as the title, and resolves the language code', () {
      final subs = OpenSubtitlesProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1.srt","lang":"eng","id":"abc123"},'
        '{"url":"https://x/2.srt","lang":"spa"}]}',
        <String>{},
      );

      // The id is what the picker's rows show -- a counter gave the user
      // nothing to choose between five rows by.
      expect(subs.map((s) => s.title), ['abc123', 'Subtitle 2']);
      expect(subs.first.language, isNot('eng'));
      expect(subs.first.providerName, 'OpenSubtitles');
    });

    test('the three endpoints are mirrors, so a repeat is not a second hit', () {
      // seenUrls carries across endpoints. Without it the same file came back
      // as "#1" from one host and "#2" from the next, and the picker showed
      // one subtitle twice.
      final seen = <String>{};
      final first = OpenSubtitlesProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1.srt","lang":"eng"}]}',
        seen,
      );
      final second = OpenSubtitlesProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1.srt","lang":"eng"},'
        '{"url":"https://x/new.srt","lang":"eng"}]}',
        seen,
      );

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(second.single.downloadUrl, 'https://x/new.srt');
      expect(second.single.title, 'Subtitle 1', reason: 'numbered per body');
    });

    test('defaults to srt when the entry does not say', () {
      final subs = OpenSubtitlesProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1.txt","lang":"eng"}]}',
        <String>{},
      );

      expect(subs.single.format, 'srt');
    });

    test('SubFormat is honoured, whatever case it arrives in', () {
      final subs = OpenSubtitlesProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1","lang":"eng","SubFormat":"VTT"}]}',
        <String>{},
      );

      expect(subs.single.format, 'vtt');
    });
  });

  group('StremioSubtitleProvider.parseBody', () {
    test("keeps the addon's own file name when it sends one", () {
      final subs = StremioSubtitleProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1.srt","lang":"eng",'
        '"subtitleFileName":"Some.Movie.2019.1080p.srt"}]}',
        'My Addon',
      );

      expect(subs.single.title, 'Some.Movie.2019.1080p.srt');
      expect(subs.single.providerName, 'My Addon');
    });

    test('falls back through release name, then title, then a number', () {
      final subs = StremioSubtitleProvider.parseBody(
        '{"subtitles":['
        '{"url":"https://x/1","lang":"eng","movieReleaseName":"A Release"},'
        '{"url":"https://x/2","lang":"eng","title":"A Title"},'
        '{"url":"https://x/3","lang":"eng"}]}',
        'My Addon',
      );

      expect(subs.map((s) => s.title), ['A Release', 'A Title', 'My Addon #3']);
    });

    test('an addon that omits SubFormat is read from the file extension', () {
      // Addons are written by strangers and plenty leave SubFormat out. The
      // name they did send is the next best evidence -- handing a .vtt to the
      // SRT path renders WEBVTT headers as a first subtitle line.
      final subs = StremioSubtitleProvider.parseBody(
        '{"subtitles":[{"url":"https://x/1","lang":"eng",'
        '"subtitleFileName":"Movie.vtt"},'
        '{"url":"https://x/2","lang":"eng","subtitleFileName":"Movie.srt"}]}',
        'My Addon',
      );

      expect(subs.map((s) => s.format), ['vtt', 'srt']);
    });

    test('a dead addon contributes nothing rather than throwing', () {
      expect(StremioSubtitleProvider.parseBody('nonsense', 'My Addon'), isEmpty);
    });
  });

  group('WyzieProvider.parseBody', () {
    test('reads a bare array, not the Stremio object', () {
      final subs = WyzieProvider.parseBody(
        '[{"url":"https://x/1.srt","language":"en","release":"A Release"}]',
      );

      expect(subs.single.title, 'A Release');
      expect(subs.single.providerName, 'Wyzie');
    });

    test('display beats looking the language code up', () {
      final subs = WyzieProvider.parseBody(
        '[{"url":"https://x/1","language":"pt-br","display":"Português (Brasil)"}]',
      );

      expect(subs.single.language, 'Português (Brasil)');
    });

    test('language and lang are both accepted', () {
      final a = WyzieProvider.parseBody('[{"url":"https://x/1","language":"es"}]');
      final b = WyzieProvider.parseBody('[{"url":"https://x/1","lang":"es"}]');

      expect(a.single.language, b.single.language);
    });

    test('hearing-impaired is marked however the API spells it', () {
      final byLongName = WyzieProvider.parseBody(
        '[{"url":"https://x/1","release":"A Release","isHearingImpaired":true}]',
      );
      final byShortName = WyzieProvider.parseBody(
        '[{"url":"https://x/1","release":"A Release","hi":true}]',
      );

      expect(byLongName.single.title, 'A Release [CC]');
      expect(byShortName.single.title, 'A Release [CC]');
    });

    test('an object body is not a Wyzie response', () {
      expect(WyzieProvider.parseBody('{"subtitles":[]}'), isEmpty);
      expect(WyzieProvider.parseBody('not json'), isEmpty);
    });

    test('entries with no url are dropped', () {
      final subs = WyzieProvider.parseBody(
        '[{"language":"en"},{"url":"","language":"en"},{"url":"https://x/ok"}]',
      );

      expect(subs, hasLength(1));
    });
  });

  group('SubdlProvider.cleanTitleAndExtractYear', () {
    test('pulls the year out of a scraper release name', () {
      // What actually reaches this: a filename off a torrent, not a clean
      // title. Searching SubDL for the whole string finds nothing.
      final parsed = SubdlProvider.cleanTitleAndExtractYear(
        'Some.Movie.2019.1080p.WEB-DL.x264-GROUP',
      );

      expect(parsed['year'], 2019);
      expect(parsed['cleanTitle'], 'Some Movie');
    });

    test('a year in brackets is read the same way', () {
      final parsed = SubdlProvider.cleanTitleAndExtractYear('Some Movie (2019)');

      expect(parsed['year'], 2019);
      expect(parsed['cleanTitle'], 'Some Movie');
    });

    test('an explicit year wins over one found in the text', () {
      // The caller knows the year from metadata; a number in the filename may
      // be a resolution, an episode count or part of the title itself.
      final parsed = SubdlProvider.cleanTitleAndExtractYear(
        'Some.Movie.2019.1080p',
        explicitYear: 2021,
      );

      expect(parsed['year'], 2021);
    });

    test('with no year, a quality tag marks where the title ends', () {
      final parsed = SubdlProvider.cleanTitleAndExtractYear(
        'Some.Show.S01E02.1080p.WEBRip',
      );

      expect(parsed['year'], isNull);
      expect(parsed['cleanTitle'], 'Some Show');
    });

    test('a title that is only a year is not reduced to nothing', () {
      // "2012" is a real film. Stripping the year would leave an empty query,
      // so the original string stands.
      final parsed = SubdlProvider.cleanTitleAndExtractYear('2012');

      expect(parsed['year'], 2012);
      expect(parsed['cleanTitle'], '2012');
    });

    test('an already clean title survives unchanged', () {
      final parsed = SubdlProvider.cleanTitleAndExtractYear('The Matrix');

      expect(parsed['cleanTitle'], 'The Matrix');
      expect(parsed['year'], isNull);
    });
  });
}
