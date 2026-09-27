import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/metadata/bestsimilar_scraper.dart' show BSItem;
import '../../services/theme/app_colors.dart';
import '../common/hover_button.dart';

/// The details page's brand red, which the similarity chip outlines itself in.
/// Duplicated from `_Palette` rather than exported from it: that class is the
/// page's private theme, and a widget reaching into a page would point the
/// dependency backwards.
const _accent = Color(0xFFE50914);

/// One suggestion on a details page's "Similar" rail: poster, title, and the
/// year and genre under it.
///
/// Public and self-contained for the same reason as [CreditCard]: the rail's
/// height is fixed by the page, so whether its two text lines stay inside that
/// budget at a large text scale was arithmetic nobody could measure. It is
/// measured now — see `test/text_scale_overflow_test.dart`.
class SimilarCard extends StatelessWidget {
  final BSItem item;

  /// The card's width. The rail picks it from the layout (160 on desktop, 130
  /// on a phone) and the height follows from it, so the two cannot drift.
  final double width;

  final VoidCallback onTap;

  const SimilarCard({
    super.key,
    required this.item,
    required this.width,
    required this.onTap,
  });

  /// The card's full height for a given [width]: the poster's 2:3 plus a flat
  /// 64 for the two text lines.
  ///
  /// The rail sizes its `SizedBox` with this, which is why the text below is
  /// capped: those two lines want ~39px at 1.0 and ~96px at 3x, and 64 is all
  /// they get.
  static double heightFor(double width) => width * 1.5 + 64;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final subtitle = [
      if (item.year != null) '${item.year}',
      if (item.genre != null) item.genre!.split(',').first.trim(),
    ].join(' · ');

    return SizedBox(
      width: width,
      child: HoverButton(
        onTap: onTap,
        scaleAmount: 1.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: item.thumbUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.thumbUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const _PosterFallback(),
                          )
                        : const _PosterFallback(),
                  ),
                ),
                if (item.similarityPercent != null)
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: _Badge(
                      // The similarity chip is the one with an outline: it is
                      // this rail's own number rather than the title's, so it
                      // reads as a label on the card instead of a fact about
                      // the film.
                      border: _accent.withValues(alpha: 0.6),
                      child: Text(
                        '${item.similarityPercent}%',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (item.rating != null)
                  PositionedDirectional(
                    bottom: 6,
                    start: 6,
                    child: _Badge(
                      horizontal: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFC107),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // The poster takes the 2:3, so the title and the line under it
            // share a flat 64px. Capped the same way the Continue Watching
            // card's title block is, and for the same reason: the box is sized
            // by the rail and cannot grow (#69).
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              style: TextStyle(
                color: AppColors.inkDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A poster that will not load, and the one with no URL at all: the same thing.
class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.movie_rounded, color: AppColors.inkFaint, size: 36),
      ),
    );
  }
}

/// The similarity and rating chips over the poster. Same fill and corner,
/// different inset and outline, exactly as they were before they shared a
/// class.
class _Badge extends StatelessWidget {
  final Widget child;
  final double horizontal;
  final Color? border;

  const _Badge({required this.child, this.horizontal = 7, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: child,
    );
  }
}
