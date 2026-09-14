import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:playtorriomov/services/my_list/my_list_service.dart';
import 'package:playtorriomov/services/tmdb/tmdb_settings.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Initialize services that the app needs
    SharedPreferences.setMockInitialValues({});
    await MyListService.initialize();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('PlayTorrio'),
          ),
        ),
      ),
    );

    expect(find.text('PlayTorrio'), findsOneWidget);
  });

  group('TmdbSettings', () {
    // This group used to assert the opposite: that a fallback key shipped in
    // the source. That key was found and revoked -- which is what the 401 on
    // v1.6.2 was -- so the contract it pinned was the bug.
    test('the app ships no TMDB key of its own', () {
      // A key committed to a public repository gets scraped and revoked, and
      // rotating it means shipping a new binary. `ENV_FILE` is where a build's
      // key belongs. This is the check that notices a constant creeping back.
      final offenders = <String>[];
      for (final file in Directory('lib/services/tmdb').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final match = RegExp("'[0-9a-fA-F]{32}'").firstMatch(file.readAsStringSync());
        if (match != null) offenders.add('${file.path}: ${match.group(0)}');
      }
      expect(
        offenders,
        isEmpty,
        reason: 'a 32-hex literal here is a TMDB key; put it in ENV_FILE instead',
      );
    });

    test('a build given no TMDB_API_KEY ships without a key', () {
      // `flutter test` passes no --dart-define, so this is that build.
      expect(TmdbSettings.bundledApiKey, isNull);
      expect(TmdbSettings.effectiveApiKey, isNull);
      expect(TmdbSettings.isConfigured, isFalse);
    });

    test('a key the user pasted is the one requests use', () {
      addTearDown(() => TmdbSettings.apiKey.value = null);
      TmdbSettings.apiKey.value = 'a-user-key';
      expect(TmdbSettings.effectiveApiKey, 'a-user-key');
      expect(TmdbSettings.isConfigured, isTrue);
    });
  });
}
