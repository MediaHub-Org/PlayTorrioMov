import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tappable thing that leans in slightly under a pointer -- and, since
/// #78, under a D-pad or keyboard focus too.
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
///
/// Focus reuses the hover lean rather than adding a second visual: a remote
/// or a keyboard moving focus here should be at least as visible as a mouse
/// hovering it, and a ring drawn around an arbitrary [child] would have to
/// guess at a shape this widget does not know. `Enter`, `NumpadEnter`, the
/// TV remote's select button and Space all fire [onTap], matching what a
/// screen reader's "activate" gesture already does for a focused control.
class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// How far it leans in. The default is the gentle one used on cards; the
  /// rails' arrows ask for more, because they are small and float over
  /// content.
  final double scaleAmount;

  /// Whether this should take focus as soon as it is built. Off by default:
  /// a screen with several of these would fight over which one starts
  /// focused, so a caller opts in deliberately for the one that should.
  final bool autofocus;

  const HoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleAmount = 1.04,
    this.autofocus = false,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    const activators = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
      LogicalKeyboardKey.space,
    };
    if (!activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
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
            scale: _isPressed
                ? 0.96
                : (_isHovered || _isFocused ? widget.scaleAmount : 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
