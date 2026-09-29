import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tv_mode_service.dart';

/// Lets a TV remote's Up/Down cross between the hub's content and the top
/// bar's section chips.
///
/// The content renders inside `NestedNavigator`'s own `Navigator`, and every
/// route gets its own focus scope. Directional traversal is confined to one
/// scope, so a D-pad could never leave the content for the chips outside it
/// (or come back) -- reported on a TV, and not something the widget tree can
/// express with a `FocusTraversalPolicy` short of merging the scopes.
///
/// This sits above both and steps in only when the normal move fails: it asks
/// the focused node to move in the pressed direction first
/// ([FocusNode.focusInDirection] says whether it did), and only when that
/// returns false does it hand focus across, so in-content navigation is never
/// second-guessed. TV only: on a keyboard the same keys belong to text fields.
class TvFocusBridge extends StatelessWidget {
  /// The debug label a chip's `Focus` carries; how the bridge finds them
  /// without the two widgets holding each other's nodes.
  static const chipLabel = 'SectionChip';

  final Widget child;

  const TvFocusBridge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _handleKey(event),
      child: child,
    );
  }

  static KeyEventResult _handleKey(KeyEvent event) {
    if (!TvModeService.isTv.value) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;

    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;

    final chips = FocusManager.instance.rootScope.descendants
        .where((n) => n.debugLabel == chipLabel && n.canRequestFocus)
        .toList();
    if (chips.isEmpty) return KeyEventResult.ignored;
    final barBottom =
        chips.map((n) => n.rect.bottom).reduce((a, b) => a > b ? a : b);
    final inBar = primary.rect.center.dy <= barBottom;

    // Ordinary traversal first. If it moves, that is the whole job.
    final direction = up ? TraversalDirection.up : TraversalDirection.down;
    if (primary.focusInDirection(direction)) return KeyEventResult.handled;

    if (up) {
      if (inBar) return KeyEventResult.ignored;
      // Prefer the chip above the focused card, so Up then Down round-trips.
      chips.sort((a, b) => (a.rect.center.dx - primary.rect.center.dx)
          .abs()
          .compareTo((b.rect.center.dx - primary.rect.center.dx).abs()));
      chips.first.requestFocus();
      return KeyEventResult.handled;
    }

    if (!inBar) return KeyEventResult.ignored;
    final below = FocusManager.instance.rootScope.traversalDescendants
        .where((n) => n.debugLabel != chipLabel && n.rect.top >= barBottom)
        .toList();
    if (below.isEmpty) return KeyEventResult.ignored;
    // The top-most row, and within it the node nearest the focused chip.
    final top = below.map((n) => n.rect.top).reduce((a, b) => a < b ? a : b);
    final firstRow = below.where((n) => n.rect.top - top < 8).toList()
      ..sort((a, b) => (a.rect.center.dx - primary.rect.center.dx)
          .abs()
          .compareTo((b.rect.center.dx - primary.rect.center.dx).abs()));
    firstRow.first.requestFocus();
    return KeyEventResult.handled;
  }
}
