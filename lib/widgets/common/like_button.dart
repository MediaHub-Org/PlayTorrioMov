import 'package:flutter/material.dart';

/// Red used for every "liked" state in the app.
const Color kLikedColor = Color(0xFFE50914);

/// How a [LikeButton] presents itself.
enum LikeButtonStyle {
  /// A filled pill with an icon and a "Like"/"Liked" label, for a detail
  /// page's action row.
  pill,

  /// A bare icon, for an app bar or a list row where there is no space for a
  /// label.
  icon,
}

/// The one "save this" toggle, for content types where saving is a boolean.
///
/// Audiobooks, Manga, Podcasts, Books and Music each had their own: two pill
/// variants, a bare `IconButton`, and two list-row hearts, in three different
/// reds. Worse, the two presentations had contradictory-looking colour rules —
/// the pill filled red and turned its icon *white*, the bare icon turned
/// *red*.
///
/// That contradiction is only apparent, and the rule is now written down here
/// rather than rediscovered per page: a filled pill needs a white icon to stay
/// legible against the red fill, while a bare icon has no fill and so must
/// carry the colour itself. Both are [kLikedColor]; they differ because the
/// backgrounds differ.
///
/// Deliberately **not** used for two things that look similar but are not a
/// boolean like:
///
///  * **Movies/Series** "Add to Library" — library membership, and a bookmark
///    rather than a heart because that is what it means.
///  * **Anime** status — a four-state picker (Watching / Plan to Watch /
///    Completed / Dropped). Collapsing it to a heart would delete the feature.
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final LikeButtonStyle style;

  /// Icon size. The pill's label scales with it.
  final double size;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    this.style = LikeButtonStyle.pill,
    this.size = 22,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.isLiked ? 'Liked' : 'Like';
    final semantics = widget.isLiked ? 'Remove from liked' : 'Add to liked';

    final child = widget.style == LikeButtonStyle.pill
        ? _buildPill(label)
        : _buildIcon();

    return Semantics(
      button: true,
      toggled: widget.isLiked,
      label: semantics,
      child: Tooltip(
        message: semantics,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : (_hovered ? 1.05 : 1.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String label) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isLiked ? kLikedColor : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isLiked ? kLikedColor : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            // White, not red: the fill behind it is already red.
            color: widget.isLiked ? Colors.white : Colors.white70,
            size: widget.size,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: widget.isLiked ? Colors.white : Colors.white70,
              fontSize: widget.size * 0.64,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        // Red, not white: there is no fill to sit against.
        color: widget.isLiked ? kLikedColor : Colors.white70,
        size: widget.size,
      ),
    );
  }
}
