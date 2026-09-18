import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';

/// A reference list of the player's keyboard shortcuts -- split out of the
/// old "General & Data" catch-all so it reads as its own category, matching
/// Backup & Data getting the same treatment.
///
/// The key column is deliberately untranslated: `Space`, `J`, `Esc` are the
/// physical keys, and a translated key name would be a lie. Only the action
/// column goes through the ARB.
class KeyboardShortcutsPage extends StatelessWidget {
  const KeyboardShortcutsPage({super.key});

  static const _shortcuts = [
    ('Space / K', _ShortcutAction.playPause),
    ('J / ←', _ShortcutAction.seekBack),
    ('L / →', _ShortcutAction.seekForward),
    ('↑ / ↓', _ShortcutAction.volume),
    ('M', _ShortcutAction.mute),
    ('C', _ShortcutAction.subtitles),
    ('A', _ShortcutAction.audioTrack),
    ('S', _ShortcutAction.playbackSpeed),
    ('R', _ShortcutAction.aspectRatio),
    ('F', _ShortcutAction.fullscreen),
    ('Esc', _ShortcutAction.back),
    ('Tab', _ShortcutAction.focusHub),
  ];

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsCategoryKeyboardShortcuts,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SettingsScrollView(
        minGutter: 20,
        topPadding: 24,
        bottomPadding: 24,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inkAlpha(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (key, action) in _shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        // The key chip is the one thing here that cannot
                        // wrap: "Space / K" is a single token. At 3x it is
                        // wider than the row, so it scales down rather than
                        // pushing the action off the edge.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.inkAlpha(0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                key,
                                style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.label(l10n),
                            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The action column, kept as an enum rather than a raw string so the list
/// above stays `const` and the lookup stays exhaustive -- adding a shortcut
/// without a translation is a compile error, not a missing string at runtime.
enum _ShortcutAction {
  playPause,
  seekBack,
  seekForward,
  volume,
  mute,
  subtitles,
  audioTrack,
  playbackSpeed,
  aspectRatio,
  fullscreen,
  back,
  focusHub;

  String label(AppLocalizations l10n) => switch (this) {
    _ShortcutAction.playPause => l10n.shortcutsPlayPause,
    _ShortcutAction.seekBack => l10n.shortcutsSeekBack,
    _ShortcutAction.seekForward => l10n.shortcutsSeekForward,
    _ShortcutAction.volume => l10n.shortcutsVolume,
    _ShortcutAction.mute => l10n.shortcutsMute,
    _ShortcutAction.subtitles => l10n.shortcutsSubtitles,
    _ShortcutAction.audioTrack => l10n.shortcutsAudioTrack,
    _ShortcutAction.playbackSpeed => l10n.shortcutsPlaybackSpeed,
    _ShortcutAction.aspectRatio => l10n.shortcutsAspectRatio,
    _ShortcutAction.fullscreen => l10n.shortcutsFullscreen,
    _ShortcutAction.back => l10n.shortcutsBack,
    _ShortcutAction.focusHub => l10n.shortcutsFocusHub,
  };
}
