// test/services/title_display_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/models/anime/anime_media.dart';
import 'package:playtorriomov/models/my_list/my_list_item.dart';
import 'package:playtorriomov/services/theme/app_theme_service.dart';
import 'package:playtorriomov/services/titles/title_display.dart';

/// The rule this guards is the one docs/CONVENTIONS.md calls out as the thing
/// that "breaks things that look unrelated": a title is two fields, and only
/// one of them is localizable.
///
/// The failure it prevents is not a wrong label. It is a *different object*:
/// `MyListItem.uniqueKey` falls back to `title:$type:$clean:$year` when there
/// is no IMDb, TMDB, Trakt or Simkl id, and anime saved from AniList takes that
/// branch by design. Localize the title that feeds it and the same show saved
/// with the setting on stops matching the one saved with it off, which takes
/// collection membership, Continue Watching dedupe and Trakt/Simkl matching
/// with it.
AnimeMedia anime() => AnimeMedia(
      id: 1,
      titleRomaji: 'Shingeki no Kyojin',
      titleEnglish: 'Attack on Titan',
      titleNative: '進撃の巨人',
      titleUserPreferred: 'Shingeki no Kyojin',
      seasonYear: 2013,
    );

void main() {
  tearDown(() => AppThemeService.preferNativeTitles.value = false);

  test('the canonical title does not move when the preference does', () {
    final show = anime();
    expect(show.canonicalTitle, 'Attack on Titan');

    AppThemeService.preferNativeTitles.value = true;
    expect(
      show.canonicalTitle,
      'Attack on Titan',
      reason: 'this is what scrapers query and what identity falls back to',
    );
  });

  test('the displayed title does move', () {
    final show = anime();
    expect(animeDisplayTitle(show), 'Attack on Titan');

    AppThemeService.preferNativeTitles.value = true;
    expect(animeDisplayTitle(show), '進撃の巨人');
  });

  test('identity survives the preference being flipped', () {
    // Built the way the anime details page builds it: from the named title
    // fields, never from the displayed one.
    MyListItem saved(AnimeMedia show) => MyListItem(
          title: show.titleUserPreferred.isNotEmpty
              ? show.titleUserPreferred
              : show.titleRomaji,
          year: show.seasonYear,
          type: 'anime',
          addedAt: DateTime(2026, 1, 1),
        );

    final show = anime();
    final before = saved(show).uniqueKey;

    AppThemeService.preferNativeTitles.value = true;
    expect(
      saved(show).uniqueKey,
      before,
      reason: 'a show saved with native titles on has to be the same object as '
          'the one saved with them off, or the library splits in two',
    );
  });

  test('a show with no native title still displays something', () {
    // An addon-sourced anime arrives with one title copied into every field,
    // and the Arabic catalog does the same. Asking for the native one must not
    // produce an empty heading.
    const bare = AnimeMedia(
      id: 2,
      titleRomaji: 'Only One Title',
      titleEnglish: 'Only One Title',
      titleNative: '',
      titleUserPreferred: '',
    );
    AppThemeService.preferNativeTitles.value = true;
    expect(animeDisplayTitle(bare), 'Only One Title');
  });
}
