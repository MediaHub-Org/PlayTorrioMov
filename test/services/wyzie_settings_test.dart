import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playtorriomov/services/subtitles/providers/wyzie_provider.dart';
import 'package:playtorriomov/services/subtitles/wyzie_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WyzieSettings.setApiKey(null);
  });

  test('no key until the user pastes one', () {
    expect(WyzieSettings.apiKey.value, isNull);
  });

  test('a pasted key is trimmed and kept', () async {
    await WyzieSettings.setApiKey('  wyzie-abc  ');
    expect(WyzieSettings.apiKey.value, 'wyzie-abc');
  });

  test('a blank key clears it rather than sending an empty one', () async {
    await WyzieSettings.setApiKey('wyzie-abc');
    await WyzieSettings.setApiKey('   ');
    expect(WyzieSettings.apiKey.value, isNull);
  });

  test('the key survives a restart', () async {
    await WyzieSettings.setApiKey('wyzie-abc');
    WyzieSettings.apiKey.value = null;
    await WyzieSettings.initialize();
    expect(WyzieSettings.apiKey.value, 'wyzie-abc');
  });

  group('WyzieProvider key', () {
    test('with no key of any kind it sends nothing and finds nothing', () async {
      expect(WyzieProvider.activeApiKey, isNull);
      expect(await WyzieProvider().search('Dune'), isEmpty);
    });

    test('a key the user pasted is the one a search would use', () async {
      await WyzieSettings.setApiKey('wyzie-mine');
      expect(WyzieProvider.activeApiKey, 'wyzie-mine');
    });
  });
}
