import 'package:flutter/material.dart';

/// A small pill button that opens a popup menu — used for sort/filter
/// controls on catalog pages (e.g. decade filter + sort on Movies/Series,
/// genre filter on Anime).
class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T?> onSelected;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      itemBuilder: (context) => items,
      onSelected: onSelected,
      color: const Color(0xFF151822),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}
