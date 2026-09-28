import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The keys that activate a focused [InteractiveCardShell]. `final`, not
/// `const`: `LogicalKeyboardKey` overrides `==`, and the analyzer rejects
/// that inside a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

/// The hover/press interaction physics shared by every poster-style card in
/// the app (Movies, IPTV channels, ...): scale up + lift on hover, scale
/// down on press. Owns the animation, the caller supplies the content via
/// [builder], which receives the current hover/press state to drive its own
/// styling (poster glow, badge fade-in, etc).
///
/// A D-pad or keyboard taking focus here is treated as the same state as a
/// pointer hovering it -- [builder]'s `hovered` flag is true either way --
/// so every caller's poster glow and badge fade-in become the focus
/// indicator for free, with no second visual to design per card type.
/// `Enter`, `NumpadEnter`, a TV remote's select button and a gamepad's A
/// button all fire [onTap].
class InteractiveCardShell extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback onTap;

  /// Whether this should take focus as soon as it is built. Off by default,
  /// same reasoning as `HoverButton`'s own `autofocus`: a catalog row of
  /// several of these would fight over which one starts focused.
  final bool autofocus;

  /// Scale applied while pressed. Movies use 0.97, IPTV channels 0.96 --
  /// close enough to not matter, but kept per-caller rather than forced
  /// to one value.
  final double pressedScale;
  final double hoveredScale;

  const InteractiveCardShell({
    super.key,
    required this.builder,
    required this.onTap,
    this.autofocus = false,
    this.pressedScale = 0.97,
    this.hoveredScale = 1.045,
  });

  @override
  State<InteractiveCardShell> createState() => _InteractiveCardShellState();
}

class _InteractiveCardShellState extends State<InteractiveCardShell> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered || _focused;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
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
            scale: _pressed ? widget.pressedScale : (hovered ? widget.hoveredScale : 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
              child: widget.builder(context, hovered, _pressed),
            ),
          ),
        ),
      ),
    );
  }
}
