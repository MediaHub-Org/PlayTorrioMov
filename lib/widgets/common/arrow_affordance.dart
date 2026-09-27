import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Which way an arrow points, in reading order rather than in pixels.
enum ArrowSense {
  /// Backwards along the reading direction — left in English, right in Arabic.
  previous,

  /// Forwards along the reading direction.
  next,

  /// Up and down have no reading order to follow, so they never mirror.
  up,
  down,
}

/// Every arrow glyph the app uses on a scroll or paging control.
///
/// A map rather than a `switch` because the two sides of each entry are the
/// whole content: an arrow's glyph and its meaning are one fact, and keeping
/// them adjacent is what stops a new icon being added with the wrong label.
const Map<IconData, ArrowSense> _senses = {
  Icons.arrow_back_ios_new_rounded: ArrowSense.previous,
  Icons.arrow_back_ios_rounded: ArrowSense.previous,
  Icons.arrow_back_rounded: ArrowSense.previous,
  Icons.chevron_left_rounded: ArrowSense.previous,
  Icons.keyboard_arrow_left_rounded: ArrowSense.previous,
  Icons.arrow_forward_ios_rounded: ArrowSense.next,
  Icons.arrow_forward_rounded: ArrowSense.next,
  Icons.chevron_right_rounded: ArrowSense.next,
  Icons.keyboard_arrow_right_rounded: ArrowSense.next,
  Icons.keyboard_arrow_up_rounded: ArrowSense.up,
  Icons.expand_less_rounded: ArrowSense.up,
  Icons.keyboard_arrow_down_rounded: ArrowSense.down,
  Icons.expand_more_rounded: ArrowSense.down,
};

/// The sense of [icon], or null when it is not one of the app's arrows.
ArrowSense? arrowSenseOf(IconData icon) => _senses[icon];

/// Labels an arrow-shaped control from its own icon.
///
/// Reading the label off the glyph rather than taking it as a parameter is
/// deliberate. An arrow button's label and its glyph are the same fact, so a
/// label passed separately is a label that can drift — and these widgets are
/// shared: `SliderArrow` alone has six call sites, each of which would
/// otherwise have to be told what its own arrow means.
///
/// Returns null for an icon that is not an arrow, so a caller wraps nothing
/// rather than announcing something wrong.
String? arrowLabel(BuildContext context, IconData icon) {
  final sense = arrowSenseOf(icon);
  if (sense == null) return null;
  final l10n = context.l10n;
  return switch (sense) {
    ArrowSense.previous => l10n.commonPrevious,
    ArrowSense.next => l10n.commonNext,
    ArrowSense.up => l10n.commonScrollUp,
    ArrowSense.down => l10n.commonScrollDown,
  };
}

/// Gives an arrow-shaped control a hover label and a screen-reader label,
/// both read off [icon].
///
/// The `Semantics(button: true)` is what `IconButton` would have supplied for
/// free. These controls are a `GestureDetector` or an `InkWell` wrapped around
/// a bare `Icon`, so without it a screen reader announces neither a name nor
/// that the thing is pressable (#69).
class ArrowTooltip extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const ArrowTooltip({super.key, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final label = arrowLabel(context, icon);
    if (label == null) return child;
    return Tooltip(
      message: label,
      child: Semantics(button: true, label: label, child: child),
    );
  }
}
