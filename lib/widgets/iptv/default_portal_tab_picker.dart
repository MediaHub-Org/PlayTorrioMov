// lib/widgets/iptv/default_portal_tab_picker.dart
import 'package:flutter/material.dart';

import '../../services/iptv/iptv_settings.dart';
import '../common/setting_choice_chip.dart';

/// Picks which tab the portals screen opens on — Xtream panels or M3U
/// playlists.
///
/// One control that happens to be reachable from two places: the portals
/// modal itself, and Live TV's settings page. Both had it written out, which
/// is what the audit counted as the last of the duplication between those
/// files. The heading above it stays with each caller, since the two pages
/// style their own section headings.
///
/// The index is the stored setting's own encoding (0 = Xtream, 1 = M3U), not
/// a position in this row, so the row's order is a layout choice here rather
/// than something the setting depends on.
class DefaultPortalTabPicker extends StatelessWidget {
  const DefaultPortalTabPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: IptvSettings.defaultPortalTab,
      builder: (context, tabIdx, _) {
        return Row(
          children: [
            SettingChoiceChip(
              label: 'Xtream Panels',
              selected: tabIdx == 0,
              onSelect: () => IptvSettings.setDefaultPortalTab(0),
            ),
            const SizedBox(width: 8),
            SettingChoiceChip(
              label: 'M3U Playlists',
              selected: tabIdx == 1,
              onSelect: () => IptvSettings.setDefaultPortalTab(1),
            ),
          ],
        );
      },
    );
  }
}
