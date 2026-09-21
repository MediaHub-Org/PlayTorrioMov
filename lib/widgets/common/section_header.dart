import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/app_colors.dart';

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
    AppColors.dependOn(context);
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
                      color: AppColors.inkAlpha(0.38),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            // Flexible on the button itself, not just inside it. The title
            // beside it is Expanded and takes its share, but the button's
            // own intrinsic width -- "See All" plus its chevron plus its
            // padding -- still wanted 8.7px more than the row had at 3x.
            // Small, and real: this is the heading above every row on every
            // browse page.
            Flexible(
              child: Padding(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.commonSeeAll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
