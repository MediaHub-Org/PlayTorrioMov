import 'package:flutter/material.dart';

/// The hover/press interaction physics shared by every poster-style card in
/// the app (Movies, IPTV channels, ...): scale up + lift on hover, scale
/// down on press. Owns the animation, the caller supplies the content via
/// [builder], which receives the current hover/press state to drive its own
/// styling (poster glow, badge fade-in, etc).
class InteractiveCardShell extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback onTap;

  /// Scale applied while pressed. Movies use 0.97, IPTV channels 0.96 --
  /// close enough to not matter, but kept per-caller rather than forced
  /// to one value.
  final double pressedScale;
  final double hoveredScale;

  const InteractiveCardShell({
    super.key,
    required this.builder,
    required this.onTap,
    this.pressedScale = 0.97,
    this.hoveredScale = 1.045,
  });

  @override
  State<InteractiveCardShell> createState() => _InteractiveCardShellState();
}

class _InteractiveCardShellState extends State<InteractiveCardShell> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          scale: _pressed ? widget.pressedScale : (_hovered ? widget.hoveredScale : 1.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
            child: widget.builder(context, _hovered, _pressed),
          ),
        ),
      ),
    );
  }
}
