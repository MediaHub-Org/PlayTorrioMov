// lib/widgets/common/section_sub_tabs.dart
import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'pill_tab_row.dart';

export 'pill_tab_row.dart' show SubTab;

/// A segmented control that splits a single hub section into two related
/// views — Movies/Series, Comics/Manga.
///
/// Each hub exposes exactly four sections so the mobile bottom bar has a fixed
/// shape. Pairs that would have made a fifth live here instead: they stay
/// distinct catalogs, one tap apart, rather than being merged into one
/// undifferentiated list.
class SectionSubTabs extends StatelessWidget {
  final List<SubTab> tabs;
  final String activeId;
  final ValueChanged<String> onSelected;

  /// The page for the active tab.
  final Widget child;

  const SectionSubTabs({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: PillTabRow(
            tabs: tabs,
            activeId: activeId,
            onSelected: onSelected,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
