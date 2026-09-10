import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/addon/addon_manager.dart';
import '../../services/app_breakpoints.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';

import 'appearance_settings_page.dart';
import 'debrid_settings_page.dart';
import 'addons_settings_page.dart';
import 'builtin_providers_settings_page.dart';
import 'general_settings_page.dart';
import 'sync_settings_page.dart';
import 'about_settings_page.dart';
import 'video_player_settings_page.dart';
import '../../services/scraper/builtin_providers_service.dart';
import '../../services/scraper/stream_scraper.dart';
import '../../services/stream/stream_service.dart';

import '../../widgets/common/animated_ambient_background.dart';
import '../../app_info.dart';
import '../../utils/navigation/route_transitions.dart';

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
    final addonCount = AddonManager.instance.addons.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tier = AppBreakpoints.of(context);
    final syncedCount = (_traktConnected ? 1 : 0) + (_simklConnected ? 1 : 0);

    // Sorted A-Z by title, except About -- which stays last, the way a
    // settings screen's "about this app" entry conventionally does.
    final tiles = <Widget>[
      _SettingsCategoryTile(
        icon: Icons.extension_rounded,
        iconColor: const Color(0xFF10B981),
        title: 'Addons',
        badgeText: '$addonCount',
        badgeColor: const Color(0xFF10B981),
        onTap: () => _navigateTo(const AddonsSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.palette_rounded,
        iconColor: AppThemeService.currentPalette.value.primaryColor,
        title: 'Appearance & Interface',
        badgeText: AppThemeService.currentPalette.value.name,
        badgeColor: AppThemeService.currentPalette.value.primaryColor,
        onTap: () => _navigateTo(const AppearanceSettingsPage()),
      ),
      _builtinProvidersTile(),
      _SettingsCategoryTile(
        icon: Icons.cloud_download_rounded,
        iconColor: const Color(0xFF00E5FF),
        title: 'Debrid & Cloud Streaming',
        badgeText: _useDebrid
            ? (_debridProvider != 'None' ? _debridProvider : 'Active')
            : 'Disabled',
        badgeColor: _useDebrid ? const Color(0xFF00E5FF) : Colors.white38,
        onTap: () => _navigateTo(const DebridSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.tune_rounded,
        iconColor: Colors.white70,
        title: 'General & Data',
        onTap: () => _navigateTo(const GeneralSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.sync_rounded,
        iconColor: const Color(0xFFED1C24),
        title: 'Sync',
        badgeText: syncedCount == 0 ? 'Offline' : '$syncedCount/2 Connected',
        badgeColor:
            syncedCount == 0 ? Colors.white38 : const Color(0xFF10B981),
        onTap: () => _navigateTo(const SyncSettingsPage()),
      ),
      _SettingsCategoryTile(
        icon: Icons.play_circle_outline_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: 'Video Playback',
        onTap: () => _navigateTo(const VideoPlayerSettingsPage()),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017).withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: tier == ScreenTier.desktop ? 1100 : 800,
            ),
            child: tier == ScreenTier.mobile
                ? ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + bottomInset),
                    itemCount: tiles.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => i < tiles.length
                        ? tiles[i]
                        : _aboutTile(),
                  )
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 32 + bottomInset),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: tier == ScreenTier.desktop ? 3 : 2,
                      mainAxisExtent: 76,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: tiles.length + 1,
                    itemBuilder: (context, i) =>
                        i < tiles.length ? tiles[i] : _aboutTile(),
                  ),
          ),
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
          title: 'Built-in Providers',
          badgeText: '$on/${providers.length}',
          badgeColor:
              off == 0 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
          onTap: () => _navigateTo(const BuiltinProvidersSettingsPage()),
        );
      },
    );
  }

  Widget _aboutTile() {
    return _SettingsCategoryTile(
      icon: Icons.info_outline_rounded,
      iconColor: Colors.white70,
      title: 'About ${AppInfo.name}',
      badgeText: _appVersion,
      badgeColor: Colors.white38,
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
/// here (P2P, Discord) -- both toggles moved to the page whose behavior
/// they actually control (Built-in Providers, General & Data), so every
/// remaining entry is just "go to this category", uniformly.
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconColor).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? iconColor,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
