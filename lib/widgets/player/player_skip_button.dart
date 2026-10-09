import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_colors.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/app_units.dart';
import '../common/focus_fill.dart';

/// Ultra-sleek, responsive glassmorphism Skip Button with dynamic hover effects
/// and a left-to-right sweep progress bar that auto-hides when complete.
class PlayerSkipButton extends StatefulWidget {
  final MediaSkipSegment segment;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;
  final Duration lifespan;

  const PlayerSkipButton({
    super.key,
    required this.segment,
    required this.onSkip,
    required this.onDismiss,
    this.lifespan = const Duration(seconds: 5),
  });

  @override
  State<PlayerSkipButton> createState() => _PlayerSkipButtonState();
}

class _PlayerSkipButtonState extends State<PlayerSkipButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  bool _isHovered = false;
  bool _isDismissHovered = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: widget.lifespan,
    );

    _sweepController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _sweepController.forward();
  }

  @override
  void didUpdateWidget(PlayerSkipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.uniqueKey != widget.segment.uniqueKey) {
      _sweepController.reset();
      _sweepController.forward();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 640;

    final isCredits = widget.segment.type == 'credits';
    final accentColor = isCredits ? const Color(0xFF10B981) : AppColors.accent;
    final accentGlow = isCredits ? const Color(0xFF34D399) : const Color(0xFF9D84FF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        // Pause the auto-dismiss timer while user is hovering to let them click comfortably
        _sweepController.stop();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        // Resume the countdown
        if (mounted) {
          _sweepController.forward();
        }
      },
      child: AnimatedScale(
        scale: _isHovered ? (isCompact ? 1.02 : 1.04) : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rem(isCompact ? AppRem.radiusMd : AppRem.radiusLg)),
            border: Border.all(
              color: _isHovered
                  ? accentGlow.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.20),
              width: _isHovered ? 1.5 : 1.0, // px: a hairline, not a layout size
            ),
            boxShadow: [
              // Deep ambient drop shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                offset: Offset(0, context.rem(AppRem.sm)),
                blurRadius: context.rem(1.75),
              ),
              // Reactive neon hover glow
              if (_isHovered) ...[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.40),
                  blurRadius: context.rem(1.375),
                  spreadRadius: context.rem(AppRem.xxs),
                ),
                BoxShadow(
                  color: accentGlow.withValues(alpha: 0.20),
                  blurRadius: context.rem(2.5),
                  spreadRadius: context.rem(AppRem.xs),
                ),
              ],
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.rem(isCompact ? AppRem.radiusMd : AppRem.radiusLg)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: _isHovered
                    ? const Color(0xF20F1420)
                    : const Color(0xD9080C14),
                child: Stack(
                  children: [
                    // Dynamic Sweep Gradient Shimmer that follows countdown
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _sweepController,
                        builder: (context, _) {
                          final progress = _sweepController.value;
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [
                                  (progress - 0.25).clamp(0.0, 1.0),
                                  progress.clamp(0.0, 1.0),
                                  (progress + 0.15).clamp(0.0, 1.0),
                                ],
                                colors: [
                                  Colors.transparent,
                                  accentColor.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcOver,
                            child: Container(color: Colors.white.withValues(alpha: 0.04)),
                          );
                        },
                      ),
                    ),

                    // Main Content Row
                    IntrinsicHeight(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary Clickable Skip Body
                          Material(
                            color: Colors.transparent,
                            child: FocusFill(
                              radius: 0,
                              child: InkWell(
                                onTap: widget.onSkip,
                                hoverColor: accentColor.withValues(alpha: 0.15),
                                splashColor: accentGlow.withValues(alpha: 0.30),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.rem(isCompact ? 0.8125 : 1.125),
                                    vertical: context.rem(isCompact ? 0.5625 : AppRem.ms),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Animated Action Icon
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        transform: Matrix4.translationValues(
                                          _isHovered ? 2.0 : 0.0,
                                          0.0,
                                          0.0,
                                        ),
                                        child: Icon(
                                          widget.segment.icon,
                                          size: context.rem(isCompact ? AppRem.iconXs : AppRem.icon),
                                          color: _isHovered ? accentGlow : accentColor,
                                        ),
                                      ),
                                      SizedBox(width: context.rem(isCompact ? 0.4375 : 0.625)),

                                      // Action Label
                                      Text(
                                        widget.segment.label(context.l10n),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isCompact ? AppType.captionPlus : AppType.body,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.8),
                                              offset: Offset(0, context.rem(0.0625)),
                                              blurRadius: context.rem(AppRem.xs),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Vertical Frosted Divider
                          Container(
                            width: 1, // px: a hairline, not a layout size
                            margin: EdgeInsets.symmetric(vertical: context.rem(AppRem.snug)),
                            color: Colors.white.withValues(alpha: 0.14),
                          ),

                          // '✕' Dismiss Button
                          MouseRegion(
                            onEnter: (_) => setState(() => _isDismissHovered = true),
                            onExit: (_) => setState(() => _isDismissHovered = false),
                            child: Material(
                              color: Colors.transparent,
                              child: FocusFill(
                                radius: 0,
                                child: InkWell(
                                  onTap: widget.onDismiss,
                                  hoverColor: Colors.white.withValues(alpha: 0.15),
                                  splashColor: Colors.white.withValues(alpha: 0.25),
                                  child: Tooltip(
                                    message: context.l10n.playerDismiss,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.rem(isCompact ? 0.5625 : AppRem.ms),
                                        vertical: context.rem(isCompact ? 0.5625 : AppRem.ms),
                                      ),
                                      alignment: Alignment.center,
                                      child: AnimatedScale(
                                        scale: _isDismissHovered ? 1.15 : 1.0,
                                        duration: const Duration(milliseconds: 140),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: context.rem(isCompact ? 0.9375 : 1.0625),
                                          color: _isDismissHovered
                                              ? Colors.white
                                              : Colors.white.withValues(alpha: 0.60),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Left-to-Right Countdown Laser / Fade Line
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: context.rem(isCompact ? AppRem.xxs : 0.1562),
                      child: AnimatedBuilder(
                        animation: _sweepController,
                        builder: (context, _) {
                          final sweepProgress = _sweepController.value.clamp(0.0, 1.0);

                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: sweepProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999), // px: a hairline, not a layout size
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor.withValues(alpha: 0.5),
                                    accentGlow,
                                    Colors.white,
                                  ],
                                  stops: const [0.0, 0.85, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentGlow.withValues(alpha: 0.8),
                                    blurRadius: context.rem(AppRem.snug),
                                    spreadRadius: context.rem(0.0625),
                                    offset: const Offset(0, -0.5), // ratio: a line height, not a size
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
