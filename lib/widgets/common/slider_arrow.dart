import 'dart:ui';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    // Dynamic scale based on interaction state
    final scale = _isPressed ? 0.90 : (_isHovered ? 1.08 : 1.0);
    
    return MouseRegion(
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
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFF080A0F).withValues(alpha: 0.5),
                  border: Border.all(
                    color: _isHovered
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: _isHovered
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
                  widget.icon,
                  color: Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.7),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
