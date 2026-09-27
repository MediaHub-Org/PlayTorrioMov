import '../../models/anime/anime_media.dart';
import '../theme/app_theme_service.dart';

/// The title to show a reader, honoring their title-language preference.
///
/// A function in `services/` rather than a getter on the model, because a
/// model depends on nothing and this depends on a setting. Call it anywhere a
/// title is *rendered*; never where one is queried, matched or stored — those
/// want [AnimeMedia.canonicalTitle], and the difference is the whole point.
String animeDisplayTitle(AnimeMedia anime) =>
    anime.titleFor(native: AppThemeService.preferNativeTitles.value);
