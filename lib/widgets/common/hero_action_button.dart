import 'package:flutter/material.dart';

import '../../services/app_units.dart';
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
/// here: explicit select/enter, the lean, and a real focus ring.
///
/// Sizes come from [AppRem] and [AppType], so both buttons in a pair are the
/// same height and scale with the text size; the only choice a caller makes
/// is [compact] (a phone).
class HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Filled with the palette color (Play) or outlined (Details).
  final bool primary;

  /// The phone's smaller size.
  final bool compact;

  const HeroActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final fill = AppThemeService.currentPalette.value.primaryColor;
    final foreground =
        primary ? AppColors.onAccent : AppColors.onAccent.withValues(alpha: 0.80);
    final radius = context.rem(AppRem.radiusMd);
    return Semantics(
      button: true,
      child: HoverButton(
        scaleAmount: 1.05,
        showFocusRing: true,
        focusRingBorderRadius: radius + context.rem(AppRem.xs),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rem(
              compact ? AppRem.controlXCompact : AppRem.controlX,
            ),
            vertical: context.rem(
              compact ? AppRem.controlYCompact : AppRem.controlY,
            ),
          ),
          decoration: BoxDecoration(
            color: primary ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: primary
                ? null
                : Border.all(
                    color: AppColors.onAccent.withValues(alpha: 0.18),
                    width: 1, // px: a hairline stays a hairline at any text size
                  ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: fill.withValues(alpha: 0.45),
                      blurRadius: context.rem(AppRem.lg),
                      offset: Offset(0, context.rem(AppRem.xs)),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: context.rem(compact ? AppRem.icon : AppRem.iconLg),
                color: foreground,
              ),
              SizedBox(width: context.rem(AppRem.sm)),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? AppType.body : AppType.bodyLg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
