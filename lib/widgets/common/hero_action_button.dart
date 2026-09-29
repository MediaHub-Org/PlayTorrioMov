import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import 'hover_button.dart';

/// The Play / Details pair on a hero slide, as one focusable control.
///
/// These were Material `ElevatedButton`/`OutlinedButton`s. Material's own
/// focus cue is a faint 10% overlay of the foreground color, which is
/// invisible on a saturated fill over a photo, so a remote moving across
/// them showed nothing at all -- reported on a TV as "no response when moving
/// the selector". Built on [HoverButton] instead, like every other target
/// here: explicit select/enter activation, the lean, and a real focus ring.
class HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Filled with the palette color (Play) or outlined (Details).
  final bool primary;

  final double iconSize;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double radius;

  const HeroActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
    required this.iconSize,
    required this.fontSize,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final fill = AppThemeService.currentPalette.value.primaryColor;
    final foreground =
        primary ? AppColors.onAccent : AppColors.onAccent.withValues(alpha: 0.80);
    return Semantics(
      button: true,
      child: HoverButton(
        scaleAmount: 1.05,
        showFocusRing: true,
        focusRingBorderRadius: radius + 4,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: primary ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: primary
                ? null
                : Border.all(
                    color: AppColors.onAccent.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
