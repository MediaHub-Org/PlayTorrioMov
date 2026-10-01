import '../../widgets/common/focus_fill.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/iptv_settings.dart';
import 'appearance/live_tv_settings_page.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_units.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    // Colors come from the theme on this page, not from constants. It is
    // the page the theme switch lives on, so it is the one page that has to
    // be readable in whichever mode the switch just selected.
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.appearanceTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // Header description
          Padding(
            padding: EdgeInsets.only(bottom: context.rem(1.25)),
            child: Text(
              l10n.appearanceSubtitle,
              style: TextStyle(
                fontSize: AppType.smallPlus,
                color: onSurface.withValues(alpha: 0.5),
                height: 1.4, // ratio: a line height, not a size
              ),
            ),
          ),

          // Theme mode. First on the page because it is the broadest
          // visual choice here -- everything below it is a detail of
          // whichever mode you land in.
          const _ThemeModeSelector(),

          SizedBox(height: context.rem(1.25)),

          const _TextScaleSelector(),

          SizedBox(height: context.rem(1.25)),

          const _LanguageSelector(),

          SizedBox(height: context.rem(1.25)),

          // Button: Live TV & Sports UI
          ValueListenableBuilder<bool>(
            valueListenable: IptvSettings.enableSpotlight,
            builder: (context, spotlightEnabled, _) {
              return ValueListenableBuilder<AppThemePalette>(
                valueListenable: AppThemeService.currentPalette,
                builder: (context, currentPalette, _) {
                  return _buildSectionButton(
                    icon: Icons.live_tv_rounded,
                    iconColor: currentPalette.primaryColor,
                    title: context.l10n.liveTvSettingsTitle,
                    subtitle: context.l10n.liveTvSettingsSub,
                    badgeText: spotlightEnabled ? 'Spotlight ON' : 'Compact',
                    badgeColor: currentPalette.primaryColor,
                    onTap: () async {
                      await pushPage(context, const LiveTvSettingsPage());
                      setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: FocusFill(
        radius: context.rem(AppRem.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
          child: Container(
            padding: EdgeInsets.all(context.rem(1.125)),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
              border: Border.all(color: onSurface.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: context.rem(2.875),
                  height: context.rem(2.875),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                  ),
                  child: Icon(icon, color: iconColor, size: context.rem(AppRem.iconLg)),
                ),
                SizedBox(width: context.rem(0.875)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: AppType.bodyLg,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: context.rem(AppRem.sm)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(0.1562)),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: AppType.tiny,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.rem(AppRem.xs)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppType.caption,
                          color: onSurface.withValues(alpha: 0.45),
                          height: 1.35, // ratio: a line height, not a size
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rem(0.625)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: context.rem(AppRem.iconXs),
                  color: onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// System / Light / Dark, as three segments rather than a toggle.
///
/// A two-state switch cannot express "follow the system", which is the
/// default and the one most people want -- with a switch, the only way to
/// say it is to leave the app's idea of the theme permanently out of step
/// with the device's.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppThemeService.themeMode,
          builder: (context, mode, _) {
            final theme = Theme.of(context);
            final onSurface = theme.colorScheme.onSurface;
            final l10n = AppLocalizations.of(context);
            final options = <(ThemeMode, String, IconData)>[
              (ThemeMode.system, l10n.appearanceThemeSystem, Icons.brightness_auto_rounded),
              (ThemeMode.light, l10n.appearanceThemeLight, Icons.light_mode_rounded),
              (ThemeMode.dark, l10n.appearanceThemeDark, Icons.dark_mode_rounded),
            ];

            return Container(
              padding: EdgeInsets.all(context.rem(1.125)),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contrast_rounded,
                        color: palette.primaryColor,
                        size: context.rem(AppRem.iconMd),
                      ),
                      SizedBox(width: context.rem(AppRem.ms)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceThemeTitle,
                              style: TextStyle(
                                fontSize: AppType.bodyLg,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              mode == ThemeMode.system
                                  ? l10n.appearanceThemeFollowingDevice
                                  : (mode == ThemeMode.light
                                      ? l10n.appearanceThemeAlwaysLight
                                      : l10n.appearanceThemeAlwaysDark),
                              style: TextStyle(
                                fontSize: AppType.captionPlus,
                                height: 1.35, // ratio: a line height, not a size
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(AppRem.md)),
                  Row(
                    children: [
                      for (final (value, label, icon) in options) ...[
                        Expanded(
                          child: _ThemeModeSegment(
                            label: label,
                            icon: icon,
                            selected: mode == value,
                            color: palette.primaryColor,
                            onTap: () => AppThemeService.setThemeMode(value),
                          ),
                        ),
                        if (value != options.last.$1)
                          SizedBox(width: context.rem(AppRem.sm)),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// In-app text zoom (#69), independent of the system's own accessibility
/// text size -- that already applies underneath this multiplier, on every
/// screen, whether or not this control is touched.
///
/// Range is [AppThemeService.minTextScale, AppThemeService.maxTextScale],
/// not left open-ended: that ceiling is exactly what the high-traffic
/// chrome this reaches (bottom tab bar, wordmark, library pill tabs,
/// details credit cards) was individually verified against. The rest of
/// the app has not had the same pass yet -- see #69 in docs/ROADMAP.md.
class _TextScaleSelector extends StatelessWidget {
  const _TextScaleSelector();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<double>(
          valueListenable: AppThemeService.textScale,
          builder: (context, scale, _) {
            final theme = Theme.of(context);
            final onSurface = theme.colorScheme.onSurface;
            final l10n = AppLocalizations.of(context);

            return Container(
              padding: EdgeInsets.all(context.rem(1.125)),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        color: palette.primaryColor,
                        size: context.rem(AppRem.iconMd),
                      ),
                      SizedBox(width: context.rem(AppRem.ms)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceTextSizeTitle,
                              style: TextStyle(
                                fontSize: AppType.bodyLg,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              scale == 1.0
                                  ? l10n.appearanceTextSizeDefault
                                  : l10n.appearanceTextSizePercent((scale * 100).round()),
                              style: TextStyle(
                                fontSize: AppType.captionPlus,
                                height: 1.35, // ratio: a line height, not a size
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(AppRem.ms)),
                  Row(
                    children: [
                      Text('A', style: TextStyle(fontSize: AppType.small, color: onSurface.withValues(alpha: 0.5))),
                      Expanded(
                        child: Slider(
                          value: scale,
                          min: AppThemeService.minTextScale,
                          max: AppThemeService.maxTextScale,
                          divisions: 9,
                          activeColor: palette.primaryColor,
                          label: '${(scale * 100).round()}%',
                          onChanged: (value) => AppThemeService.setTextScale(value),
                        ),
                      ),
                      Text('A', style: TextStyle(fontSize: AppType.titleSm, color: onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// App-only language override (#68): translates this app's own chrome,
/// independent of the device's system language and of which language
/// scraped/catalog titles show in (that display-vs-canonical title
/// question is its own setting, the switch at the bottom of this card -- see
/// the Localization section of docs/CONVENTIONS.md for why the two titles must
/// never merge).
///
/// Shown in each language's own name, not translated into the currently
/// active one -- someone who can't read the active language still needs to
/// find their own in this list.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  static const _nativeNames = <String, String>{
    'en': 'English',
    'es': 'Español',
    'ar': 'العربية',
    'pt': 'Português',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: AppThemeService.locale,
          builder: (context, activeLocale, _) {
            final theme = Theme.of(context);
            final onSurface = theme.colorScheme.onSurface;
            final l10n = AppLocalizations.of(context);

            return Container(
              padding: EdgeInsets.all(context.rem(1.125)),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate_rounded, color: palette.primaryColor, size: context.rem(AppRem.iconMd)),
                      SizedBox(width: context.rem(AppRem.ms)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceLanguageTitle,
                              style: TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.w800, color: onSurface),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              l10n.appearanceLanguageSubtitle,
                              style: TextStyle(fontSize: AppType.captionPlus, height: 1.35, color: onSurface.withValues(alpha: 0.55)), // ratio: a line height, not a size
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(0.875)),
                  Wrap(
                    spacing: context.rem(AppRem.sm),
                    runSpacing: context.rem(AppRem.sm),
                    children: [
                      _LanguageChip(
                        label: l10n.appearanceLanguageSystem,
                        selected: activeLocale == null,
                        color: palette.primaryColor,
                        onTap: () => AppThemeService.setLocale(null),
                      ),
                      for (final locale in AppThemeService.supportedAppLocales)
                        _LanguageChip(
                          label: _nativeNames[locale.languageCode] ?? locale.languageCode,
                          selected: activeLocale == locale,
                          color: palette.primaryColor,
                          onTap: () => AppThemeService.setLocale(locale),
                        ),
                    ],
                  ),
                  // In this card rather than its own: it is a question about
                  // language, and the answer to the *other* language question
                  // does not decide it. Someone reading the app in Spanish may
                  // still want a show's English title, because that is the one
                  // they will recognize and the one they would search for.
                  Divider(height: context.rem(1.625)),
                  ValueListenableBuilder<bool>(
                    valueListenable: AppThemeService.preferNativeTitles,
                    builder: (context, native, _) => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: native,
                      activeColor: palette.primaryColor,
                      onChanged: AppThemeService.setPreferNativeTitles,
                      title: Text(
                        l10n.appearanceNativeTitlesTitle,
                        style: TextStyle(
                          fontSize: AppType.smallPlus,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                      subtitle: Text(
                        l10n.appearanceNativeTitlesSubtitle,
                        style: TextStyle(
                          fontSize: AppType.caption,
                          height: 1.35, // ratio: a line height, not a size
                          color: onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: FocusFill(
        radius: context.rem(AppRem.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.5625)),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.18) : onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.7) : onSurface.withValues(alpha: 0.10),
                width: 1.2, // px: a hairline, not a layout size
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppType.small,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? onSurface : onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ThemeModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: FocusFill(
        radius: context.rem(AppRem.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.7)
                    : onSurface.withValues(alpha: 0.10),
                width: 1.2, // px: a hairline, not a layout size
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: context.rem(AppRem.icon),
                  color: selected ? color : onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppType.captionPlus,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? onSurface : onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
