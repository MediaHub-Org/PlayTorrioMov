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
    test('no TMDB key is committed anywhere in lib/', () {
      // A key committed to a public repository gets scraped and revoked, and
      // rotating it means shipping a new binary. DOTENV_CONTENTS is where a
      // build's key belongs, read through TmdbSettings.effectiveApiKey.
      //
      // This check was once scoped to lib/services/tmdb and looked for a bare
      // 32-hex literal. It missed five live keys: they were written into the
      // middle of a URL -- `?api_key=b3556f...` -- across three scrapers,
      // where no literal is 32 characters on its own.
      //
      // Widening it to any 32-hex run in lib/ then caught four things that are
      // not keys at all: an R2 bucket subdomain, a CDN filename, and a site
      // cookie in two places. So both halves are matched precisely instead:
      // a key spelled into a URL, and a bare key literal in a file that talks
      // to TMDB.
      final inUrl = RegExp(r'api_key=[0-9a-fA-F]{32}');
      final bareLiteral = RegExp(r"'[0-9a-fA-F]{32}'");
      final offenders = <String>[];

      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final src = file.readAsStringSync();

        final url = inUrl.firstMatch(src);
        if (url != null) offenders.add('${file.path}: ${url.group(0)}');

        if (src.contains('themoviedb.org')) {
          final bare = bareLiteral.firstMatch(src);
          if (bare != null) offenders.add('${file.path}: ${bare.group(0)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'read the key from TmdbSettings.effectiveApiKey and put its '
            'value in the DOTENV_CONTENTS secret',
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
