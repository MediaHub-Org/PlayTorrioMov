import '../../models/anime/anime_media.dart';
import 'anilist_service.dart';
import 'kitsu_service.dart';

/// The TV seasons of one show, oldest first: the title itself and every TV
/// season linked to it as a sequel or a prequel, followed through the chain.
///
/// Each season is its own entry with its own episodes, so a season change is a
/// change of entry, not of episode numbering.
abstract final class AnimeSeasons {
  static const int _maxSeasons = 8;
  static final Map<int, List<AnimeMedia>> _cache = {};

  static Future<List<AnimeMedia>> of(AnimeMedia anime) async {
    final cached = _cache[anime.id];
    if (cached != null) return cached;

    final seen = <int>{};
    final queue = <AnimeMedia>[anime];
    final seasons = <AnimeMedia>[];
    while (queue.isNotEmpty && seen.length < _maxSeasons) {
      final node = queue.removeAt(0);
      if (!seen.add(node.id)) continue;
      if (node.format == 'TV') seasons.add(node);
      queue.addAll(await _neighbors(node));
    }
    seasons.sort((a, b) => a.seasonYear.compareTo(b.seasonYear));
    _cache[anime.id] = seasons;
    return seasons;
  }

  static Future<List<AnimeMedia>> _neighbors(AnimeMedia node) async {
    if (KitsuService.isKitsuId(node.id)) {
      return KitsuService.instance
          .seasonNeighbors(KitsuService.kitsuIdOf(node.id));
    }
    final full = await AnilistService.instance.fetchAnimeDetails(node.id);
    if (full == null) return const [];
    final linked = full.relations.where((r) =>
        (r.relationType == 'PREQUEL' || r.relationType == 'SEQUEL') &&
        r.format == 'TV');
    final fetched = await Future.wait(
      linked.map((r) => AnilistService.instance.fetchAnimeDetails(r.id)),
    );
    return fetched.whereType<AnimeMedia>().toList();
  }
}
