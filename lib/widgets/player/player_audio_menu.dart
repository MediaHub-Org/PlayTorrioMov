import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'language_flag.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';

/// One audio track, as the menu needs to draw it.
class PlayerAudioTrack {
  final int index;

  /// The clean language name, e.g. "English". The container's own title is
  /// not used: it tends to carry codec and channel detail ("English [DD+
  /// 5.1]"), which the row does not show at all.
  final String title;
  final String? language;
  final String? codec;
  final int? channels;

  const PlayerAudioTrack({
    required this.index,
    required this.title,
    this.language,
    this.codec,
    this.channels,
  });
}

/// The audio tracks, on their own.
///
/// This shared a panel with the subtitles and the sleep timer for a while.
/// They are three unrelated questions -- what am I hearing, what am I reading,
/// when does this stop -- asked at different moments, and putting them side by
/// side made a viewer answer all three to change one. Each has its own icon
/// on the transport bar again.
///
/// A row is the language and nothing else. Codec, channel count and the
/// container's own track title are all gone: the list exists to answer "which
/// language", and every extra field is another thing to read past on the way
/// to that answer.
class PlayerAudioMenu extends StatelessWidget {
  final List<PlayerAudioTrack> audioTracks;
  final int selectedIndex;

  /// The track the file opens with, badged as the original. Null when it is
  /// not known, which is better than badging a guess.
  final int? primaryIndex;

  final ValueChanged<int> onTrackSelected;

  /// Back to the settings root, when this menu was stepped into from there.
  final VoidCallback? onBack;

  const PlayerAudioMenu({
    super.key,
    required this.audioTracks,
    required this.selectedIndex,
    required this.onTrackSelected,
    this.primaryIndex,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                PlayerIconButton(
                  size: 28,
                  iconSize: 14,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: context.l10n.playerBackToSettings,
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: PlayerMenuHeader(
                  title: context.l10n.playerAudioTracks.toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (audioTracks.isEmpty)
            PlayerMenuEmptyRow(context.l10n.playerAudioDefaultStream)
          else
            for (final track in audioTracks)
              PlayerMenuRow(
                leading: LanguageFlag(track.language ?? '', height: 13),
                title: track.title,
                badges: [
                  if (track.index == primaryIndex) 'original',
                ],
                isSelected: track.index == selectedIndex,
                onTap: () => onTrackSelected(track.index),
              ),
        ],
      ),
    );
  }
}