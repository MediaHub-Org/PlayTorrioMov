import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/iptv_settings.dart';
import 'appearance/live_tv_settings_page.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../l10n/app_localizations.dart';

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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.appearanceTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // Header description
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              l10n.appearanceSubtitle,
              style: TextStyle(
                fontSize: 13.5,
                color: onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),

          // Theme mode. First on the page because it is the broadest
          // visual choice here -- everything below it is a detail of
          // whichever mode you land in.
          const _ThemeModeSelector(),

          const SizedBox(height: 20),

          const _TextScaleSelector(),

          const SizedBox(height: 20),

          const _LanguageSelector(),

          const SizedBox(height: 20),

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: onSurface.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.45),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: onSurface.withValues(alpha: 0.3),
              ),
            ],
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
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
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceThemeTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode == ThemeMode.system
                                  ? l10n.appearanceThemeFollowingDevice
                                  : (mode == ThemeMode.light
                                      ? l10n.appearanceThemeAlwaysLight
                                      : l10n.appearanceThemeAlwaysDark),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          const SizedBox(width: 8),
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
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
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceTextSizeTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scale == 1.0
                                  ? l10n.appearanceTextSizeDefault
                                  : l10n.appearanceTextSizePercent((scale * 100).round()),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('A', style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.5))),
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
                      Text('A', style: TextStyle(fontSize: 20, color: onSurface.withValues(alpha: 0.5))),
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
/// question is a separate, larger decision -- see docs/ROADMAP.md's
/// Translation entry).
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate_rounded, color: palette.primaryColor, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appearanceLanguageTitle,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.appearanceLanguageSubtitle,
                              style: TextStyle(fontSize: 12.5, height: 1.35, color: onSurface.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.7) : onSurface.withValues(alpha: 0.10),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? onSurface : onSurface.withValues(alpha: 0.6),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : onSurface.withValues(alpha: 0.10),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? color : onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? onSurface : onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
