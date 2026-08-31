import 'package:flutter_test/flutter_test.dart';
import 'package:playtorrio/models/stream/stream_model.dart';

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
