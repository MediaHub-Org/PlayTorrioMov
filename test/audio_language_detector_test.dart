import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';

void main() {
  group('Audio Language & Dub Detection in StreamSource', () {
    test('Purstream Multi detected as multi and english', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'Purstream · pulse · 1080p · MULTI',
        description: 'Purstream Multi-Audio HLS Stream',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isTrue);
      expect(langs.contains('english'), isTrue);
      expect(s.getAudioBadge(), '🌐 MULTI');
      expect(s.hasAudioLanguage('multi'), isTrue);
    });

    test('Movy Delhi detected as Hindi', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Delhi] 1080p',
        description: 'Hindi audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
      expect(s.hasAudioLanguage('hindi'), isTrue);
    });

    test('Movy Munich detected as German', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Munich] 1080p',
        description: 'German audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('german'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇩🇪 GER');
      expect(s.hasAudioLanguage('german'), isTrue);
    });

    test('Movy Paris detected as French', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Paris] 1080p',
        description: 'French audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('french'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇫🇷 FRE');
      expect(s.hasAudioLanguage('french'), isTrue);
    });

    test('Movy Cancun detected as Spanish', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Cancun] 1080p',
        description: 'Spanish audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('spanish'));
      expect(langs.contains('english'), isFalse);
      expect(s.getAudioBadge(), '🇪🇸 SPA');
      expect(s.hasAudioLanguage('spanish'), isTrue);
    });

    test('Movy Miami detected as English / Original', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Miami] 1080p',
        description: 'Original audio • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('english'));
      expect(langs.contains('hindi'), isFalse);
      expect(langs.contains('multi'), isFalse);
      expect(s.hasAudioLanguage('english'), isTrue);
    });

    test('Vuflix Hindi Audio stream', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Vuflix - Beta] Hindi Audio',
        description: 'Beta • Hindi Audio • MOVIE',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('MeowTV Hindiv3 stream', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'MeowTV · Hindiv3 · 1080p',
        description: 'MeowTV Stream · HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('RiveStream hindicast stream', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Rive - hindicast] HD',
        description: 'hindicast • HD • HLS',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('Vadapav Hindi release', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        name: 'vadapav.mov 1080P',
        title: '3.Idiots.[2009].1080p.10bit.BluRay.x265.Hindi.AAC.5.1.Esub.mkv',
        description: '3.Idiots.[2009].1080p.10bit.BluRay.x265.Hindi.AAC.5.1.Esub.mkv',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });

    test('111477 Telugu Indian dub release', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'Inception.2010.720p.AMZN.WEB-DL.TELUGU.DDP2.0.H.265-GTM.mkv [a11 970.6 MB]',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('hindi'));
      expect(s.getAudioBadge(), '🇮🇳 TELUGU');
    });

    test('DownloadEverything Dual Audio Hindi release', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[HubCloud] Movie.2024.1080p.Dual.Audio.Hindi.English.x264',
        description: '1080p · Dual Audio · Hindi · HubCloud',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('multi'));
      expect(langs, contains('hindi'));
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), '🌐 MULTI');
    });

    test('ZERO JUNK: MultiEmbed does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '2embed XPS · Server 1',
        description: '2embed Multi-CDN Stream',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse, reason: 'Multi-CDN must not trigger multi-audio');
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: FlaxMovies Multi-CDN does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'FlaxMovies · Airflix · 1080p',
        description: 'FlaxMovies Multi-CDN Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse);
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: Dulo Multi-CDN does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'Dulo · Source · 1080p',
        description: 'Dulo Multi-CDN HLS Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse);
      expect(langs, contains('english'));
      expect(s.getAudioBadge(), isNull);
    });

    test('ZERO JUNK: Indiana Jones movie title does NOT trigger Indian/Hindi', () {
      final s = StreamSource(
        addonName: 'PlayTorrio',
        title: 'Indiana.Jones.and.the.Dial.of.Destiny.2023.1080p.WEBRip.x264-FLUX.mkv',
      );
      final langs = s.getAudioLanguages(mediaTitle: 'Indiana Jones and the Dial of Destiny');
      expect(langs.contains('hindi'), isFalse, reason: 'Movie title Indiana Jones must not trigger Indian');
      expect(langs, contains('english'));
    });

    test('ZERO JUNK: German Sub does NOT trigger German audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrio',
        title: 'Movie.2024.1080p.WEBRip.x264 [German-Sub]',
        description: 'Subs: German, French, Spanish',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('german'), isFalse, reason: 'German-Sub is a subtitle, not audio');
      expect(langs.contains('french'), isFalse);
      expect(langs.contains('spanish'), isFalse);
      expect(langs, contains('english'));
    });

    test('ZERO JUNK: Multi-Sub does NOT trigger multi-audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrio',
        title: 'Movie.2024.1080p.Multi-Sub.x265',
      );
      final langs = s.getAudioLanguages();
      expect(langs.contains('multi'), isFalse, reason: 'Multi-Sub is subtitles, not audio');
      expect(langs, contains('english'));
    });

    test('French VF / Truefrench triggers French audio', () {
      final s = StreamSource(
        addonName: 'PlayTorrio',
        title: 'Movie.2024.1080p.VF.x264-ZONE',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('french'));
      expect(s.getAudioBadge(), '🇫🇷 FRE');
    });

    test('Standard LookMovie / VidSrc defaults to English / Original', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'LookMovie · 1080p',
        description: 'LookMovie HLS Stream · 1080p',
      );
      final langs = s.getAudioLanguages();
      expect(langs, contains('english'));
      expect(s.hasAudioLanguage('english'), isTrue);
      expect(s.hasAudioLanguage('hindi'), isFalse);
      expect(s.hasAudioLanguage('all'), isTrue);
    });

    test('VidVault backend language and MKV extraction', () {
      final s1 = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'VidVault · MP4 · Hindi · IN · 1080p',
        description: 'VidVault Direct MP4 · Hindi · IN',
      );
      expect(s1.getAudioLanguages(), contains('hindi'));
      expect(s1.getAudioBadge(), '🇮🇳 HINDI');

      final s2 = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'VidVault · MKV · German · DE · 1080p · 2.8GB',
        description: 'VidVault Direct MKV · German DE 2.8GB',
      );
      expect(s2.getAudioLanguages(), contains('german'));
      expect(s2.getAudioBadge(), '🇩🇪 GER');
    });

    test('VidZee backend language extraction', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'VidZee · Alpha · Spanish · 1080p',
        description: 'VidZee Stream · Spanish · HLS',
      );
      expect(s.getAudioLanguages(), contains('spanish'));
      expect(s.getAudioBadge(), '🇪🇸 SPA');
    });

    test('VixSrc foreign language extraction', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'VixSrc · Master HLS · Spanish · 1080p',
        description: 'VixSrc Master Stream · Spanish',
      );
      expect(s.getAudioLanguages(), contains('spanish'));
      expect(s.getAudioBadge(), '🇪🇸 SPA');
    });

    test('Movy server language in title', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: '[Movy - Munich · German] 1080p',
        description: 'German audio • HLS',
      );
      expect(s.getAudioLanguages(), contains('german'));
      expect(s.getAudioBadge(), '🇩🇪 GER');
    });

    test('X-Downloader spokenLanguages extraction', () {
      final s = StreamSource(
        addonName: 'PlayTorrioHTTP',
        title: 'X-Downloader · Hindi, English',
        description: 'X-Downloader Direct MP4 Stream · Hindi, English',
      );
      expect(s.getAudioLanguages(), contains('hindi'));
      expect(s.getAudioLanguages(), contains('english'));
      expect(s.getAudioBadge(), '🇮🇳 HINDI');
    });
  });

  // Ported from upstream ayman708-UX/PlayTorrioV3 (e560d4a) -- splits the
  // generic 'spanish' tag into Castilian (Spain) vs Latino (Latin America)
  // variants with their own badges, on top of the existing 'spanish' tag
  // (kept for anything that only wants "some Spanish dub, don't care which").
  group('Spanish Castilian & Latin American audio detection', () {
    test('detects Castilian Spanish from Castellano tag', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Gladiator.2000.1080p.BluRay.x264.Castellano.AC3',
        url: 'https://example.com',
      );
      final langs = source.getAudioLanguages();
      expect(langs.contains('spanish_castilian'), isTrue);
      expect(langs.contains('spanish'), isTrue);
      expect(langs.contains('spanish_latino'), isFalse);
      expect(source.hasAudioLanguage('spanish_castilian'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.hasAudioLanguage('spanish_latino'), isFalse);
      expect(source.getAudioBadge(), '🇪🇸 CAST');
    });

    test('detects Castilian Spanish from [CAST] tag', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Gladiator.2000.1080p.[CAST].mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish_castilian'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.getAudioBadge(), '🇪🇸 CAST');
    });

    test('detects Castilian Spanish from ES-ES tag', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Movie.2024.1080p.WEB-DL.ES-ES.mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish_castilian'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.getAudioBadge(), '🇪🇸 CAST');
    });

    test('detects Latin American Spanish from Latino tag', () {
      // Deliberately no "Dual Audio" here, unlike upstream's own version of
      // this test -- Mov's existing MULTI-takes-priority convention (see
      // "DownloadEverything Dual Audio Hindi release" above) means a real
      // "Dual Audio ... English" phrase legitimately earns the generic
      // MULTI badge over a specific-language one, same as it does for
      // Hindi. This test is about the Latino tag alone, not that priority
      // rule, so it isolates just that.
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Avengers.Endgame.2019.1080p.Latino-English.mkv',
        url: 'https://example.com',
      );
      final langs = source.getAudioLanguages();
      expect(langs.contains('spanish_latino'), isTrue);
      expect(langs.contains('spanish'), isTrue);
      expect(langs.contains('spanish_castilian'), isFalse);
      expect(source.hasAudioLanguage('spanish_latino'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.hasAudioLanguage('spanish_castilian'), isFalse);
      expect(source.getAudioBadge(), '🇲🇽 LAT');
    });

    test('detects Latin American Spanish from [LAT] tag', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Dune.Part.Two.2024.1080p.[LAT].mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish_latino'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.getAudioBadge(), '🇲🇽 LAT');
    });

    test('detects Latin American Spanish from ES-419 tag', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Movie.2024.1080p.WEB-DL.ES-419.AAC.mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish_latino'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.getAudioBadge(), '🇲🇽 LAT');
    });

    test('detects both Castilian and Latin American when both present', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Interstellar.2014.1080p.BluRay.Castellano.Latino.Eng.mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish_castilian'), isTrue);
      expect(source.hasAudioLanguage('spanish_latino'), isTrue);
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.getAudioBadge(), '🇪🇸 CAST / 🇲🇽 LAT');
    });

    test('detects generic Spanish and badges as SPA', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Movie.2024.1080p.Spanish.AAC5.1.mkv',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish'), isTrue);
      expect(source.hasAudioLanguage('spanish_castilian'), isFalse);
      expect(source.hasAudioLanguage('spanish_latino'), isFalse);
      expect(source.getAudioBadge(), '🇪🇸 SPA');
    });

    test('does not match subtitles listing as audio language', () {
      final source = StreamSource(
        addonName: 'Torrentio',
        title: 'Movie.2024.1080p.BluRay.x264\nSubs: Spanish, English, French',
        url: 'https://example.com',
      );
      expect(source.hasAudioLanguage('spanish'), isFalse);
      expect(source.hasAudioLanguage('spanish_castilian'), isFalse);
      expect(source.hasAudioLanguage('spanish_latino'), isFalse);
    });
  });
}
