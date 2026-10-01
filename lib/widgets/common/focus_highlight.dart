import 'package:flutter/material.dart';

import 'focus_ring.dart';

/// Marks focus on a control that owns its own focus node -- a
/// Material `IconButton`, a `PopupMenuButton`, an `InkWell` -- when anything
/// inside it holds focus.
///
/// Those controls' built-in focus cue is a faint overlay of their foreground
/// color, which disappears on a translucent pill or a dark bar; on a TV the
/// filter pills and the Search and Settings buttons showed nothing while the
/// remote was on them. [HoverButton] wraps its own child and so can draw the
/// ring itself; these cannot, so the ring is drawn from outside.
class FocusHighlight extends StatefulWidget {
  final double borderRadius;
  final Widget child;

  const FocusHighlight({
    super.key,
    this.borderRadius = 9999,
    required this.child,
  });

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: FocusRing(
        visible: _focused,
        borderRadius: widget.borderRadius,
        // A soft wash, not a ring: see [FocusRing.soft].
        soft: true,
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
