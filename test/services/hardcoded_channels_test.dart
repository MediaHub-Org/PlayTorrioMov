import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/iptv/hardcoded_channels.dart';

/// The channel behind a portal stream name, or null when no built-in
/// claims it. Tests match the way the app does: keywords plus excludes
/// straight off the entry.
HardcodedChannel? resolve(String streamName) {
  for (final channel in HardcodedChannels.all) {
    if (HardcodedChannels.matches(
      streamName,
      channel.keywords,
      channel.exclude,
    )) {
      return channel;
    }
  }
  return null;
}

void main() {
  group('new language rows', () {
    test('each new category resolves its channels', () {
      expect(HardcodedChannels.byCategory('Spanish').length, 4);
      expect(HardcodedChannels.byCategory('German').length, 5);
      expect(HardcodedChannels.byCategory('Russian').length, 4);
      expect(HardcodedChannels.byCategory('Chinese').length, 4);
    });

    test('Spanish portal names land on the right tile', () {
      expect(resolve('ES | LA 1 HD')?.id, 'la1');
      expect(resolve('ES | LA 2 HD')?.id, 'la2');
      expect(resolve('ES | CANAL 24H')?.id, 'tve24h');
      expect(resolve('ES | TELEDEPORTE HD')?.id, 'teledeporte');
    });

    test('La 2 does not eat the 24h news channel', () {
      // `la 2` is a substring of `la 24`, so the La 2 entry excludes it;
      // without that every 24h feed filed under entertainment.
      expect(resolve('ES | LA 24H')?.id, isNot('la2'));
      expect(resolve('ES | LA 24H')?.id, 'tve24h');
    });

    test('German portal names land on the right tile', () {
      expect(resolve('DE | DAS ERSTE HD')?.id, 'das_erste');
      expect(resolve('DE | ZDF HD')?.id, 'zdf');
      expect(resolve('DE | RTL HD')?.id, 'rtl_de');
      expect(resolve('DE | N-TV')?.id, 'ntv_de');
      expect(resolve('DE | WELT HD')?.id, 'welt');
    });

    test('the two NTVs stay apart', () {
      // Same letters, different channels: the German entry only knows the
      // German spellings and the Russian one only the Russian ones.
      expect(resolve('DE | N-TV')?.id, 'ntv_de');
      expect(resolve('NTV Russia HD')?.id, 'ntv_ru');
      expect(resolve('NTV Mir')?.id, 'ntv_ru');
    });

    test('Russian portal names land on the right tile', () {
      expect(resolve('RU | PERVIY KANAL HD')?.id, 'channel_one_ru');
      expect(resolve('RU | ROSSIYA 1 HD')?.id, 'rossiya1');
      expect(resolve('RU | RUSSIA TODAY HD')?.id, 'rt_news');
    });

    test('Chinese portal names land on the right tile', () {
      expect(resolve('CN | CCTV-1 HD')?.id, 'cctv1');
      expect(resolve('CN | CCTV-4 HD')?.id, 'cctv4');
      expect(resolve('CN | CCTV NEWS')?.id, 'cctv_news');
      expect(resolve('CN | CGTN HD')?.id, 'cgtn');
    });
  });
}
