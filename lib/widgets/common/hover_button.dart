import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/theme/app_colors.dart';
import 'focus_ring.dart';

/// The keys that activate a focused [HoverButton]. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that inside
/// a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
  LogicalKeyboardKey.space,
};

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
/// Focus reuses the hover lean by default rather than adding a second
/// visual: a remote or a keyboard moving focus here should be at least as
/// visible as a mouse hovering it, and a ring drawn around an arbitrary
/// [child] would have to guess at a shape this widget does not know.
/// `Enter`, `NumpadEnter`, the TV remote's select button and Space all fire
/// [onTap], matching what a screen reader's "activate" gesture already does
/// for a focused control.
///
/// [showFocusRing] opts back into that ring for a call site whose [child]
/// *does* have a known, plain shape -- a bare icon, a short line of text --
/// where the lean alone is easy to miss, especially at TV viewing distance.
/// It only ever reacts to focus, never to hover: a mouse already has the
/// cursor itself as a positional cue, which a D-pad or Tab press does not.
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

  /// Whether a [FocusRing] marks focus in addition to the scale-lean. See
  /// the class doc for when to turn this on.
  final bool showFocusRing;

  /// The ring's corner radius. The default is a pill, right for a bare icon
  /// or a short line of text; a rounded-rectangle [child] passes its own.
  final double focusRingBorderRadius;

  /// Marks focus by lightening the child *inside* its own bounds, with this
  /// corner radius -- the child's own. For a chip in a scrolling row, where
  /// the ring is the wrong tool: it needs room outside the child, which a
  /// row with no padding clips, and on a violet selected chip a violet ring
  /// is the same color as what it surrounds (#80). Null leaves it off.
  final double? focusFillRadius;

  const HoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleAmount = 1.04,
    this.autofocus = false,
    this.showFocusRing = false,
    this.focusRingBorderRadius = 9999,
    this.focusFillRadius,
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
    if (!_activators.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    widget.onTap();
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    setState(() => _isFocused = focused);
    if (!focused) return;
    // A D-pad/keyboard move can land focus on something the scroll offset
    // hasn't caught up to yet -- a card in the next row down, still outside
    // the viewport. Without this the focus ring lands somewhere the viewer
    // cannot see, which reads as "the remote stopped working" rather than
    // "keep pressing, it moved". No-ops when there is no ancestor
    // Scrollable (a hero dot, a fixed toolbar button).
    if (Scrollable.maybeOf(context) == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: _handleKey,
      child: FocusRing(
        visible: widget.showFocusRing && _isFocused,
        borderRadius: widget.focusRingBorderRadius,
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
              child: widget.focusFillRadius == null
                  ? widget.child
                  : Stack(
                      // Passthrough, so the child keeps the constraints it
                      // would have had without the overlay.
                      fit: StackFit.passthrough,
                      children: [
                        widget.child,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                color: _isFocused
                                    ? AppColors.inkAlpha(0.20)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  widget.focusFillRadius!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
