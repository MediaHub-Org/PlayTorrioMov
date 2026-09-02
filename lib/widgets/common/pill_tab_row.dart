// lib/widgets/common/pill_tab_row.dart
import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';

/// One choice inside a [PillTabRow] / [SectionSubTabs] control.
class SubTab {
  final String id;
  final String label;
  final IconData icon;

  const SubTab({required this.id, required this.label, required this.icon});
}

/// The segmented pill control itself, extracted from [SectionSubTabs] so a
/// page can position it inline (e.g. beside other filter controls) instead
/// of always wrapping the whole page in its own row above everything.
class PillTabRow extends StatelessWidget {
  final List<SubTab> tabs;
  final String activeId;
  final ValueChanged<String> onSelected;

  const PillTabRow({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Scrolls rather than overflows. Two short labels always fit, but a
    // three-way split with longer ones ("Audiobooks / Books / Manga")
    // runs past a 360px phone, and further still at a large text scale.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tab in tabs)
              _SubTabButton(
                tab: tab,
                selected: tab.id == activeId,
                onTap: () => onSelected(tab.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final SubTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C5CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.icon,
              size: 15,
              color: selected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
