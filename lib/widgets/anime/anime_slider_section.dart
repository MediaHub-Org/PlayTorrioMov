import 'package:flutter/material.dart';

import '../../models/anime/anime_media.dart';
import '../../widgets/common/browse_row_view.dart';
import '../../widgets/movie/movie_card.dart';
import 'anime_card.dart';

/// An anime row: a [BrowseRowView] with [AnimeCard] as the item builder.
///
/// Used by the Anime page and the anime search page. It used to be a full
/// second copy of the row -- same `MovieCardSizing`, same [SectionHeader],
/// same hover arrows -- which meant two adjacent screens could drift apart on
/// card size, spacing or arrow behaviour with nothing to stop them.
class AnimeSliderSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<AnimeMedia> animeList;
  final void Function(AnimeMedia) onAnimeTap;
  final VoidCallback? onSeeAll;

  const AnimeSliderSection({
    super.key,
    required this.title,
    required this.animeList,
    required this.onAnimeTap,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return BrowseRowView<AnimeMedia>(
      title: title,
      subtitle: subtitle,
      items: animeList,
      onSeeAll: onSeeAll,
      itemBuilder: (context, anime) => AnimeCard(
        anime: anime,
        width: MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width)
            .cardWidth,
        onTap: () => onAnimeTap(anime),
      ),
    );
  }
}
