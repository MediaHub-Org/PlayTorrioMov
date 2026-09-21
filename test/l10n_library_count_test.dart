// test/l10n_library_count_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/l10n/app_localizations_ar.dart';
import 'package:playtorriomov/l10n/app_localizations_en.dart';
import 'package:playtorriomov/l10n/app_localizations_es.dart';

void main() {
  test('a library shelf count agrees with its number, in each language', () {
    final en = AppLocalizationsEn();
    expect(en.libraryTitleCount(1), '1 title');
    expect(en.libraryTitleCount(0), '0 titles');
    expect(en.libraryTitleCount(12), '12 titles');

    expect(AppLocalizationsEs().libraryTitleCount(1), '1 título');
    expect(AppLocalizationsEs().libraryTitleCount(3), '3 títulos');

    // Arabic has six plural forms; a single "other" would read wrong for
    // most counts.
    final ar = AppLocalizationsAr();
    expect(ar.libraryTitleCount(1), 'عنوان واحد');
    expect(ar.libraryTitleCount(2), 'عنوانان');
    expect(ar.libraryTitleCount(5), '5 عناوين');
    expect(ar.libraryTitleCount(15), '15 عنوانًا');
  });
}
