import 'package:flutter/material.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/audiobook/audiobook_settings.dart';
import '../../services/theme/custom_background_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/manga/manga_settings.dart';
import '../../services/music/music_settings.dart';
import 'appearance/audiobook_player_studio_page.dart';
import 'appearance/custom_background_settings_page.dart';
import 'appearance/liquid_glass_settings_page.dart';
import 'appearance/live_tv_settings_page.dart';
import 'appearance/manga_settings_page.dart';
import 'appearance/music_player_studio_page.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Appearance & Interface',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Header description
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Fine-tune the visual atmosphere, custom wallpaper background, color palettes, and interface layouts.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),

              // Button 0: Custom Wallpaper & Atmosphere Background
              ValueListenableBuilder<CustomBackgroundData>(
                valueListenable: CustomBackgroundService.notifier,
                builder: (context, customBg, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.wallpaper_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Custom Background & Wallpaper',
                        subtitle: 'Upload custom photos, choose curated dark wallpapers, and blend theme ambient lighting',
                        badgeText: customBg.hasCustomBackground ? 'Custom Active' : 'Default Theme',
                        badgeColor: customBg.hasCustomBackground ? currentPalette.primaryColor : Colors.white38,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CustomBackgroundSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 1: Liquid Glass Setup
              ValueListenableBuilder<bool>(
                valueListenable: GlassSettings.enabled,
                builder: (context, glassEnabled, _) {
                  return ValueListenableBuilder<GlassPreset>(
                    valueListenable: GlassSettings.preset,
                    builder: (context, preset, _) {
                      return _buildSectionButton(
                        icon: Icons.blur_on_rounded,
                        iconColor: const Color(0xFF7C5CFF),
                        title: 'Liquid Glass Setup',
                        subtitle: 'Adjust hover impact, wobble spring physics, lens refraction, and chromatic aberration',
                        badgeText: glassEnabled ? preset.label : 'Disabled',
                        badgeColor: glassEnabled ? const Color(0xFF7C5CFF) : Colors.white38,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiquidGlassSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 2: Live TV & Sports UI
              ValueListenableBuilder<bool>(
                valueListenable: IptvSettings.enableSpotlight,
                builder: (context, spotlightEnabled, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.live_tv_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Live TV & Sports UI',
                        subtitle: 'Broadcast hero spotlight, channel card density, category ordering, and live badge styling',
                        badgeText: spotlightEnabled ? 'Spotlight ON' : 'Compact',
                        badgeColor: currentPalette.primaryColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveTvSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 4: Manga UI & Reader Atmosphere
              ValueListenableBuilder<MangaReadingMode>(
                valueListenable: MangaSettings.defaultReadingMode,
                builder: (context, readingMode, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.menu_book_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Manga UI & Reader Atmosphere',
                        subtitle: 'Ambient moving lighting, card density, reading layout widths, webtoon/horizontal modes, and page deck preview',
                        badgeText: readingMode == MangaReadingMode.webtoon ? 'Webtoon' : 'Horizontal',
                        badgeColor: currentPalette.primaryColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MangaSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 5: Audiobook UI & Player Studio
              ValueListenableBuilder<AudiobookPlayerPreset>(
                valueListenable: AudiobookSettings.selectedPlayerPreset,
                builder: (context, playerPreset, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.headphones_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Audiobook UI & Player Studio',
                        subtitle: 'Hero spotlight, 5 distinct player designs, drag & drop modular studio, waveform canvas scrubber, and custom controls',
                        badgeText: playerPreset.label.split(' ').first,
                        badgeColor: currentPalette.primaryColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AudiobookPlayerStudioPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // Button 6: Music UI & Player Studio
              ValueListenableBuilder<MusicFullscreenPreset>(
                valueListenable: MusicSettings.selectedFullscreenPreset,
                builder: (context, fullPreset, _) {
                  return ValueListenableBuilder<AppThemePalette>(
                    valueListenable: AppThemeService.currentPalette,
                    builder: (context, currentPalette, _) {
                      return _buildSectionButton(
                        icon: Icons.music_note_rounded,
                        iconColor: currentPalette.primaryColor,
                        title: 'Music UI & Player Studio',
                        subtitle: 'Hero spotlight, lossless badges, dual-engine customizer for both mini dock bar and fullscreen turntable/equalizer',
                        badgeText: fullPreset.label.split(' ').first,
                        badgeColor: currentPalette.primaryColor,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MusicPlayerStudioPage(),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 28),

              // Visual Overview Notes
              Text(
                'LIVE CUSTOMIZATION SCOPE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              _buildScopeTile(
                icon: Icons.dock_rounded,
                title: 'Bottom Liquid Dock',
                description: 'Dock items react dynamically with your custom hover magnification, proximity ripples, and wobble springs.',
              ),
              const SizedBox(height: 10),
              _buildScopeTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Video Player & Watch Screens',
                description: 'Overlays, glass sheets, and media controls render with your custom optical blur, refraction index, and border shimmer.',
              ),
              const SizedBox(height: 10),
              _buildScopeTile(
                icon: Icons.home_rounded,
                title: 'Home Page & Discovery',
                description: 'Adapts to your chosen theme accent colors, smart BestSimilar recommendation slider, and chosen poster density.',
              ),
            ],
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.45),
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
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
