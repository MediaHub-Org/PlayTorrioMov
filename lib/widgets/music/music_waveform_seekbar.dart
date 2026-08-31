import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/music/music_settings.dart';

class MusicWaveformSeekbar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final MusicSeekbarStyle style;
  final bool compact;

  const MusicWaveformSeekbar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.isPlaying = false,
    this.style = MusicSeekbarStyle.waveformEqualizer,
    this.compact = false,
  });

  @override
  State<MusicWaveformSeekbar> createState() => _MusicWaveformSeekbarState();
}

class _MusicWaveformSeekbarState extends State<MusicWaveformSeekbar> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragProgress = 0.0;
  late final AnimationController _waveAnimController;

  static final List<double> _waveSamples = List.generate(64, (i) {
    final s1 = math.sin(i * 0.32).abs();
    final s2 = math.cos(i * 0.52).abs();
    final s3 = math.sin(i * 0.18 + 1.4).abs();
    return ((s1 * 0.55 + s2 * 0.3 + s3 * 0.4) * 0.75 + 0.25).clamp(0.2, 1.0);
  });

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    super.dispose();
  }

  double get _currentProgress {
    if (_isDragging) return _dragProgress;
    if (widget.duration.inMilliseconds <= 0) return 0.0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      final mins = (d.inMinutes % 60).toString().padLeft(2, '0');
      final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$mins:$secs';
    }
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _handleSeek(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    final progress = (localX / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = progress;
    });
    final targetMs = (progress * widget.duration.inMilliseconds).round();
    widget.onSeek(Duration(milliseconds: targetMs));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final posDuration = _isDragging
        ? Duration(milliseconds: (_dragProgress * widget.duration.inMilliseconds).round())
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (widget.style == MusicSeekbarStyle.standardSlider) {
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: palette.primaryColor,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 4,
                  overlayColor: palette.primaryColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _currentProgress,
                  onChanged: (val) {
                    setState(() {
                      _isDragging = true;
                      _dragProgress = val;
                    });
                  },
                  onChangeEnd: (val) {
                    setState(() => _isDragging = false);
                    final targetMs = (val * widget.duration.inMilliseconds).round();
                    widget.onSeek(Duration(milliseconds: targetMs));
                  },
                ),
              );
            }

            if (widget.style == MusicSeekbarStyle.neonGradient) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (d) => _handleSeek(d.localPosition.dx, width),
                onHorizontalDragEnd: (d) => setState(() => _isDragging = false),
                onTapDown: (d) => _handleSeek(d.localPosition.dx, width),
                child: Container(
                  height: widget.compact ? 20 : 32,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: widget.compact ? 4 : 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: _currentProgress,
                        child: Container(
                          height: widget.compact ? 4 : 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [palette.primaryColor, palette.accentColor, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryColor.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: (width * _currentProgress - 6).clamp(0.0, math.max(0.0, width - 12)),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryColor,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (widget.style == MusicSeekbarStyle.liquidGlassSlider) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (d) => _handleSeek(d.localPosition.dx, width),
                onHorizontalDragEnd: (d) => setState(() => _isDragging = false),
                onTapDown: (d) => _handleSeek(d.localPosition.dx, width),
                child: Container(
                  height: widget.compact ? 24 : 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      FractionallySizedBox(
                        widthFactor: _currentProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.primaryColor.withValues(alpha: 0.35),
                                palette.primaryColor.withValues(alpha: 0.65),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (width * _currentProgress - 10).clamp(0.0, math.max(0.0, width - 20)),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: palette.primaryColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primaryColor.withValues(alpha: 0.7),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (widget.style == MusicSeekbarStyle.radialDial) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => setState(() => _isDragging = true),
                onHorizontalDragUpdate: (d) => _handleSeek(d.localPosition.dx, width),
                onHorizontalDragEnd: (d) => setState(() => _isDragging = false),
                onTapDown: (d) => _handleSeek(d.localPosition.dx, width),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(56, 56),
                    painter: _RadialDialSeekPainter(
                      progress: _currentProgress,
                      primaryColor: palette.primaryColor,
                      accentColor: palette.accentColor,
                    ),
                  ),
                ),
              );
            }

            // Default: Dynamic Audio Waveform Canvas
            return AnimatedBuilder(
              animation: _waveAnimController,
              builder: (context, child) {
                final animPhase = _waveAnimController.value * 2 * math.pi;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (d) => _handleSeek(d.localPosition.dx, width),
                  onHorizontalDragEnd: (d) => setState(() => _isDragging = false),
                  onTapDown: (d) => _handleSeek(d.localPosition.dx, width),
                  child: Container(
                    height: widget.compact ? 32 : 48,
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: Size(width, widget.compact ? 32 : 48),
                      painter: _MusicWaveformPainter(
                        samples: _waveSamples,
                        progress: _currentProgress,
                        primaryColor: palette.primaryColor,
                        accentColor: palette.accentColor,
                        isPlaying: widget.isPlaying,
                        animPhase: animPhase,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),

        if (!widget.compact) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(posDuration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _formatDuration(widget.duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MusicWaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color primaryColor;
  final Color accentColor;
  final bool isPlaying;
  final double animPhase;

  _MusicWaveformPainter({
    required this.samples,
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
    required this.isPlaying,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) return;

    final count = samples.length;
    final totalSpacing = size.width / count;
    final barWidth = math.max(1.8, totalSpacing * 0.55);
    final midY = size.height / 2;

    final activePaint = Paint()..style = PaintingStyle.fill;
    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final x = i * totalSpacing + (totalSpacing - barWidth) / 2;
      final barProgress = i / count;
      final isActive = barProgress <= progress;

      double sampleHeight = samples[i];
      if (isPlaying && isActive) {
        final ripple = math.sin(animPhase + (i * 0.45)).abs() * 0.25;
        sampleHeight = (sampleHeight + ripple).clamp(0.2, 1.0);
      }

      final h = sampleHeight * size.height * 0.85;
      final top = midY - h / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, h),
        const Radius.circular(3),
      );

      if (isActive) {
        activePaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor,
            primaryColor,
          ],
        ).createShader(Rect.fromLTWH(x, top, barWidth, h));
        canvas.drawRRect(rect, activePaint);
      } else {
        canvas.drawRRect(rect, inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MusicWaveformPainter oldDelegate) => true;
}

class _RadialDialSeekPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color accentColor;

  _RadialDialSeekPainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..shader = SweepGradient(
        colors: [primaryColor, accentColor, primaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialDialSeekPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.primaryColor != primaryColor;
}
