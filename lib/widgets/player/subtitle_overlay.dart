import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/player/player_settings.dart';

/// The main player's subtitle text, drawn by the app rather than by media_kit's
/// own `SubtitleView`.
///
/// `SubtitleView` pins its text to the bottom centre and has no notion of a
/// horizontal side or a vertical position, so the Left / Center / Right
/// buttons and the vertical-position slider changed a setting that nothing
/// drew. Drawing it here makes every appearance control do something: the
/// side picks the alignment, the position slider places the text between the
/// top and the bottom of the picture, and the bottom margin keeps it off the
/// edge.
///
/// With the native (libass) engine libmpv draws the text itself and applies
/// the same settings as mpv properties, so this draws nothing.
///
/// [showSample] replaces the real text with a fixed two-line sample. The
/// appearance editor turns it on, so its changes can be judged without
/// waiting for a line of dialogue.
class SubtitleOverlay extends StatefulWidget {
  /// The current subtitle lines, as the player reports them
  /// (`player.stream.subtitle`). A stream and its first value rather than the
  /// player itself, so the overlay can be exercised without a native player.
  final Stream<List<String>> lines;
  final List<String> initialLines;
  final bool showSample;

  /// Space to leave clear on each edge: the text is laid out in what remains,
  /// so position and margin are measured from there. The appearance editor
  /// passes the room around its own panel, so the sample lands where the
  /// viewer can see it instead of under the panel they are adjusting it with.
  final EdgeInsets avoid;

  const SubtitleOverlay({
    super.key,
    required this.lines,
    this.initialLines = const [],
    this.showSample = false,
    this.avoid = EdgeInsets.zero,
  });

  /// The largest free space around [panel] on a [screen], as insets, or null
  /// when nothing is big enough to read a sample in. [bottomReserved] is the
  /// transport bar's share of the bottom edge.
  ///
  /// Two places are candidates: beside the panel (a wide screen puts it in the
  /// right-hand corner) and above it (a narrow one centres it along the
  /// bottom). The bigger wins. On a phone held sideways neither is, and the
  /// answer is null: the editor's own pinned preview is the sample there.
  static EdgeInsets? insetsAround({
    required Size screen,
    required Rect panel,
    required double bottomReserved,
    double gap = 12,
    double minWidth = 220,
    double minHeight = 80,
  }) {
    final floor = screen.height - bottomReserved;
    final beside = Rect.fromLTRB(0, 0, panel.left - gap, floor);
    final above = Rect.fromLTRB(0, 0, screen.width, panel.top - gap);

    bool fits(Rect r) => r.width >= minWidth && r.height >= minHeight;
    double area(Rect r) => fits(r) ? r.width * r.height : 0;

    final best = area(beside) >= area(above) ? beside : above;
    if (!fits(best)) return null;
    return EdgeInsets.fromLTRB(
      best.left,
      best.top,
      screen.width - best.right,
      screen.height - best.bottom,
    );
  }

  /// Where the text block sits vertically, as an [Alignment.y]: a position of
  /// 100 (the bottom) is `1`, 0 (the top) is `-1`.
  @visibleForTesting
  static double alignmentY(double position) =>
      (position.clamp(0.0, 100.0) / 50.0) - 1.0;

  /// Which side the block hugs, as an [Alignment.x]. The appearance editor's
  /// preview uses it too, so the two cannot disagree about a side.
  static double alignmentX(String side) => switch (side) {
    'left' => -1.0,
    'right' => 1.0,
    _ => 0.0,
  };

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  late List<String> _lines = widget.initialLines;
  StreamSubscription<List<String>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.lines.listen((lines) {
      if (mounted) setState(() => _lines = lines);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PlayerSettings.changeNotifier,
      builder: (context, _, __) {
        if (PlayerSettings.useLibass.value) return const SizedBox.shrink();

        final text = widget.showSample
            ? '${context.l10n.subSampleTitle}\n${context.l10n.subSampleBody}'
            : _lines.where((l) => l.trim().isNotEmpty).join('\n');
        if (text.isEmpty) return const SizedBox.shrink();

        final side = PlayerSettings.subAlignX.value;
        return IgnorePointer(
          child: Padding(
            padding: widget.avoid,
            // Measured inside the free space, so the margin can be held to a
            // share of it: 150 px of bottom margin is a sensible ask of a
            // full screen and pushes the text out of a 100 px gap.
            child: LayoutBuilder(
              builder: (context, box) {
                final margin = PlayerSettings.subMarginY.value.clamp(0.0, 300.0);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    side == 'left' ? 32 : 16,
                    0,
                    side == 'right' ? 32 : 16,
                    widget.avoid == EdgeInsets.zero ? margin : margin.clamp(0.0, box.maxHeight * 0.25),
                  ),
                  child: Align(
                    alignment: Alignment(
                      SubtitleOverlay.alignmentX(side),
                      SubtitleOverlay.alignmentY(PlayerSettings.subPos.value),
                    ),
                    child: Text(
                      text,
                      textAlign: PlayerSettings.subtitleTextAlign(),
                      style: PlayerSettings.subtitleTextStyle(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
