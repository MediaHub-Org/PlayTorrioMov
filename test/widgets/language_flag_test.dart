// test/widgets/language_flag_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/subtitles/subtitle_languages.dart';
import 'package:playtorriomov/widgets/player/language_flag.dart';

void main() {
  group('languageCountryCode', () {
    test('keys on the display name, not on ISO-code substrings', () {
      expect(languageCountryCode('Spanish'), 'es');
      expect(languageCountryCode('Spanish (Latin America)'), 'es');
      expect(languageCountryCode('Portuguese (BR)'), 'br');
      // "Chinese" contains "hi"; it once drew the Indian flag.
      expect(languageCountryCode('Chinese (Simplified)'), 'cn');
      expect(languageCountryCode('Hindi'), 'in');
    });

    test('Malayalam is not Malay', () {
      // "Malayalam" contains "malay"; without its own row it drew Malaysia's flag.
      expect(languageCountryCode('Malayalam'), 'in');
      expect(languageCountryCode('Malay'), 'my');
    });

    test('the languages that once fell back to the globe have a flag', () {
      for (final name in [
        'Albanian', 'Bengali', 'Bosnian', 'Catalan', 'Icelandic', 'Kurdish',
        'Macedonian', 'Malay', 'Mongolian', 'Pashto', 'Sinhala', 'Slovak',
        'Slovenian', 'Somali', 'Swahili',
      ]) {
        expect(languageCountryCode(name), isNotNull, reason: name);
      }
    });

    test('the subtitle name table knows the ones it was missing', () {
      for (final code in ['ku', 'mn', 'ps', 'si', 'so', 'sw']) {
        final name = subtitleLanguageName(code);
        expect(name.length, greaterThan(2), reason: '$code stays a raw code');
        expect(languageCountryCode(name), isNotNull, reason: '$code -> $name');
      }
    });

    test('is null for a language with no flag', () {
      expect(languageCountryCode('Klingon'), isNull);
      expect(languageCountryCode(''), isNull);
      expect(languageCountryCode(null), isNull);
    });

    test('every flag it can name is bundled', () {
      // A code with no PNG would silently fall back to the globe.
      for (final name in [
        'arabic', 'english', 'portuguese', 'spanish', 'french', 'german',
        'italian', 'russian', 'japanese', 'korean', 'chinese', 'hindi',
        'turkish', 'dutch', 'swedish', 'norwegian', 'danish', 'finnish',
        'polish', 'ukrainian', 'greek', 'czech', 'hungarian', 'romanian',
        'persian', 'croatian', 'serbian', 'bulgarian', 'hebrew',
        'indonesian', 'vietnamese', 'thai', 'tagalog', 'filipino',
        'albanian', 'bengali', 'bosnian', 'catalan', 'icelandic', 'kurdish',
        'macedonian', 'malay', 'mongolian', 'pashto', 'sinhala', 'slovak',
        'slovenian', 'somali', 'swahili',
      ]) {
        final code = languageCountryCode(name);
        expect(code, isNotNull, reason: name);
        expect(File('assets/flags/$code.png').existsSync(), isTrue,
            reason: 'assets/flags/$code.png for $name');
      }
    });
  });

  group('LanguageFlag', () {
    testWidgets('draws an image, not emoji text, for a known language',
        (tester) async {
      // Windows has no flag glyphs in its emoji font, so a flag drawn as
      // text shows as its two bare letters there.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LanguageFlag('Spanish'))),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('🇪🇸'), findsNothing);
    });

    testWidgets('falls back to the globe for an unknown language',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LanguageFlag('Klingon'))),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('🌐'), findsOneWidget);
    });
  });
}
