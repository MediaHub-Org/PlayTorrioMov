import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme/app_colors.dart';
import 'arrow_affordance.dart';
import '../../services/app_units.dart';

/// The keys that activate a focused [SliderArrow]. `final`, not `const`:
/// `LogicalKeyboardKey` overrides `==`, and the analyzer rejects that inside
/// a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

class SliderArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const SliderArrow({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  State<SliderArrow> createState() => _SliderArrowState();
}

class _SliderArrowState extends State<SliderArrow> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final isHighlighted = _isHovered || _isFocused;
    // Dynamic scale based on interaction state
    final scale = _isPressed ? 0.90 : (isHighlighted ? 1.08 : 1.0);

    final arrow = Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: context.rem(3),
                height: context.rem(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHighlighted
                      ? AppColors.inkAlpha(0.15)
                      : AppColors.canvas.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isHighlighted
                        ? AppColors.inkAlpha(0.3)
                        : AppColors.inkAlpha(0.1),
                    width: 1.5, // px: a hairline, not a layout size
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: context.rem(0.625),
                            offset: Offset(0, context.rem(AppRem.xs)),
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  readingOrderArrow(context, widget.icon),
                  color: AppColors.ink.withValues(alpha: isHighlighted ? 1.0 : 0.7),
                  size: context.rem(AppRem.icon),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
    return ArrowTooltip(icon: widget.icon, child: arrow);
  }
}

/// The previous/next pair that floats over a horizontally scrolling rail --
/// Home's sliders, Browse's rows, Continue Watching, and three of anime's
/// rails (cast, episodes, relations/recommendations) all want the same pair,
/// hidden until a pointer hovers the row.
///
/// Each of those six places used to carry its own copy of this, and every
/// copy parked its arrow 60px past the edge and slid it in over 250ms on
/// hover. That slide was the bug reported against the anime episode rail: a
/// pointer already moving toward where the arrow was about to land could
/// click during the 250ms it was still travelling, which reads as the button
/// moving out from under the cursor. The arrow now stays exactly where it
/// will be clicked and only fades and scales in, so there is nothing left to
/// chase. [canGoPrevious]/[canGoNext] default to true for a wrapping
/// carousel (Browse's hero), which always has both; a plain rail passes its
/// own `canScrollLeft`/`canScrollRight` instead.
class RailEdgeArrows extends StatelessWidget {
  /// Whatever gates reveal at the call site -- a `MouseRegion`'s hover flag
  /// at every current use, kept as a plain bool rather than wrapping the
  /// `MouseRegion` itself so a caller can fold in its own extra conditions
  /// (`isDesktop`, as several did).
  final bool visible;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Distance from the rail's edge once revealed. Rails disagreed on this
  /// before (0.5rem, 0.625rem, 0.75rem) for no evident reason, so each
  /// caller keeps its own figure instead of being quietly nudged.
  final double insetRem;

  const RailEdgeArrows({
    super.key,
    required this.visible,
    this.canGoPrevious = true,
    this.canGoNext = true,
    required this.onPrevious,
    required this.onNext,
    this.insetRem = AppRem.pillGap,
  });

  @override
  Widget build(BuildContext context) {
    // Positioned.fill: every caller drops this straight into its own Stack
    // alongside the rail's content, exactly where the two arrows it
    // replaces used to sit directly. Without this, this widget's Stack is a
    // non-positioned child there, and asks that Stack to size itself around
    // it -- which blows up the moment the outer Stack has nothing else
    // non-positioned to measure instead (a rail pumped on its own in a
    // test, with no page around it to provide a bounded height).
    return Positioned.fill(
      child: Stack(
        children: [
          if (canGoPrevious)
            _RailArrow(
              visible: visible,
              start: true,
              insetRem: insetRem,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onPrevious,
            ),
          if (canGoNext)
            _RailArrow(
              visible: visible,
              start: false,
              insetRem: insetRem,
              icon: Icons.arrow_forward_ios_rounded,
              onTap: onNext,
            ),
        ],
      ),
    );
  }
}

class _RailArrow extends StatelessWidget {
  final bool visible;

  /// The rail's own physical start/end, not reading order: a horizontal list
  /// scrolls toward its start or its end regardless of which language is
  /// reading it, and `PositionedDirectional` resolves that side for the
  /// ambient `Directionality`. The icon passed in already mirrors itself in
  /// RTL -- `arrow_back_ios_new_rounded`/`arrow_forward_ios_rounded` declare
  /// `matchTextDirection` -- so the two need no coordinating here.
  final bool start;
  final double insetRem;
  final IconData icon;
  final VoidCallback onTap;

  const _RailArrow({
    required this.visible,
    required this.start,
    required this.insetRem,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: start ? context.rem(insetRem) : null,
      end: start ? null : context.rem(insetRem),
      top: 0,
      bottom: 0,
      child: Center(
        // Parked but still in the tree, so a D-pad does not land on an
        // invisible arrow -- a focus stop with nothing to see and nothing
        // worth doing. Every rail but `browse_row_view`'s wants this; none
        // of them had it.
        child: ExcludeFocus(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedScale(
              scale: visible ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: SliderArrow(icon: icon, onTap: onTap),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
