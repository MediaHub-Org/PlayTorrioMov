import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';

/// A focus indicator for D-pad/keyboard navigation: a rounded ring drawn
/// just outside the widget it wraps, shown when [visible].
///
/// Originated on the player transport controls, which were built
/// pointer-first -- `GestureDetector`, no `Focus` -- so a remote's
/// directional pad could not reach them at all, and a keyboard's Tab key
/// moved focus invisibly; every `PlayerIconButton` and slider wraps itself
/// in a `Focus` and shows this ring when it has it. Moved here so the same
/// clear cue is available for small or plain controls elsewhere in the app
/// -- a bare icon button, a text pill, a scroll arrow -- where a
/// hover/focus scale-lean (see `HoverButton`) reads as too subtle to
/// notice.
class FocusRing extends StatelessWidget {
  final bool visible;
  final double borderRadius;
  final Widget child;

  const FocusRing({
    super.key,
    required this.visible,
    this.borderRadius = 9999,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      // A little outside the widget, so the ring reads as marking it rather
      // than as a border of it.
      padding: const EdgeInsets.all(2),
      child: child,
    );
  }
}
