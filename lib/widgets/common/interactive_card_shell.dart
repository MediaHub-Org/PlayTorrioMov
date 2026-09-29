import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'focus_ring.dart';

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
///
/// The hover-lean was originally judged enough on its own here -- unlike
/// [HoverButton]'s `showFocusRing`, no card type opted into a ring. Real
/// remote testing on an actual TV said otherwise: at couch distance a ~4%
/// lean is easy to lose track of against a full grid of posters, especially
/// once scrolling (see `Scrollable.ensureVisible` below) moves the whole
/// grid under it at the same time. Every card now gets a [FocusRing] too.
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

  /// [FocusRing]'s corner radius, matched to the card's own artwork corners
  /// so the ring reads as marking the card rather than as a mismatched box
  /// around it. Movie/series posters use 18; overridden per caller for a
  /// different shape (a channel logo tile, for instance).
  final double focusRingBorderRadius;

  const InteractiveCardShell({
    super.key,
    required this.builder,
    required this.onTap,
    this.autofocus = false,
    this.pressedScale = 0.97,
    this.hoveredScale = 1.045,
    this.focusRingBorderRadius = 18,
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

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (!focused) return;
    // Same reasoning as HoverButton's own onFocusChange: a D-pad move can
    // land focus on a card the scroll offset hasn't caught up to yet, still
    // outside the viewport, which otherwise reads as the remote having
    // stopped working. No-op without an ancestor Scrollable.
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
    final hovered = _hovered || _focused;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: _handleKey,
      child: FocusRing(
        visible: _focused,
        borderRadius: widget.focusRingBorderRadius,
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
      ),
    );
  }
}
