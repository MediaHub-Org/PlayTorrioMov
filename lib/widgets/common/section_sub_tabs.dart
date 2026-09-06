// lib/widgets/common/section_sub_tabs.dart
import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import 'pill_tab_row.dart';

export 'pill_tab_row.dart' show SubTab;

/// A segmented control that splits a single hub section into two related
/// views. Not currently used by any hub section — Movies/Series (the
/// original motivating case) became two full top-level sections instead of
/// sharing one with this toggle — but kept for a future pair that would
/// rather stay one section with two views than grow the section count.
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
