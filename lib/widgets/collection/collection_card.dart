// lib/widgets/collection/collection_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';

/// The three ways a card's square can be filled. Named so the choice can be
/// asserted without rendering a network image in a test.
enum CollectionArt {
  /// [CollectionCard.icon] on a tinted ground: nothing to show, or a built-in
  /// shelf whose icon is its identity.
  icon,

  /// One poster filling the square.
  single,

  /// Four posters in a 2x2.
  mosaic,
}

/// A square card for one shelf in the Library: a user collection, or one of
/// the three built-in states pinned before them.
///
/// Square, not poster-shaped, and that is the point. A 2:3 tile is a *title*
/// -- it is what Movies, Series, Anime and the Library's own grids use, and a
/// collection rendered that way would read as one more film. Spotify and
/// YouTube Music draw the same distinction: tracks are rows, the things that
/// hold tracks are squares. Here the square says "this opens a list", so
/// Liked, Watchlist, Watched and a collection called "Weekend" all look like
/// what they are -- containers -- while everything inside them stays 2:3.
///
/// Artwork follows from how much there is. Four posters or more tile into a
/// 2x2, which is the shape that reads as "several things"; one to three show
/// the first poster filling the square, because a 2x2 with holes in it reads
/// as broken rather than sparse. Nothing at all falls back to [icon] on a
/// tinted ground, so an empty collection still gets a card instead of being
/// hidden until it earns one.
class CollectionCard extends StatelessWidget {
  final String title;

  /// Shown under the title. The count, usually.
  final String subtitle;

  /// Up to four posters. Fewer is fine; see the class comment.
  final List<String> posters;

  /// Stands in when there are no posters, and identifies the built-in
  /// shelves, whose artwork is always their icon.
  final IconData icon;

  /// Tints the artwork ground and the fallback icon. Lets Liked, Watchlist
  /// and Watched keep the colours they carry everywhere else in the app.
  final Color accent;

  /// Built-in shelves draw their icon even when they hold posters, so Liked
  /// stays recognisably Liked however its contents change.
  final bool alwaysUseIcon;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CollectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.posters = const [],
    this.alwaysUseIcon = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildArt(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.inkSubtle, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  /// One to three posters show the first one, because a 2x2 with holes in it
  /// reads as broken rather than sparse.
  @visibleForTesting
  CollectionArt get artKind {
    if (alwaysUseIcon || posters.isEmpty) return CollectionArt.icon;
    return posters.length >= 4 ? CollectionArt.mosaic : CollectionArt.single;
  }

  /// The posters this card will actually draw, in order.
  @visibleForTesting
  List<String> get visiblePosters => switch (artKind) {
    CollectionArt.icon => const [],
    CollectionArt.single => [posters.first],
    CollectionArt.mosaic => posters.take(4).toList(),
  };

  Widget _buildArt() => switch (artKind) {
    CollectionArt.icon => _buildIconArt(),
    CollectionArt.single => _buildPoster(visiblePosters.first),
    CollectionArt.mosaic => _buildMosaic(),
  };

  Widget _buildIconArt() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.42),
            accent.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 34, color: AppColors.ink),
      ),
    );
  }

  Widget _buildMosaic() {
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final p in visiblePosters) _buildPoster(p)],
    );
  }

  Widget _buildPoster(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // A fixed dark fill in either theme: it is standing in for a picture,
      // the same choice the details pages make for a poster that has not
      // arrived yet.
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF15171F)),
      errorWidget: (_, __, ___) => _buildIconArt(),
    );
  }
}
