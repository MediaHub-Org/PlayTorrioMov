import 'package:flutter/material.dart';

/// A tappable thing that leans in slightly under a pointer.
///
/// Extracted from `details_page.dart`, where it was private and used seven
/// times: the scroll arrows on five rails, the credit card and the similar
/// card. The cards moved out to be probeable at a large text scale, and this
/// had to come with them rather than be copied.
///
/// It takes its content as [child], which is worth knowing about: the icon in
/// an arrow button is therefore *not* lexically inside this gesture detector,
/// so a source scan looking for "an Icon in a GestureDetector" cannot see
/// through it. That is how ten unlabelled arrows on the details page went
/// uncounted. A caller wrapping an icon-only control in one of these has to
/// label it at the call site.
class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// How far it leans in. The default is the gentle one used on cards; the
  /// rails' arrows ask for more, because they are small and float over
  /// content.
  final double scaleAmount;

  const HoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleAmount = 1.04,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? widget.scaleAmount : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
