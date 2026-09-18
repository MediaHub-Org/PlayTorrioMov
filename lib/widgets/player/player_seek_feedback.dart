import 'package:flutter/material.dart';

/// One seek, as the overlay needs to know about it.
///
/// [id] is what makes a repeat visible: seeking twice by the same amount
/// produces two flashes that are otherwise identical, and without a changing
/// id the second one would not re-trigger the animation.
@immutable
class SeekFlash {
  /// Bumped once per seek.
  final int id;

  /// Signed, and **accumulated** while the taps keep coming in the same
  /// direction -- three taps of +10s read as "30 seconds", the way a viewer
  /// counts it, rather than flashing "10 seconds" three times.
  final int totalSeconds;

  const SeekFlash({required this.id, required this.totalSeconds});

  bool get isForward => totalSeconds > 0;

  /// Folds a new seek into the flash currently on screen: same direction
  /// adds to the running total, the other direction starts a new count.
  /// [id] is the caller's next sequence number.
  static SeekFlash next(SeekFlash? previous, int seconds, {required int id}) {
    final continues = previous != null && previous.isForward == (seconds > 0);
    return SeekFlash(
      id: id,
      totalSeconds: continues ? previous.totalSeconds + seconds : seconds,
    );
  }
}

/// The transient flash shown on the side of the video a seek moved it.
///
/// Every way of seeking by a fixed step goes through this -- the double-tap
/// zones, the centered ±10s buttons, the ±30s buttons in the transport bar,
/// and the arrow keys -- so the feedback is the same regardless of how the
/// seek was asked for, and it always appears on the side that matches the
/// direction.
class PlayerSeekFeedback extends StatefulWidget {
  final SeekFlash? flash;

  const PlayerSeekFeedback({super.key, this.flash});

  @override
  State<PlayerSeekFeedback> createState() => _PlayerSeekFeedbackState();
}

class _PlayerSeekFeedbackState extends State<PlayerSeekFeedback>
    with SingleTickerProviderStateMixin {
  // Built in initState, not as `late final` field initializers. Those are
  // lazy: with no seek yet there is nothing to animate, so nothing would
  // touch them -- and then dispose()'s `_controller.dispose()` would be the
  // first read, constructing a ticker against an element that is already
  // deactivated. Opening the player and leaving without seeking is the
  // ordinary way to hit that.
  late final AnimationController _controller;

  /// Quick in, brief hold, slower out -- long enough to read at a glance,
  /// short enough not to sit over the picture.
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final CurvedAnimation _scaleCurve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 47),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_controller);
    _scaleCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(_scaleCurve);

    if (widget.flash != null) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(PlayerSeekFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    final flash = widget.flash;
    if (flash != null && flash.id != oldWidget.flash?.id) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleCurve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flash = widget.flash;
    if (flash == null) return const SizedBox.shrink();

    final forward = flash.isForward;
    final seconds = flash.totalSeconds.abs();
    final isCompact = MediaQuery.sizeOf(context).width < 680;

    return IgnorePointer(
      child: Align(
        alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 24 : 56),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 18 : 24,
                vertical: isCompact ? 14 : 18,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    forward
                        ? Icons.fast_forward_rounded
                        : Icons.fast_rewind_rounded,
                    color: Colors.white,
                    size: isCompact ? 30 : 38,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$seconds seconds',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 12 : 14,
                      fontWeight: FontWeight.w600,
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
