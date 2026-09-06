import 'package:flutter/material.dart';

/// Icon for a genre/category tag, shared by every content-detail page so a
/// given genre always reads the same way whether it's on a movie, a series,
/// or an anime.
IconData genreTagIcon(String genre) {
  final g = genre.toLowerCase();
  switch (g) {
    case 'action':
      return Icons.bolt_rounded;
    case 'adventure':
      return Icons.explore_rounded;
    case 'animation':
      return Icons.brush_rounded;
    case 'comedy':
      return Icons.theater_comedy_rounded;
    case 'crime':
      return Icons.gavel_rounded;
    case 'documentary':
      return Icons.videocam_rounded;
    case 'drama':
      return Icons.masks_rounded;
    case 'family':
      return Icons.family_restroom_rounded;
    case 'fantasy':
      return Icons.auto_awesome_rounded;
    case 'history':
      return Icons.history_edu_rounded;
    case 'horror':
      return Icons.mood_bad_rounded;
    case 'music':
    case 'musical':
      return Icons.music_note_rounded;
    case 'mystery':
      return Icons.search_rounded;
    case 'romance':
      return Icons.favorite_rounded;
    case 'science fiction':
    case 'sci-fi':
    case 'scifi':
      return Icons.rocket_launch_rounded;
    case 'thriller':
      return Icons.flash_on_rounded;
    case 'war':
    case 'war & politics':
      return Icons.military_tech_rounded;
    case 'western':
      return Icons.landscape_rounded;
    case 'sport':
    case 'sports':
      return Icons.sports_basketball_rounded;
    case 'kids':
      return Icons.child_care_rounded;
    case 'ecchi':
    case 'harem':
      return Icons.favorite_border_rounded;
    case 'isekai':
      return Icons.swap_horiz_rounded;
    case 'mecha':
      return Icons.smart_toy_rounded;
    case 'sci-fi & fantasy':
      return Icons.auto_awesome_rounded;
    case 'slice of life':
      return Icons.wb_sunny_rounded;
    case 'sports & competition':
      return Icons.emoji_events_rounded;
    case 'supernatural':
      return Icons.dark_mode_rounded;
    case 'talk':
      return Icons.mic_rounded;
    case 'news':
      return Icons.newspaper_rounded;
    case 'reality':
      return Icons.live_tv_rounded;
    default:
      return Icons.local_offer_rounded;
  }
}

/// A single row of icon-only genre/category tags that always fits on one
/// line — scrolls horizontally instead of wrapping when there isn't room
/// for all of them. Each icon carries the genre name as a [Tooltip] (hover
/// on desktop; long-press on touch) since the label itself isn't shown.
class GenreTagRow extends StatelessWidget {
  final List<String> genres;
  final ValueChanged<String>? onTap;
  final double size;

  const GenreTagRow({
    super.key,
    required this.genres,
    this.onTap,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final g = genres[index];
          return Tooltip(
            message: g,
            child: MouseRegion(
              cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
              child: GestureDetector(
                onTap: onTap == null ? null : () => onTap!(g),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(
                    genreTagIcon(g),
                    color: Colors.white70,
                    size: size * 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
