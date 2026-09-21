import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../services/theme/app_theme_service.dart';
import '../../../services/content_display_enums.dart';
import '../../../services/iptv/iptv_settings.dart';
import '../../../widgets/settings/settings_scroll_view.dart';
import '../../../services/theme/app_colors.dart';
import '../../../widgets/common/setting_choice_chip.dart';
import '../../../widgets/iptv/default_portal_tab_picker.dart';

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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.liveTvSettingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildHeroSpotlightCard(palette),

          const SizedBox(height: 28),

          // ── 2. Card Layout & Poster Density ──
          Text(
            context.l10n.liveTvSecCards.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildCardDensityCard(palette),

          const SizedBox(height: 28),

          // ── 3. Category Visibility & Ordering ──
          Text(
            context.l10n.liveTvSecSections.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryManagerCard(palette),

          const SizedBox(height: 28),

          // ── 4. Portals Modal Customization ──
          Text(
            context.l10n.liveTvSecPortalsModal.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildPortalsModalCustomizerCard(palette),

          const SizedBox(height: 28),

          // ── 5. Portal Browser Customization ──
          Text(
            context.l10n.liveTvSecBrowser.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildPortalBrowserCustomizerCard(palette),

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildHeroSpotlightCard(AppThemePalette palette) {
    return ValueListenableBuilder<bool>(
      valueListenable: IptvSettings.enableSpotlight,
      builder: (context, enabled, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tv_rounded,
                      color: palette.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.liveTvShowSpotlight,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowSpotlightSub,
                          style: TextStyle(fontSize: 12, color: AppColors.inkSubtle),
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
                const SizedBox(height: 16),
                Divider(color: AppColors.inkAlpha(0.06)),
                const SizedBox(height: 12),

                // Style Selection
                Text(
                  context.l10n.liveTvHeroStyle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkAlpha(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<HeroStyle>(
                  valueListenable: IptvSettings.heroStyle,
                  builder: (context, currentStyle, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: HeroStyle.values.map((style) {
                        final isSelected = style == currentStyle;
                        return SettingChoiceChip(
                          label: style.localizedLabel(context.l10n),
                          selected: isSelected,
                          onSelect: () {
                            IptvSettings.setHeroStyle(style);
                            setState(() {});
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),
                Divider(color: AppColors.inkAlpha(0.06)),
                const SizedBox(height: 12),

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
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.liveTvAutoRotateSub,
                                style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Expanded: the label yields to the value beside it. At a large text
                                // scale this Row ran 692px past the card (#69).
                                Expanded(child: Text(
                                  context.l10n.liveTvRotationInterval,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.inkAlpha(0.7),
                                  ),
                                )),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.liveTvSecondsN(seconds),
                                  // The value has nowhere to go; the label beside it is the part that
                                  // wraps, so this one is clamped instead.
                                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: palette.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Density Choice
          Text(
            context.l10n.liveTvCardSize,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<CardDensity>(
            valueListenable: IptvSettings.cardDensity,
            builder: (context, currentDensity, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
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

          const SizedBox(height: 16),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                      Text(
                        context.l10n.liveTvHoverZoom,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkAlpha(0.8),
                        ),
                      ),
                      Text(
                        '+$percent%',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: palette.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowHdBadgeSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowCategoryTagSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.liveTvToggleRows,
                        style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => IptvSettings.resetCategories(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(context.l10n.liveTvResetAll, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppColors.inkAlpha(0.06)),
              const SizedBox(height: 6),

              ...IptvSettings.defaultCategories.map((cat) {
                final isVisible = visibleList.contains(cat);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13.5,
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

  Widget _buildPortalsModalCustomizerCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.iptvCardDisplayStyle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<PortalCardStyle>(
            valueListenable: IptvSettings.portalCardStyle,
            builder: (context, style, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
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

          const SizedBox(height: 16),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowExpirySub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowConnTagSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

          Text(
            context.l10n.iptvDefaultTab,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          const SizedBox(height: 8),
          const DefaultPortalTabPicker(),
        ],
      ),
    );
  }

  Widget _buildPortalBrowserCustomizerCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.iptvStreamLayoutMode,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.8),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<PortalBrowserLayout>(
            valueListenable: IptvSettings.browserLayout,
            builder: (context, layout, _) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
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

          const SizedBox(height: 16),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkAlpha(0.8),
                            ),
                          )),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.liveTvColumnsN(cols),
                            // The value has nowhere to go; the label beside it is the part that
                            // wraps, so this one is clamped instead.
                            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: palette.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 12),
                      Divider(color: AppColors.inkAlpha(0.06)),
                      const SizedBox(height: 12),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkAlpha(0.8),
                        ),
                      )),
                      const SizedBox(width: 8),
                      Text(
                        '${width.round()} px',
                        // The value has nowhere to go; the label beside it is the part that
                        // wraps, so this one is clamped instead.
                        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: palette.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowLogosSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowEpgSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06)),
          const SizedBox(height: 12),

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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.liveTvShowCountsSub,
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkSubtle),
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
