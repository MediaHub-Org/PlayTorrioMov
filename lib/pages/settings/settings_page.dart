import '../../widgets/common/focus_fill.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/addon/addon_manager.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';

import 'appearance_settings_page.dart';
import 'debrid_settings_page.dart';
import 'addons_settings_page.dart';
import 'builtin_providers_settings_page.dart';
import 'backup_settings_page.dart';
import 'keyboard_shortcuts_page.dart';
import 'sync_settings_page.dart';
import 'about_settings_page.dart';
import 'video_player_settings_page.dart';
import 'source_filter_settings_page.dart';
import '../../services/scraper/builtin_providers_service.dart';
import '../../services/scraper/stream_scraper.dart';
import '../../services/stream/stream_service.dart';

import '../../widgets/common/animated_ambient_background.dart';
import '../../app_info.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/app_units.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _debrid = DebridService();
  bool _useDebrid = false;
  String _debridProvider = 'None';
  String? _appVersion;
  bool _traktConnected = false;
  bool _simklConnected = false;

  @override
  void initState() {
    super.initState();
    _loadOverviewState();
  }

  Future<void> _loadOverviewState() async {
    final useDebrid = await _debrid.getUseDebridForStreams();
    final provider = await _debrid.getSelectedService();
    final traktAuth = await TraktService.instance.isAuthenticated();
    final simklAuth = await SimklService.instance.isAuthenticated();
    final pkg = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
          appName: AppInfo.name,
          packageName: 'com.mediahub.playtorriomov',
          version: AppInfo.fallbackVersion,
          buildNumber: AppInfo.fallbackBuildNumber,
        ));

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _debridProvider = provider;
        _appVersion = AppInfo.versionLabel(pkg.version);
        _traktConnected = traktAuth;
        _simklConnected = simklAuth;
      });
    }
  }

  Future<void> _navigateTo(Widget page) async {
    await pushPage(context, page);
    // Refresh badges when returning
    _loadOverviewState();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = AppLocalizations.of(context);
    final addonCount = AddonManager.instance.addons.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final syncedCount = (_traktConnected ? 1 : 0) + (_simklConnected ? 1 : 0);

    // Sorted A-Z by title, except About -- which stays last, the way a
    // settings screen's "about this app" entry conventionally does.
    final tiles = <Widget>[
      _SettingsCategoryTile(
        icon: Icons.extension_rounded,
        iconColor: const Color(0xFF10B981),
        title: l10n.settingsCategoryAddons,
        badgeText: '$addonCount',
        badgeColor: const Color(0xFF10B981),
        onTap: () => _navigateTo(const AddonsSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.palette_rounded,
        iconColor: AppThemeService.currentPalette.value.primaryColor,
        title: l10n.settingsCategoryAppearance,
        badgeText: AppThemeService.currentPalette.value.name,
        badgeColor: AppThemeService.currentPalette.value.primaryColor,
        onTap: () => _navigateTo(const AppearanceSettingsPage()),
      ),
      _builtinProvidersTile(),
      _SettingsCategoryTile(
        icon: Icons.cloud_download_rounded,
        iconColor: const Color(0xFF00E5FF),
        title: l10n.settingsCategoryDebrid,
        badgeText: _useDebrid
            ? (_debridProvider != 'None' ? _debridProvider : l10n.settingsBadgeActive)
            : l10n.settingsBadgeDisabled,
        badgeColor: _useDebrid ? const Color(0xFF00E5FF) : AppColors.inkDisabled,
        onTap: () => _navigateTo(const DebridSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.save_alt_rounded,
        iconColor: AppColors.inkMuted,
        title: l10n.settingsCategoryBackup,
        onTap: () => _navigateTo(const BackupSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.link_rounded,
        iconColor: const Color(0xFFED1C24),
        title: l10n.settingsCategoryConnect,
        badgeText: syncedCount == 0
            ? l10n.settingsBadgeOffline
            : l10n.settingsBadgeConnectedCount(syncedCount),
        badgeColor:
            syncedCount == 0 ? AppColors.inkDisabled : const Color(0xFF10B981),
        onTap: () => _navigateTo(const SyncSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.keyboard_rounded,
        iconColor: AppColors.inkMuted,
        title: l10n.settingsCategoryKeyboardShortcuts,
        onTap: () => _navigateTo(const KeyboardShortcutsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.play_circle_outline_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: l10n.settingsCategoryVideoPlayback,
        onTap: () => _navigateTo(const VideoPlayerSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.filter_alt_rounded,
        iconColor: const Color(0xFF38BDF8),
        title: l10n.settingsCategorySources,
        onTap: () => _navigateTo(const SourceFilterSettingsPage()),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bar.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.titleSm),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: SettingsScrollView.separated(
          bottomPadding: 32 + bottomInset,
          itemCount: tiles.length + 1,
          separatorBuilder: (_, __) => SizedBox(height: context.rem(0.625)),
          itemBuilder: (context, i) =>
              i < tiles.length ? tiles[i] : _aboutTile(context),
        ),
      ),
    );
  }

  Widget _builtinProvidersTile() {
    return ValueListenableBuilder<int>(
      valueListenable: BuiltinProvidersService.revision,
      builder: (context, _, __) {
        StreamService.registerBuiltInScrapers();
        final providers = ScraperManager.instance.scrapers;
        final off = BuiltinProvidersService.disabledCountAmong(
          providers.map((p) => p.id),
        );
        final on = providers.length - off;

        return _SettingsCategoryTile(
          icon: Icons.travel_explore_rounded,
          iconColor: const Color(0xFF38BDF8),
          title: AppLocalizations.of(context).settingsCategoryBuiltinProviders,
          badgeText: '$on/${providers.length}',
          badgeColor:
              off == 0 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
          onTap: () => _navigateTo(const BuiltinProvidersSettingsPage()),
        );
      },
    );
  }

  Widget _aboutTile(BuildContext context) {
    return _SettingsCategoryTile(
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.inkMuted,
      title: AppLocalizations.of(context).settingsCategoryAbout(AppInfo.name),
      badgeText: _appVersion,
      badgeColor: AppColors.inkDisabled,
      onTap: () => _navigateTo(const AboutSettingsPage()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Category Tile
// ─────────────────────────────────────────────────────────────────────────────

/// One entry in the Settings grid/list -- icon, title, an optional short
/// status badge, and a chevron. Every category uses this same shape and
/// size now; there used to also be a subtitle sentence under the title and
/// a visually distinct switch-tile variant for the two toggles that lived
/// here -- they moved to the pages whose behavior they actually control, so
/// every remaining entry is just "go to this category", uniformly.
class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Material(
      color: Colors.transparent,
      child: FocusFill(
        radius: context.rem(AppRem.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
          child: Container(
            // A minimum, not a fixed 76. The title and the badge both grow
            // with text scale and the box had nowhere to put them -- 286px
            // past the tile at 3x on the longest title. The page scrolls, so
            // growing here is safe.
            constraints: BoxConstraints(minHeight: context.rem(4.75)),
            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.sm)),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
              border: Border.all(
                color: AppColors.inkAlpha(0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: context.rem(2.75),
                  height: context.rem(2.75),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                  ),
                  child: Icon(icon, color: iconColor, size: context.rem(AppRem.iconMd)),
                ),
                SizedBox(width: context.rem(0.875)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: AppType.bodyMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null) ...[
                  SizedBox(width: context.rem(AppRem.sm)),
                  // Flexible, and the badge itself is the widest thing in the
                  // row after the title: "Built-in Providers" plus "Connected"
                  // asked for 64px more than the tile had at 3x.
                  Flexible(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(0.1562)),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? iconColor).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                      ),
                      child: Text(
                        badgeText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: TvType.scale(AppType.microPlus),
                          fontWeight: FontWeight.w700,
                          color: badgeColor ?? iconColor,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(width: context.rem(AppRem.sm)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: context.rem(0.875),
                  color: AppColors.inkAlpha(0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
