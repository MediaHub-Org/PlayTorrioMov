import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../services/content_display_enums.dart';
import '../../../services/iptv/iptv_settings.dart';
import '../../../utils/navigation/route_transitions.dart';
import '../../../widgets/settings/settings_scroll_view.dart';
import '../../../services/theme/app_colors.dart';
import '../../../widgets/common/setting_choice_chip.dart';
import '../../../widgets/iptv/default_portal_tab_picker.dart';
import '../../../pages/iptv/iptv_sources_page.dart';
import '../../../services/app_units.dart';

class LiveTvSettingsPage extends StatefulWidget {
  const LiveTvSettingsPage({super.key});

  @override
  State<LiveTvSettingsPage> createState() => _LiveTvSettingsPageState();
}

class _LiveTvSettingsPageState extends State<LiveTvSettingsPage> {
  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.liveTvSettingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // ── 1. Hero Spotlight Carousel ──
          Text(
            context.l10n.liveTvSecSpotlight.toUpperCase(),
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildHeroSpotlightCard(palette),

          SizedBox(height: context.rem(1.75)),

          // ── 2. Card Layout & Poster Density ──
          Text(
            context.l10n.liveTvSecCards.toUpperCase(),
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildCardDensityCard(palette),

          SizedBox(height: context.rem(1.75)),

          // ── 3. Category Visibility & Ordering ──
          Text(
            context.l10n.liveTvSecSections.toUpperCase(),
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildCategoryManagerCard(palette),

          SizedBox(height: context.rem(1.75)),

          // ── 4. Portals Modal Customization ──
          Text(
            context.l10n.liveTvSecPortalsModal.toUpperCase(),
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildPortalsModalCustomizerCard(palette),

          SizedBox(height: context.rem(1.75)),

          // ── 5. Portal Browser Customization ──
          Text(
            context.l10n.liveTvSecBrowser.toUpperCase(),
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildPortalBrowserCustomizerCard(palette),

          SizedBox(height: context.rem(2.25)),
        ],
      ),
    );
  }

  Widget _buildHeroSpotlightCard(AppThemePalette palette) {
    return ValueListenableBuilder<bool>(
      valueListenable: IptvSettings.enableSpotlight,
      builder: (context, enabled, _) {
        return Container(
          padding: EdgeInsets.all(context.rem(1.125)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            border: Border.all(
              color: enabled
                  ? palette.primaryColor.withValues(alpha: 0.35)
                  : AppColors.inkAlpha(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Toggle
              Row(
                children: [
                  Container(
                    width: context.rem(2.625),
                    height: context.rem(2.625),
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                    child: Icon(
                      Icons.tv_rounded,
                      color: palette.primaryColor,
                      size: context.rem(AppRem.iconMd),
                    ),
                  ),
                  SizedBox(width: context.rem(0.875)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowSpotlight,
                          style: TextStyle(
                            fontSize: AppType.bodyMd,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowSpotlightSub,
                          style: TextStyle(fontSize: AppType.caption, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: palette.primaryColor,
                    onChanged: (val) {
                      IptvSettings.setEnableSpotlight(val);
                      setState(() {});
                    },
                  ),
                ],
              ),

              if (enabled) ...[
                SizedBox(height: context.rem(AppRem.md)),
                Divider(color: AppColors.inkAlpha(0.06)),
                SizedBox(height: context.rem(AppRem.ms)),

                // Auto Rotate
                ValueListenableBuilder<bool>(
                  valueListenable: IptvSettings.heroAutoRotate,
                  builder: (context, autoRotate, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.liveTvAutoRotate,
                                style: TextStyle(
                                  fontSize: AppType.smallPlus,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: context.rem(AppRem.xxs)),
                              Text(
                                context.l10n.liveTvAutoRotateSub,
                                style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: autoRotate,
                          activeColor: palette.primaryColor,
                          onChanged: (val) => IptvSettings.setHeroAutoRotate(val),
                        ),
                      ],
                    );
                  },
                ),

                // Rotate Timer Slider
                ValueListenableBuilder<bool>(
                  valueListenable: IptvSettings.heroAutoRotate,
                  builder: (context, autoRotate, _) {
                    if (!autoRotate) return const SizedBox.shrink();
                    return ValueListenableBuilder<int>(
                      valueListenable: IptvSettings.heroRotateSeconds,
                      builder: (context, seconds, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: context.rem(0.625)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Expanded: the label yields to the value beside it. At a large text
                                // scale this Row ran 692px past the card (#69).
                                Expanded(child: Text(
                                  context.l10n.liveTvRotationInterval,
                                  style: TextStyle(
                                    fontSize: AppType.captionPlus,
                                    color: AppColors.inkAlpha(0.7),
                                  ),
                                )),
                                SizedBox(width: context.rem(AppRem.sm)),
                                Text(
                                  context.l10n.liveTvSecondsN(seconds),
                                  // The value has nowhere to go; the label beside it is the part that
                                  // wraps, so this one is clamped instead.
                                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                                  style: TextStyle(
                                    fontSize: AppType.captionPlus,
                                    fontWeight: FontWeight.w800,
                                    color: palette.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: palette.primaryColor,
                                inactiveTrackColor: AppColors.inkAlpha(0.08),
                                thumbColor: palette.primaryColor,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: seconds.toDouble(),
                                min: 3,
                                max: 15,
                                divisions: 12,
                                onChanged: (val) => IptvSettings.setHeroRotateSeconds(val.round()),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardDensityCard(AppThemePalette palette) {
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
          // Density Choice
          Text(
            context.l10n.liveTvCardSize,
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          ValueListenableBuilder<CardDensity>(
            valueListenable: IptvSettings.cardDensity,
            builder: (context, currentDensity, _) {
              return Wrap(
                spacing: context.rem(AppRem.sm),
                runSpacing: context.rem(AppRem.sm),
                children: CardDensity.values.map((density) {
                  final isSelected = density == currentDensity;
                  return SettingChoiceChip(
                    label: density.localizedLabel(context.l10n),
                    selected: isSelected,
                    onSelect: () {
                      IptvSettings.setCardDensity(density);
                      setState(() {});
                    },
                  );
                }).toList(),
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.md)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          // Hover Zoom Slider
          ValueListenableBuilder<double>(
            valueListenable: IptvSettings.cardHoverZoom,
            builder: (context, zoom, _) {
              final percent = ((zoom - 1.0) * 100).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Expanded: the label yields to the value beside it, the
                      // same shape as the rotation row above. In Spanish the
                      // label runs 490px in a 360px panel.
                      Expanded(child: Text(
                        context.l10n.liveTvHoverZoom,
                        style: TextStyle(
                          fontSize: AppType.small,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkAlpha(0.8),
                        ),
                      )),
                      Text(
                        '+$percent%',
                        style: TextStyle(
                          fontSize: AppType.captionPlus,
                          fontWeight: FontWeight.w800,
                          color: palette.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(AppRem.xs)),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: palette.primaryColor,
                      inactiveTrackColor: AppColors.inkAlpha(0.08),
                      thumbColor: palette.primaryColor,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: zoom,
                      min: 1.00,
                      max: 1.15,
                      divisions: 15,
                      onChanged: (val) => IptvSettings.setCardHoverZoom(val),
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          // HD Badge Toggle
          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showHdBadge,
            builder: (context, showHd, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowHdBadge,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowHdBadgeSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showHd,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowHdBadge(val),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          // Category Tag Toggle
          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showCategoryTag,
            builder: (context, showTag, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowCategoryTag,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowCategoryTagSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showTag,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowCategoryTag(val),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryManagerCard(AppThemePalette palette) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: IptvSettings.visibleCategories,
      builder: (context, visibleList, _) {
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.liveTvCategoriesSections,
                        style: TextStyle(
                          fontSize: AppType.bodyPlus,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: context.rem(AppRem.xxs)),
                      Text(
                        context.l10n.liveTvToggleRows,
                        style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => IptvSettings.resetCategories(),
                    icon: Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconXs)),
                    label: Text(context.l10n.liveTvResetAll, style: const TextStyle(fontSize: AppType.caption)),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rem(AppRem.ms)),
              Divider(color: AppColors.inkAlpha(0.06)),
              SizedBox(height: context.rem(AppRem.snug)),

              ...IptvSettings.defaultCategories.map((cat) {
                final isVisible = visibleList.contains(cat);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    cat,
                    style: TextStyle(
                      fontSize: AppType.smallPlus,
                      fontWeight: isVisible ? FontWeight.w700 : FontWeight.w500,
                      color: isVisible ? AppColors.ink : AppColors.inkDisabled,
                    ),
                  ),
                  value: isVisible,
                  activeColor: palette.primaryColor,
                  checkColor: AppColors.ink,
                  onChanged: (val) {
                    IptvSettings.toggleCategoryVisibility(cat);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Sources live on their own page now; this card keeps the row display
  /// preferences that used to sit beside them in the modal, plus the way
  /// in. Management happens on the page, configuration stays here.
  Widget _buildPortalsModalCustomizerCard(AppThemePalette palette) {
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
          InkWell(
            onTap: () => pushPage(context, const IptvSourcesPage()),
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.snug)),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_input_antenna_rounded,
                    color: palette.primaryColor,
                    size: context.rem(AppRem.icon),
                  ),
                  SizedBox(width: context.rem(AppRem.ms)),
                  Expanded(
                    child: Text(
                      context.l10n.iptvManagePortals,
                      style: TextStyle(
                        fontSize: AppType.smallPlus,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkSubtle,
                    size: context.rem(AppRem.icon),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),
          Text(
            context.l10n.iptvCardDisplayStyle,
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          ValueListenableBuilder<PortalCardStyle>(
            valueListenable: IptvSettings.portalCardStyle,
            builder: (context, style, _) {
              return Wrap(
                spacing: context.rem(AppRem.sm),
                runSpacing: context.rem(AppRem.sm),
                children: PortalCardStyle.values.map((s) {
                  final isSelected = s == style;
                  return SettingChoiceChip(
                    label: s.localizedLabel(context.l10n),
                    selected: isSelected,
                    onSelect: () {
                      IptvSettings.setPortalCardStyle(s);
                      setState(() {});
                    },
                  );
                }).toList(),
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.md)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showPortalExpiry,
            builder: (context, showExpiry, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.iptvShowExpiry,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowExpirySub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showExpiry,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowPortalExpiry(val),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showPortalConnections,
            builder: (context, showConn, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowConnTag,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowConnTagSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showConn,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowPortalConnections(val),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          Text(
            context.l10n.iptvDefaultTab,
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          const DefaultPortalTabPicker(),
        ],
      ),
    );
  }

  Widget _buildPortalBrowserCustomizerCard(AppThemePalette palette) {
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
          Text(
            context.l10n.iptvStreamLayoutMode,
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          ValueListenableBuilder<PortalBrowserLayout>(
            valueListenable: IptvSettings.browserLayout,
            builder: (context, layout, _) {
              return Wrap(
                spacing: context.rem(AppRem.sm),
                runSpacing: context.rem(AppRem.sm),
                children: PortalBrowserLayout.values.map((l) {
                  final isSelected = l == layout;
                  return SettingChoiceChip(
                    label: l.localizedLabel(context.l10n),
                    selected: isSelected,
                    onSelect: () {
                      IptvSettings.setBrowserLayout(l);
                      setState(() {});
                    },
                  );
                }).toList(),
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.md)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<PortalBrowserLayout>(
            valueListenable: IptvSettings.browserLayout,
            builder: (context, layout, _) {
              if (layout != PortalBrowserLayout.grid) return const SizedBox.shrink();
              return ValueListenableBuilder<int>(
                valueListenable: IptvSettings.browserGridColumns,
                builder: (context, cols, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded: the label yields to the value beside it. At a large text
                          // scale this Row ran 692px past the card (#69).
                          Expanded(child: Text(
                            context.l10n.liveTvGridColumns,
                            style: TextStyle(
                              fontSize: AppType.small,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkAlpha(0.8),
                            ),
                          )),
                          SizedBox(width: context.rem(AppRem.sm)),
                          Text(
                            context.l10n.liveTvColumnsN(cols),
                            // The value has nowhere to go; the label beside it is the part that
                            // wraps, so this one is clamped instead.
                            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                            style: TextStyle(
                              fontSize: AppType.captionPlus,
                              fontWeight: FontWeight.w800,
                              color: palette.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rem(AppRem.xs)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: palette.primaryColor,
                          inactiveTrackColor: AppColors.inkAlpha(0.08),
                          thumbColor: palette.primaryColor,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: cols.toDouble(),
                          min: 2,
                          max: 6,
                          divisions: 4,
                          onChanged: (val) => IptvSettings.setBrowserGridColumns(val.round()),
                        ),
                      ),
                      SizedBox(height: context.rem(AppRem.ms)),
                      Divider(color: AppColors.inkAlpha(0.06)),
                      SizedBox(height: context.rem(AppRem.ms)),
                    ],
                  );
                },
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: IptvSettings.sidebarWidth,
            builder: (context, width, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Expanded: the label yields to the value beside it. At a large text
                      // scale this Row ran 692px past the card (#69).
                      Expanded(child: Text(
                        context.l10n.liveTvSidebarWidth,
                        style: TextStyle(
                          fontSize: AppType.small,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkAlpha(0.8),
                        ),
                      )),
                      SizedBox(width: context.rem(AppRem.sm)),
                      Text(
                        '${width.round()} px',
                        // The value has nowhere to go; the label beside it is the part that
                        // wraps, so this one is clamped instead.
                        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                        style: TextStyle(
                          fontSize: AppType.captionPlus,
                          fontWeight: FontWeight.w800,
                          color: palette.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(AppRem.xs)),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: palette.primaryColor,
                      inactiveTrackColor: AppColors.inkAlpha(0.08),
                      thumbColor: palette.primaryColor,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: width,
                      min: 200.0,
                      max: 340.0,
                      divisions: 14,
                      onChanged: (val) => IptvSettings.setSidebarWidth(val),
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showStreamLogos,
            builder: (context, showLogos, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowLogos,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowLogosSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showLogos,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowStreamLogos(val),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showEpgSnippet,
            builder: (context, showEpg, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowEpg,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowEpgSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showEpg,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowEpgSnippet(val),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: context.rem(AppRem.ms)),
          Divider(color: AppColors.inkAlpha(0.06)),
          SizedBox(height: context.rem(AppRem.ms)),

          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.showCategoryCount,
            builder: (context, showCount, _) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowCounts,
                          style: TextStyle(
                            fontSize: AppType.smallPlus,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          context.l10n.liveTvShowCountsSub,
                          style: TextStyle(fontSize: AppType.tinyPlus, color: AppColors.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: showCount,
                    activeColor: palette.primaryColor,
                    onChanged: (val) => IptvSettings.setShowCategoryCount(val),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
