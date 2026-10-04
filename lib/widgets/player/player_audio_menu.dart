import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'language_flag.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';
import '../../services/app_units.dart';

/// One audio track, as the menu needs to draw it.
class PlayerAudioTrack {
  final int index;

  /// The clean language name, e.g. "English". The container's own title is
  /// not the title: it tends to carry codec and channel detail ("English
  /// [DD+ 5.1]"), which the row shows as chips instead -- the language stays
  /// the thing the eye lands on.
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

/// The codec chip for an audio row ("AAC", "5.1" comes separately): mpv's
/// codec names, shortened the way the subtitle formats are. Unknown codecs
/// yield nothing -- a raw `pcm_s32le` on every row is noise, not info.
String? audioCodecLabel(String? codec) {
  switch (codec?.trim().toLowerCase()) {
    case 'aac':
      return 'AAC';
    case 'ac3':
    case 'ac-3':
      return 'AC-3';
    case 'eac3':
    case 'e-ac-3':
      return 'E-AC-3';
    case 'dts':
      return 'DTS';
    case 'dts-hd':
    case 'dtshd':
      return 'DTS-HD';
    case 'flac':
      return 'FLAC';
    case 'mp3':
      return 'MP3';
    case 'opus':
      return 'Opus';
    case 'vorbis':
      return 'Vorbis';
    case 'truehd':
      return 'TrueHD';
    case 'alac':
      return 'ALAC';
    default:
      if ((codec?.trim().toLowerCase().startsWith('pcm') ?? false)) {
        return 'PCM';
      }
      return null;
  }
}

/// The channel chip ("Stereo", "5.1"): the count mpv reports, read as the
/// layout it almost always is. Anything else renders as a bare count rather
/// than a guessed layout -- "4 ch" states what is known, "Quad" would not.
String? audioChannelsLabel(int? channels) => switch (channels) {
      1 => 'Mono',
      2 => 'Stereo',
      6 => '5.1',
      8 => '7.1',
      null => null,
      _ => '$channels ch',
    };

/// The audio tracks, on their own.
///
/// This shared a panel with the subtitles and the sleep timer for a while.
/// They are three unrelated questions -- what am I hearing, what am I reading,
/// when does this stop -- asked at different moments, and putting them side by
/// side made a viewer answer all three to change one. Each has its own icon
/// on the transport bar again.
///
/// A row leads with the language -- the list exists to answer "which
/// language" -- and the file's own detail rides as chips behind it: codec
/// and channel layout off the embedded tags. The container's own title
/// stays out: it is the same detail written noisier ("English [DD+ 5.1]").
class PlayerAudioMenu extends StatelessWidget {
  final List<PlayerAudioTrack> audioTracks;
  final int selectedIndex;

  final ValueChanged<int> onTrackSelected;

  /// Back to the settings root, when this menu was stepped into from there.
  final VoidCallback? onBack;

  const PlayerAudioMenu({
    super.key,
    required this.audioTracks,
    required this.selectedIndex,
    required this.onTrackSelected,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      padding: EdgeInsets.all(context.rem(0.625)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                PlayerIconButton(
                  size: context.rem(1.75),
                  iconSize: context.rem(0.875),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: context.l10n.playerBackToSettings,
                  onPressed: onBack,
                ),
                SizedBox(width: context.rem(AppRem.xs)),
              ],
              Expanded(
                child: PlayerMenuHeader(
                  title: context.l10n.playerAudioTracks.toUpperCase(),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rem(AppRem.snug)),
          if (audioTracks.isEmpty)
            PlayerMenuEmptyRow(context.l10n.playerAudioDefaultStream)
          else
            for (final track in audioTracks)
              PlayerMenuRow(
                // mpv often tags no language at all: fall back to the row
                // title, which already prefers the language name and only
                // then the container title or codec.
                leading: LanguageFlag(
                  track.language?.trim().isNotEmpty == true
                      ? track.language
                      : track.title,
                  height: context.rem(0.8125),
                ),
                title: track.title,
                // The embedded info the rows used to drop: what the file
                // carries beyond the language -- format and layout -- as
                // chips, so the language stays the thing the eye lands on.
                badges: [
                  if (audioCodecLabel(track.codec) case final codec?)
                    codec,
                  if (audioChannelsLabel(track.channels) case final layout?)
                    layout,
                ],
                isSelected: track.index == selectedIndex,
                onTap: () => onTrackSelected(track.index),
              ),
        ],
      ),
    );
  }
}