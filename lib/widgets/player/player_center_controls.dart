import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import 'player_glass.dart' show FocusRing;
import '../../services/app_units.dart';

/// The keys that activate a focused control in this file. `final`, not
/// `const`: `LogicalKeyboardKey` overrides `==`, and the analyzer rejects
/// that inside a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

/// Centered play/pause with ±30s seek on either side. Lives over the middle
/// of the video, not in the bottom transport bar, so it stays reachable (and
/// visible) regardless of how far down the bottom bar's own controls get
/// trimmed.
///
/// ±30s rather than ±10s so that each amount has exactly one affordance:
/// the double-tap side zones are the small nudge, these buttons are the
/// bigger jump. They used to be ±10s as well, which on a phone meant the
/// gesture and the buttons did the same thing while ±30s sat in a third
/// place, the transport bar -- three seek controls, two of them identical.
///
/// The seek callbacks are optional so a live stream can use the same widget:
/// seeking has no meaning without a duration, and the alternative -- a
/// second, near-identical play/pause somewhere else -- is how the Live TV
/// player drifted away from this one in the first place. With them null the
/// play button stands alone, centered, at the same size and in the same
/// place.
class PlayerCenterControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onSeekBack30;
  final VoidCallback? onSeekForward30;

  /// The play/pause button's focus node, so the screen can hand a remote's
  /// first arrow press to it when the controls come back on screen.
  final FocusNode? playPauseFocusNode;

  const PlayerCenterControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    this.onSeekBack30,
    this.onSeekForward30,
    this.playPauseFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    final sideSize = context.rem(isCompact ? 3.25 : 4);
    final sideIconSize = context.rem(isCompact ? 1.625 : 2);
    final playSize = context.rem(isCompact ? 4.25 : 5.25);
    final playIconSize = context.rem(isCompact ? 2.125 : 2.625);
    final gap = context.rem(isCompact ? 1.75 : 2.75);

    final seekBack = onSeekBack30;
    final seekForward = onSeekForward30;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (seekBack != null) ...[
          _CenterButton(
            size: sideSize,
            iconSize: sideIconSize,
            icon: Icons.replay_30_rounded,
            tooltip: context.l10n.playerBack30,
            onTap: seekBack,
          ),
          SizedBox(width: gap),
        ],
        _PlayPauseButton(
          isPlaying: isPlaying,
          size: playSize,
          iconSize: playIconSize,
          onTap: onPlayPause,
          focusNode: playPauseFocusNode,
        ),
        if (seekForward != null) ...[
          SizedBox(width: gap),
          _CenterButton(
            size: sideSize,
            iconSize: sideIconSize,
            icon: Icons.forward_30_rounded,
            tooltip: context.l10n.playerForward30,
            onTap: seekForward,
          ),
        ],
      ],
    );
  }
}

class _CenterButton extends StatefulWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CenterButton({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (!_activators.contains(event.logicalKey)) {
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
                    alpha: (_hovered || _focused) ? 0.20 : 0.12,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1, // px: a hairline, not a layout size
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: widget.iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
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
        if (!_activators.contains(event.logicalKey)) {
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
