import 'package:flutter/material.dart';
import '../../app_info.dart';
import '../../services/app_breakpoints.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/app_colors.dart';

/// The app's logo and wordmark, shown in the header.
///
/// The wordmark shows at every width but a tablet's, where the header also
/// holds the section chips -- a header with only an icon does not tell a new
/// user what they have opened, so that is the one place it gives way. It is a
/// little smaller on phones, where the header also carries the settings
/// button.
class SidebarLogo extends StatelessWidget {
  /// Whether the wordmark is drawn beside the icon. Off only where the header
  /// has to share its row with the section chips on a tablet, which cannot
  /// hold both at 600px.
  final bool showWordmark;

  const SidebarLogo({super.key, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final isMobile = AppBreakpoints.of(context) == ScreenTier.mobile;
    final iconSize = isMobile ? 26.0 : 32.0;
    if (!showWordmark) {
      return Image.asset(
        'assets/icon.png',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icon.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
        SizedBox(width: isMobile ? 8 : 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppInfo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Clamped: this sits inside TopBar's fixed
                // height (TopBar.sharedHeight, 56) — a constant every
                // caller uses to inset content below the bar. Unclamped, a
                // large accessibility text size grows the wordmark past
                // that fixed height and overflows it (#69).
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: isMobile ? 16 : 18,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: isMobile ? 3 : 4),
              // The accent sits under the wordmark rather than beside it:
              // the icon already occupies the left, and a second mark there
              // would crowd a phone header that also carries Settings.
              // Underlining it reads as part of the wordmark and costs no
              // horizontal room, which is the scarce dimension here.
              _FilmStripRule(
                width: isMobile ? 34 : 40,
                height: isMobile ? 4 : 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A short film-strip rule: a bar with sprocket holes punched along it.
///
/// Drawn rather than shipped as an asset so it takes the theme's accent
/// color, and drawn as a single even-odd path rather than a bar with
/// holes painted over it -- the holes are genuinely transparent, so the
/// rule works over the header's gradient instead of only over one flat
/// color it happened to be designed against.
class _FilmStripRule extends StatelessWidget {
  final double width;
  final double height;

  const _FilmStripRule({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return SizedBox(
          height: height,
          // A short rule under the start of the wordmark, not a full
          // underline: stretching it to the available width would run it
          // far past the text on a desktop header, and reading the text's
          // own width here would cost an IntrinsicWidth for an accent.
          width: width,
          child: CustomPaint(
            painter: _FilmStripPainter(color: palette.primaryColor),
          ),
        );
      },
    );
  }
}

class _FilmStripPainter extends CustomPainter {
  final Color color;

  const _FilmStripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final radius = Radius.circular(size.height / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius),
      );

    // Perforations: square-ish, inset from the bar's edges, evenly spaced.
    // Spacing is derived from the height so the holes stay in proportion at
    // both the phone and desktop sizes rather than needing two constants.
    final holeSize = size.height * 0.5;
    final step = holeSize * 2.4;
    final top = (size.height - holeSize) / 2;
    final holeRadius = Radius.circular(holeSize * 0.3);

    for (double x = step * 0.6; x + holeSize < size.width; x += step) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, holeSize, holeSize),
          holeRadius,
        ),
      );
    }

    // Even-odd turns the hole rects into cut-outs instead of filled blobs.
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FilmStripPainter oldDelegate) =>
      oldDelegate.color != color;
}
