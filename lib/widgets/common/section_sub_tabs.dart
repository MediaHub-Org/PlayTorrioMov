import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';

/// One choice inside a [SectionSubTabs] control.
class SubTab {
  final String id;
  final String label;
  final IconData icon;

  const SubTab({required this.id, required this.label, required this.icon});
}

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
          // Scrolls rather than overflows. Two short labels always fit, but a
          // three-way split with longer ones ("Audiobooks / Books / Manga")
          // runs past a 360px phone, and further still at a large text scale.
          child: SingleChildScrollView(
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
          ),
        ),
        Expanded(child: child),
      ],
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
