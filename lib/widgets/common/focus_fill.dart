import 'package:flutter/material.dart';

import '../../services/theme/app_colors.dart';

/// Marks a row that holds focus with a soft wash drawn *over* it, in its own
/// bounds. No border: on a settings page the fill alone reads clearly, and the
/// outline made every row look like a button box (#80).
///
/// For the settings rows and cards, which are an `InkWell` over an opaque
/// `Container`: the `InkWell`'s focus tint is painted on the `Material`
/// underneath, so the container's own fill covers it, and a remote moving
/// down a settings page showed nothing at all (#80). Drawing the cue on top,
/// from outside the `InkWell`, does not depend on what is inside it.
///
/// Takes no layout room and no focus of its own: it only listens for focus
/// anywhere inside [child]. [HoverButton.focusFillRadius] does the same job
/// for a chip; this is for something that already owns its own focus node.
class FocusFill extends StatefulWidget {
  /// The corner radius of what it covers.
  final double radius;
  final Widget child;

  const FocusFill({super.key, required this.radius, required this.child});

  @override
  State<FocusFill> createState() => _FocusFillState();
}

class _FocusFillState extends State<FocusFill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Stack(
        // Passthrough, so the row keeps the constraints it would have had.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  // Stronger than a bordered cue would need, since the fill is
                  // all there is to see.
                  color: _focused
                      ? AppColors.accent.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
