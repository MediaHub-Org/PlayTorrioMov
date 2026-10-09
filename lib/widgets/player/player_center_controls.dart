import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import 'player_glass.dart' show FocusRing;
import '../../services/app_units.dart';
import '../common/activate_keys.dart';

/// Centered play/pause. Lives over the middle of the video, not in the
/// bottom transport bar, so it stays reachable (and visible) regardless of
/// how far down the bottom bar's own controls get trimmed -- and it is the
/// one thing a remote's first arrow press can land on when the controls
/// reappear, the anchor the rest of the D-pad traversal is built around
/// (#80).
///
/// Used to carry ±30s seek buttons on either side. Removed rather than kept
/// behind a flag: every platform already has a better way to do the same
/// jump -- double-tap zones and keyboard seek on touch/desktop, and the
/// transport bar's own seek bar on a TV remote, which nudges 10s and
/// accelerates to a full 2 minutes per press the longer Left/Right is held
/// (see `PlayerSeekBar._stepFor`). The buttons were a second, bigger-only
/// affordance sitting over the middle of the picture for something every
/// platform could already do -- the double-tap gesture study that picked
/// ±30s over ±10s to begin with ("three seek controls, two of them
/// identical") reached the same conclusion about this one, just a release
/// later.
class PlayerCenterControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;

  /// The play/pause button's focus node, so the screen can hand a remote's
  /// first arrow press to it when the controls come back on screen.
  final FocusNode? playPauseFocusNode;

  const PlayerCenterControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    this.playPauseFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    final playSize = context.rem(isCompact ? 4.25 : 5.25);
    final playIconSize = context.rem(isCompact ? 2.125 : 2.625);

    return _PlayPauseButton(
      isPlaying: isPlaying,
      size: playSize,
      iconSize: playIconSize,
      onTap: onPlayPause,
      focusNode: playPauseFocusNode,
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final button = Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!kActivateKeys.contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        widget.onTap();
        return KeyEventResult.handled;
      },
      child: FocusRing(
        visible: _focused,
        borderRadius: widget.size / 2, // ratio: half the button, a circle
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: (_hovered || _focused) ? 0.28 : 0.18,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.2, // px: a hairline, not a layout size
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x66000000),
                    offset: Offset(0, context.rem(AppRem.xs)),
                    blurRadius: context.rem(AppRem.md),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
    // The two seek buttons beside this one are told their label; this one
    // reads the state it already has, so the label names where a press takes
    // you rather than what is happening now.
    return Tooltip(
      message: widget.isPlaying
          ? context.l10n.playerPause
          : context.l10n.playerPlay,
      child: button,
    );
  }
}
