import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/app_units.dart';
import '../../../services/browse/home_rows_settings.dart';
import '../../../services/theme/app_colors.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../widgets/settings/settings_scroll_view.dart';

/// Toggles for the Films, Series and Anime home rows: the same shape as the
/// Live TV category manager, one card per section. Everything shows by
/// default; rows for addon catalogs appear here once their section has
/// loaded them, since their titles come from installed addons and cannot
/// be listed up front.
class HomeRowsSettingsPage extends StatelessWidget {
  const HomeRowsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: context.rem(AppRem.icon),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.homeRowsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: AppType.headline,
          ),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: context.rem(AppRem.md)),
            child: Text(
              context.l10n.homeRowsSub,
              style: TextStyle(
                fontSize: AppType.smallPlus,
                color: AppColors.inkSubtle,
              ),
            ),
          ),
          _SectionCard(
            section: HomeSection.movies,
            title: context.l10n.navMovies,
          ),
          SizedBox(height: context.rem(AppRem.lg)),
          _SectionCard(
            section: HomeSection.series,
            title: context.l10n.navSeries,
          ),
          SizedBox(height: context.rem(AppRem.lg)),
          _SectionCard(
            section: HomeSection.anime,
            title: context.l10n.navAnime,
          ),
        ],
      ),
    );
  }
}

/// One section's rows: a title, a reset-everything action, and a checkbox
/// per row. Mirrors the Live TV category card, so the two managers read as
/// the same control in different places rather than two designs.
class _SectionCard extends StatelessWidget {
  final HomeSection section;
  final String title;

  const _SectionCard({required this.section, required this.title});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    return ValueListenableBuilder<List<String>>(
      valueListenable: HomeRowsSettings.visibleFor(section),
      builder: (context, visible, _) {
        return Container(
          padding: EdgeInsets.all(context.rem(1.125)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            border: Border.all(color: AppColors.inkAlpha(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppType.bodyPlus,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => HomeRowsSettings.resetSection(section),
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: context.rem(AppRem.iconXs),
                    ),
                    label: Text(
                      context.l10n.liveTvResetAll,
                      style: const TextStyle(fontSize: AppType.caption),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rem(AppRem.ms)),
              Divider(color: AppColors.inkAlpha(0.06)),
              SizedBox(height: context.rem(AppRem.snug)),
              for (final id in HomeRowsSettings.displayIds(section))
                _RowToggle(
                  section: section,
                  id: id,
                  visible: visible.contains(id),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One row's checkbox, in display order: the built-ins first, then
/// registered addon rows in the order they were first seen. A hidden row
/// stays listed and unchecked -- hiding it removes it from its home page,
/// never from this list.
class _RowToggle extends StatelessWidget {
  final HomeSection section;
  final String id;
  final bool visible;

  const _RowToggle({
    required this.section,
    required this.id,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // Its own Material: the card paints a background behind this tile, and
    // without one the tile's ripples would paint on whatever Material sits
    // further up instead -- invisible, and a debug assertion in tests.
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          HomeRowsSettings.labelOf(section, id, context.l10n),
          style: TextStyle(
            fontSize: AppType.smallPlus,
            fontWeight: visible ? FontWeight.w700 : FontWeight.w500,
            color: visible ? AppColors.ink : AppColors.inkDisabled,
          ),
        ),
        value: visible,
        activeColor: AppThemeService.currentPalette.value.primaryColor,
        checkColor: AppColors.ink,
        onChanged: (val) =>
            HomeRowsSettings.toggleRow(section, id, visible: val == true),
      ),
    );
  }
}
