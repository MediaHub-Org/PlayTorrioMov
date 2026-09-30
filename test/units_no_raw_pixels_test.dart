// test/units_no_raw_pixels_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files whose sizes come from `AppRem`/`AppType`/`context.rem`, not bare
/// numbers. A file joins this list when it is migrated; from then on a
/// literal size in it fails here, so the migration cannot quietly undo itself.
///
/// The migration is by batches (see the roadmap). A file not listed is simply
/// not migrated yet, and is not checked.
const migratedFiles = <String>[
  'lib/widgets/common/tv_side_menu.dart',
  'lib/widgets/common/hero_action_button.dart',
  'lib/widgets/common/focus_highlight.dart',
  'lib/widgets/common/tv_focus_bridge.dart',
  'lib/widgets/common/top_bar.dart',
  'lib/widgets/common/section_chips.dart',
  'lib/widgets/common/filter_dropdown.dart',
  'lib/widgets/common/header_pill_style.dart',
  'lib/widgets/common/section_header.dart',
  'lib/widgets/common/adaptive_nav_shell.dart',
  'lib/widgets/common/pill_filter_header_bar.dart',
  'lib/widgets/common/universal_play_bar.dart',
  'lib/widgets/common/sidebar_logo.dart',
  'lib/widgets/movie/movie_card.dart',
  'lib/widgets/anime/anime_card.dart',
  'lib/widgets/common/browse_row_view.dart',
  'lib/widgets/common/browse_scaffold.dart',
  'lib/widgets/iptv/iptv_slider_section.dart',
  'lib/pages/details/details_page.dart',
  'lib/pages/anime/anime_details_page.dart',
  'lib/widgets/details/details_metrics.dart',
  'lib/pages/iptv/iptv_player_page.dart',
  'lib/pages/player/player_screen.dart',
  'lib/pages/player/watch_screen.dart',
  'lib/widgets/player/language_flag.dart',
  'lib/widgets/player/performance_liquid_lens.dart',
  'lib/widgets/player/player_aspect_menu.dart',
  'lib/widgets/player/player_audio_menu.dart',
  'lib/widgets/player/player_cast_sheet.dart',
  'lib/widgets/player/player_center_controls.dart',
  'lib/widgets/player/player_episodes_panel.dart',
  'lib/widgets/player/player_glass.dart',
  'lib/widgets/player/player_menu_row.dart',
  'lib/widgets/player/player_seek_bar.dart',
  'lib/widgets/player/player_seek_feedback.dart',
  'lib/widgets/player/player_skip_button.dart',
  'lib/widgets/player/player_sources_panel.dart',
  'lib/widgets/player/player_speed_menu.dart',
  'lib/widgets/player/player_sub_style_modal.dart',
  'lib/widgets/player/player_subtitle_menu.dart',
  'lib/widgets/player/player_top_bar.dart',
  'lib/widgets/player/player_transport.dart',
  'lib/widgets/player/player_volume_control.dart',
  'lib/widgets/player/sleep_timer_menu.dart',
  'lib/widgets/player/sub_sync_bar.dart',
  'lib/widgets/player/subtitle_overlay.dart',
  'lib/widgets/player/text_sync_overlay.dart',
  'lib/pages/settings/about_settings_page.dart',
  'lib/pages/settings/addons_settings_page.dart',
  'lib/pages/settings/appearance/live_tv_settings_page.dart',
  'lib/pages/settings/appearance_settings_page.dart',
  'lib/pages/settings/backup_settings_page.dart',
  'lib/pages/settings/builtin_providers_settings_page.dart',
  'lib/pages/settings/debrid_settings_page.dart',
  'lib/pages/settings/keyboard_shortcuts_page.dart',
  'lib/pages/settings/settings_page.dart',
  'lib/pages/settings/source_filter_settings_page.dart',
  'lib/pages/settings/sync_settings_page.dart',
  'lib/pages/settings/video_player_settings_page.dart',
  'lib/widgets/p2p/p2p_warning_dialog.dart',
  'lib/widgets/updater/update_dialog.dart',
];

/// A size written as a number. A line that must keep one -- a hairline border,
/// which is meant to stay one pixel at any text size -- says so with `// px`,
/// and a unitless ratio such as a line height with `// ratio`.
final _rawSize = <RegExp>[
  RegExp(
    r'\b(width|height|minWidth|minHeight|maxWidth|maxHeight|size|fontSize|'
    r'blurRadius|spreadRadius|radius|borderRadius|horizontal|vertical|left|'
    r'right|top|bottom|start|end)\s*:\s*[^,;]*(?<![\w.])[1-9]\d*(\.\d+)?\b',
  ),
  RegExp(r'EdgeInsets\.\w+\([^)]*(?<![\w.])[1-9]'),
  RegExp(r'Radius\.circular\(\s*\d'),
  RegExp(r'(?<![\w.])Offset\(\s*[^)]*[1-9]'),
];

/// [code] with every `context.rem(...)` call (balanced, so a nested call is
/// fine) replaced by a placeholder: what is inside is already in rem.
String _withoutRem(String code) {
  const open = 'context.rem(';
  var out = code;
  var at = out.indexOf(open);
  while (at >= 0) {
    var depth = 1;
    var i = at + open.length;
    while (i < out.length && depth > 0) {
      if (out[i] == '(') depth++;
      if (out[i] == ')') depth--;
      i++;
    }
    out = '${out.substring(0, at)}R${out.substring(i)}';
    at = out.indexOf(open);
  }
  return out;
}

void main() {
  for (final path in migratedFiles) {
    test('$path has no bare pixel sizes', () {
      final lines = File(path).readAsLinesSync();
      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A rem literal is the unit, not a bare number: `context.rem(1.25)`.
        final code = _withoutRem(line.split('//').first);
        if (line.contains('// px') || line.contains('// ratio')) continue;
        if (_rawSize.any((re) => re.hasMatch(code))) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'use context.rem(AppRem.x) for a size and AppType.x for a font '
            'size (lib/services/app_units.dart), or mark a deliberate '
            'hairline with "// px"',
      );
    });
  }
}
