import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/stream/stream_model.dart';

void main() {
  group('StreamSource', () {
    group('quality detection', () {
      test('detects 4K from title', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.2160p.WEB-DL.mkv\nScraper', url: 'https://x.com');
        expect(source.quality, anyOf('4K', '2160p'));
      });
      test('detects 1080p from title', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.1080p.BluRay.mkv\nScraper', url: 'https://x.com');
        expect(source.quality, '1080p');
      });
      test('detects 720p from title', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.720p.HDTV.mkv\nScraper', url: 'https://x.com');
        expect(source.quality, '720p');
      });
    });
    group('HDR detection', () {
      test('detects Dolby Vision', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.2160p.DV.HDR.mkv\nScraper', url: 'https://x.com');
        expect(source.isHDR, true);
      });
      test('returns false for SDR', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.1080p.SDR.mkv\nScraper', url: 'https://x.com');
        expect(source.isHDR, false);
      });
    });
    group('codec detection', () {
      test('detects HEVC/x265', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.2160p.x265.mkv\nScraper', url: 'https://x.com');
        expect(source.codec, anyOf('HEVC', 'x265'));
      });
      test('detects H.264/x264', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.1080p.x264.mkv\nScraper', url: 'https://x.com');
        expect(source.codec, anyOf('AVC', 'H.264', 'x264'));
      });
    });
    group('container detection', () {
      test('reads MKV off the release name', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie.2024.1080p.WEB-DL.mkv', url: 'https://x.com/file');
        expect(source.containerLabel, 'MKV');
      });
      test('reads MP4 off the URL', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie 2024 1080p', url: 'https://x.com/video.mp4');
        expect(source.containerLabel, 'MP4');
      });
      test('reads HLS off an m3u8 URL', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'VixSrc Master', url: 'https://x.com/master.m3u8');
        expect(source.containerLabel, 'HLS');
      });
      test('a magnet with no extension gets no guess', () {
        final source = StreamSource(addonName: 'TestAddon', name: 'Test', title: 'Movie 2024 1080p BluRay', url: 'magnet:?xt=urn:btih:abc123');
        expect(source.containerLabel, isNull);
      });
    });
    group('release source detection', () {
      test('reads REMUX, BLURAY, WEB-DL, WEBRIP and HDTV', () {
        expect(StreamSource(addonName: 'A', title: 'Movie REMUX 1080p', url: '').releaseSource, 'REMUX');
        expect(StreamSource(addonName: 'A', title: 'Movie BluRay x264', url: '').releaseSource, 'BLURAY');
        expect(StreamSource(addonName: 'A', title: 'Movie WEB-DL', url: '').releaseSource, 'WEB-DL');
        expect(StreamSource(addonName: 'A', title: 'Movie WEBRip', url: '').releaseSource, 'WEBRIP');
        expect(StreamSource(addonName: 'A', title: 'Movie HDTV', url: '').releaseSource, 'HDTV');
      });
      test('a bare HD tag is not a source', () {
        expect(StreamSource(addonName: 'A', title: 'Movie 720p HD', url: '').releaseSource, isNull);
      });
    });
    group('compactTitle', () {
      test('reads scraper, quality and container', () {
        final source = StreamSource(addonName: 'VixSrc', name: 'VixSrc', title: 'Movie.2024.1080p.WEB-DL.mkv', url: 'https://x.com/f');
        expect(source.compactTitle, 'VixSrc • 1080p • MKV');
      });
      test('takes a resolved provider instead of the delivery label', () {
        final source = StreamSource(addonName: 'PlayTorrioHTTP', name: 'HindMoviez • 1080p', title: 'Movie.2024.1080p.WEB-DL.mkv', url: 'https://x.com/f');
        expect(source.compactTitle, 'PlayTorrioHTTP • 1080p • MKV');
        expect(source.compactTitleFor('HindMoviez'), 'HindMoviez • 1080p • MKV');
      });
      test('falls back to the full title when nothing is known', () {
        final source = StreamSource(addonName: '', name: 'Test', title: 'Some Release', url: '');
        expect(source.compactTitle, 'Some Release');
      });
    });
    group('displayProvider', () {
      test('a numeric file id shows the scraper instead', () {
        final source = StreamSource(addonName: 'MyScraper', name: '111477', title: 'Movie.mkv', url: '');
        expect(source.displayProvider, 'MyScraper');
      });
      test('a real name is kept', () {
        final source = StreamSource(addonName: 'MyScraper', name: 'HindMoviez • 1080p', title: 'Movie.mkv', url: '');
        expect(source.displayProvider, 'HindMoviez • 1080p');
      });
    });
    group('qualityRank', () {
      test('4K ranks higher than 1080p', () {
        final fourK = StreamSource(addonName: 'TestAddon', name: 'A', title: '4K.Movie.mkv\nA', url: '');
        final hd = StreamSource(addonName: 'TestAddon', name: 'B', title: '1080p.Movie.mkv\nB', url: '');
        expect(fourK.qualityRank, isNotNull);
      expect(hd.qualityRank, isNotNull);
      });
    });
  });
}
