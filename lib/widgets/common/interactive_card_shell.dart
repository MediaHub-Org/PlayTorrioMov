import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'activate_keys.dart';

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
/// No [FocusRing] here, on purpose. Cards got one after a first TV test said
/// the ~4% lean was easy to lose against a full grid; a later test said the
/// other way: a card already scales up and lifts when focused, and the violet
/// ring around it on top of that only covers the poster. The lean and the lift
/// are the indicator (plus `Scrollable.ensureVisible` below, which keeps the
/// card on screen as the grid scrolls under it).
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

  @override
  void initState() {
    super.initState();
    // The highlight mode flips when the viewer switches input (touch/mouse
    // to keys/D-pad), which is exactly when focused styling should appear
    // or disappear -- without this a card focused by FirstFocusScope keeps
    // its zoom for a mouse viewer who never touched the keyboard.
    FocusManager.instance.addListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!kActivateKeys.contains(event.logicalKey)) return KeyEventResult.ignored;
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
    // Focus zooms the card only while the viewer is navigating with keys
    // or a D-pad. A mouse viewer never asked for focus: FirstFocusScope
    // hands it to the first card on open so a remote has somewhere to be,
    // and without this gate that looked like the first movie arriving
    // pre-selected and zoomed. Same gate the player menus use.
    final focusShown = _focused &&
        FocusManager.instance.highlightMode ==
            FocusHighlightMode.traditional;
    final hovered = _hovered || focusShown;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
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
