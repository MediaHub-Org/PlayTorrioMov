import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'reading_direction.dart';

/// A title's own logo where its metadata has one, its name where it does not
/// or the image cannot be loaded.
///
/// The details page, the sources page and the player's loading screen each
/// built this by hand, with the same fallback and slightly different sizes.
/// The sizes are the caller's -- the three sit on different backdrops and at
/// different distances -- and the behavior is shared: a logo that fails to
/// load falls back to the name rather than leaving a hole.
class TitleOrLogo extends StatelessWidget {
  /// The transparent logo image, or null/empty when the title has none.
  final String? logoUrl;

  /// What to show when there is no logo.
  final String name;

  /// The logo is contained in this box, so a wide wordmark and a tall emblem
  /// both fit without dwarfing what is next to them.
  final double maxLogoWidth;
  final double maxLogoHeight;

  final double fontSize;
  final double letterSpacing;
  final Color color;

  /// The name's drop shadow, which is what keeps it legible over artwork.
  final double shadowBlur;
  final double shadowOffsetY;

  /// Where a logo smaller than its box sits. Mirrored for right-to-left.
  final Alignment logoAlignment;

  final TextAlign? textAlign;
  final int? maxLines;

  /// Shown in place of the logo while it loads. Null shows nothing.
  final Widget? placeholder;

  const TitleOrLogo({
    super.key,
    required this.logoUrl,
    required this.name,
    required this.maxLogoWidth,
    required this.maxLogoHeight,
    required this.fontSize,
    required this.letterSpacing,
    required this.color,
    required this.shadowBlur,
    required this.shadowOffsetY,
    this.logoAlignment = Alignment.bottomLeft,
    this.textAlign,
    this.maxLines,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final logo = logoUrl;
    if (logo == null || logo.isEmpty) return _name(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxLogoWidth,
        maxHeight: maxLogoHeight,
      ),
      child: CachedNetworkImage(
        imageUrl: logo,
        alignment: mirroredIfRtl(context, logoAlignment),
        fit: BoxFit.contain,
        placeholder: placeholder == null ? null : (_, __) => placeholder!,
        errorWidget: (_, __, ___) => _name(context),
      ),
    );
  }

  Widget _name(BuildContext context) {
    return Text(
      name,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1.1, // ratio: a line height, not a size
        letterSpacing: letterSpacing,
        color: color,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffsetY),
          ),
        ],
      ),
    );
  }
}
