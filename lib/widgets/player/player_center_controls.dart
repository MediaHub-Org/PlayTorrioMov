import 'package:flutter/material.dart';

/// Centered play/pause with ±10s seek on either side -- YouTube/Netflix
/// style. Lives over the middle of the video, not in the bottom transport
/// bar, so it stays reachable (and visible) regardless of how far down the
/// bottom bar's own controls get trimmed.
class PlayerCenterControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack10;
  final VoidCallback onSeekForward10;

  const PlayerCenterControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBack10,
    required this.onSeekForward10,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 680;
    final sideSize = isCompact ? 52.0 : 64.0;
    final sideIconSize = isCompact ? 26.0 : 32.0;
    final playSize = isCompact ? 68.0 : 84.0;
    final playIconSize = isCompact ? 34.0 : 42.0;
    final gap = isCompact ? 28.0 : 44.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CenterButton(
          size: sideSize,
          iconSize: sideIconSize,
          icon: Icons.replay_10_rounded,
          tooltip: 'Seek -10s',
          onTap: onSeekBack10,
        ),
        SizedBox(width: gap),
        _PlayPauseButton(
          isPlaying: isPlaying,
          size: playSize,
          iconSize: playIconSize,
          onTap: onPlayPause,
        ),
        SizedBox(width: gap),
        _CenterButton(
          size: sideSize,
          iconSize: sideIconSize,
          icon: Icons.forward_10_rounded,
          tooltip: 'Seek +10s',
          onTap: onSeekForward10,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
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
              color: Colors.white.withValues(alpha: _hovered ? 0.20 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, color: Colors.white, size: widget.iconSize),
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

  const _PlayPauseButton({
    required this.isPlaying,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
            color: Colors.white.withValues(alpha: _hovered ? 0.28 : 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
