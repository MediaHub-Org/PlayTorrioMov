import 'package:flutter/material.dart';
import '../../services/app_spacing.dart';
import '../../services/theme/app_theme_service.dart';

/// Clean section header — title on left, optional "See All" on right.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppThemeService.currentPalette.value.primaryColor;

    return Padding(
      // Bottom matches the loading skeleton's own title placeholder
      // (BrowseScaffold._buildLoading) so the real header doesn't shift the
      // row down once content replaces the skeleton. Used to be 0, leaving
      // the title flush against the card row with no breathing room.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageInset(context),
        8,
        AppSpacing.pageInset(context),
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
