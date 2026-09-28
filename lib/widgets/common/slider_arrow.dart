import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme/app_colors.dart';
import 'arrow_affordance.dart';

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHighlighted
                      ? AppColors.inkAlpha(0.15)
                      : AppColors.canvas.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isHighlighted
                        ? AppColors.inkAlpha(0.3)
                        : AppColors.inkAlpha(0.1),
                    width: 1.5,
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  readingOrderArrow(context, widget.icon),
                  color: AppColors.ink.withValues(alpha: isHighlighted ? 1.0 : 0.7),
                  size: 20,
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
