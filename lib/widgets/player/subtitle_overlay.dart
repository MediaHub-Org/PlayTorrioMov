import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/player/player_settings.dart';
import '../../services/app_units.dart';

/// The main player's subtitle text, drawn by the app rather than by media_kit's
/// own `SubtitleView`.
///
/// `SubtitleView` pins its text to the bottom center and has no notion of a
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

  const SubtitleOverlay({
    super.key,
    required this.lines,
    this.initialLines = const [],
    this.showSample = false,
  });

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
    return ListenableBuilder(
      // Both, because either can turn libass on: the preference, or an
      // embedded track being selected. Listening only to the preference
      // meant the overlay kept drawing after an embedded track turned
      // libass on, so every line appeared twice -- once from mpv, once from
      // Flutter.
      listenable: Listenable.merge([
        PlayerSettings.changeNotifier,
        PlayerSettings.embeddedSubtitleActive,
      ]),
      builder: (context, _) {
        // `shouldUseLibass`, not `useLibass`: an embedded track turns libass
        // on without the preference being set, and the overlay has to know
        // or it draws the same text a second time.
        if (PlayerSettings.shouldUseLibass) return const SizedBox.shrink();

        final text = widget.showSample
            ? '${context.l10n.subSampleTitle}\n${context.l10n.subSampleBody}'
            : _lines.where((l) => l.trim().isNotEmpty).join('\n');
        if (text.isEmpty) return const SizedBox.shrink();

        final side = PlayerSettings.subAlignX.value;
        return IgnorePointer(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rem(side == 'left' ? AppRem.xl : AppRem.md),
              0,
              context.rem(side == 'right' ? AppRem.xl : AppRem.md),
              PlayerSettings.subMarginY.value.clamp(0.0, 300.0),
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
          ),
        );
      },
    );
  }
}
