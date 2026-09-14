// lib/widgets/common/setting_choice_chip.dart
import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';

/// One option in a short row of mutually exclusive choices — hero style,
/// card density, which tab a screen opens on.
///
/// Ten call sites across Live TV's settings page, its portals modal and the
/// portal browser had this chip written out in full, all ten agreeing on the
/// same six styling properties: the accent at 0.25 behind the selection, the
/// bar colour behind the rest, a 12px label that goes accent-coloured and
/// heavier when picked, and a border at 0.6 of the accent or 0.08 of the ink.
/// The audit counted the result as 45 duplicated windows between two of those
/// files; it is one widget, so here it is.
///
/// [onSelect] fires only when this chip becomes the selection. Material's
/// `onSelected` also reports a chip being *un*-selected, which none of these
/// rows want — every one of them had written the same `if (selected)` guard
/// around its body.
class SettingChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;

  /// Called when this chip is chosen. Callers that do not listen to the
  /// setting they are writing pass their own `setState` in here.
  final VoidCallback onSelect;

  const SettingChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Paints from AppColors, which reads globals rather than an inherited
    // widget, so this is what makes a chip follow a theme change.
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: palette.primaryColor.withValues(alpha: 0.25),
      backgroundColor: AppColors.bar,
      labelStyle: TextStyle(
        color: selected ? palette.primaryColor : AppColors.inkMuted,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? palette.primaryColor.withValues(alpha: 0.6)
            : AppColors.inkAlpha(0.08),
      ),
      onSelected: (isSelected) {
        if (isSelected) onSelect();
      },
    );
  }
}
