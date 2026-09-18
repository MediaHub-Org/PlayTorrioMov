import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/player/player_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_sub_style_modal.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';

class VideoPlayerSettingsPage extends StatefulWidget {
  const VideoPlayerSettingsPage({super.key});

  @override
  State<VideoPlayerSettingsPage> createState() =>
      _VideoPlayerSettingsPageState();
}

class _VideoPlayerSettingsPageState extends State<VideoPlayerSettingsPage> {
  bool _subtitleEditorExpanded = false;

  String get _platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    return 'Desktop/Mobile';
  }

  /// The platform names above are product names and stay as they are; only
  /// the generic fallback is a phrase a reader would expect translated.
  String _platformLabel(AppLocalizations l10n) =>
      _platformName == 'Desktop/Mobile'
      ? l10n.videoPlatformFallback
      : _platformName;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<int>(
      valueListenable: PlayerSettings.changeNotifier,
      builder: (context, _, __) {
        final palette = AppThemeService.currentPalette.value;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: AppColors.bar.withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              l10n.videoPlayerSettingsTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            actions: [
              IconButton(
                tooltip: l10n.videoResetTooltip,
                icon: const Icon(Icons.restart_alt_rounded, size: 22),
                onPressed: () => _confirmResetToDefaults(palette),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: AnimatedAmbientBackground(
            child: SettingsScrollView(
              maxContentWidth: 820,
              bottomPadding: 32 + bottomInset,
              children: [
                // ── Device & Platform Status Card ──
                _buildDeviceStatusCard(palette),

                const SizedBox(height: 24),

                // ── Section 1: Video Decoders & Hardware Acceleration ──
                _buildSectionHeader(l10n.videoSectionDecoders),
                const SizedBox(height: 12),
                _buildDecodersCard(palette),

                const SizedBox(height: 24),

                // ── Section 2: Engine Performance & Fast Decode (AnymeX) ──
                _buildSectionHeader(l10n.videoSectionOptimizations),
                const SizedBox(height: 12),
                _buildPerformanceOptimizationCard(palette),

                const SizedBox(height: 24),

                // ── Section 3: Buffer Cushion & Anti-Desync Engine ──
                _buildSectionHeader(l10n.videoSectionBuffer),
                const SizedBox(height: 12),
                _buildBufferCushionCard(palette),

                const SizedBox(height: 24),

                // ── Section 4: Network Continuity & Auto-Reconnect ──
                _buildSectionHeader(l10n.videoSectionNetwork),
                const SizedBox(height: 12),
                _buildNetworkReconnectCard(palette),

                const SizedBox(height: 24),

                // ── Section 5: A/V Master Clock & Sync Calibration ──
                _buildSectionHeader(l10n.videoSectionClock),
                const SizedBox(height: 12),
                _buildAudioSyncCard(palette),

                const SizedBox(height: 24),

                // ── Section 6: Subtitle Appearance & libass Styling ──
                _buildSectionHeader(l10n.videoSectionSubtitles),
                const SizedBox(height: 12),
                _buildSubtitleAppearanceCard(palette),

                const SizedBox(height: 32),

                // ── Reset to Defaults ──
                _buildResetButton(palette),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Component Builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.inkAlpha(0.35),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(AppThemePalette palette) {
    final l10n = context.l10n;
    final effectiveDecoders = PlayerSettings.getEffectiveDecoders();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.primaryColor.withValues(alpha: 0.16),
            const Color(0xFF00E5FF).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Platform.isAndroid
                      ? Icons.android_rounded
                      : (Platform.isWindows
                            ? Icons.window_rounded
                            : (Platform.isMacOS || Platform.isIOS
                                  ? Icons.apple_rounded
                                  : Icons.computer_rounded)),
                  color: palette.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A Wrap, not a Row: at 3x the engine title and the
                    // Crash-Free badge together are wider than the card, and
                    // the badge is the part that can move to a second line.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          l10n.videoEngineTitle(_platformLabel(l10n)),
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                color: Color(0xFF10B981),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              // The badge is a fixed-width pill with a
                              // single-line label; at 3x the label alone is
                              // wider than the card, so it scales down
                              // rather than running off the edge.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    l10n.videoCrashFreeBadge,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.videoEngineBody,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkAlpha(0.55),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inkAlpha(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.hub_rounded, size: 14, color: AppColors.inkSubtle),
                const SizedBox(width: 8),
                // Both halves flex: at 3x the label alone is wider than the
                // row, and it is a fixed phrase that cannot wrap usefully.
                Flexible(
                  child: Text(
                    l10n.videoActiveDecoderChain,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    effectiveDecoders.join(' → '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecodersCard(AppThemePalette palette) {
    final l10n = context.l10n;
    final presets = PlayerSettings.getAvailablePresetsForPlatform();
    final currentPreset = PlayerSettings.decoderPreset.value;
    final isForceSoftware = PlayerSettings.forceSoftwareDecoding.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Toggle: Force Software Decoding (Anti-Desync)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isForceSoftware
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : AppColors.inkAlpha(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.memory_rounded,
                color: isForceSoftware
                    ? const Color(0xFFF59E0B)
                    : AppColors.inkSubtle,
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoSoftwareSafeTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoSoftwareSafeBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: isForceSoftware,
            activeColor: const Color(0xFFF59E0B),
            onChanged: (val) => PlayerSettings.setForceSoftwareDecoding(val),
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 14),

          Text(
            l10n.videoDecoderPresetHeader(_platformLabel(l10n).toUpperCase()),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.4),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // Preset Options
          ...presets.map((preset) {
            final isSelected = !isForceSoftware && currentPreset == preset;
            final isCustom = preset == DecoderPreset.custom;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isForceSoftware
                      ? null
                      : () {
                          if (isCustom) {
                            _showCustomDecodersDialog(palette);
                          } else {
                            PlayerSettings.setDecoderPreset(preset);
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.primaryColor.withValues(alpha: 0.12)
                          : AppColors.inkAlpha(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? palette.primaryColor.withValues(alpha: 0.5)
                            : AppColors.inkAlpha(0.06),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? palette.primaryColor
                              : AppColors.inkDisabled,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.title(l10n),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isForceSoftware
                                      ? AppColors.inkDisabled
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preset.description(l10n),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.inkAlpha(0.45),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCustom)
                          IconButton(
                            icon: Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppColors.inkMuted,
                            ),
                            onPressed: isForceSoftware
                                ? null
                                : () => _showCustomDecodersDialog(palette),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPerformanceOptimizationCard(AppThemePalette palette) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Fast Video Decoding
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.flash_on_rounded,
                color: palette.primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoFastDecodeTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoFastDecodeBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.enableFastDecode.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setEnableFastDecode(val),
          ),

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 12),

          // 2. Loop Filter Skipping
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_alt_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.videoLoopFilterTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      l10n.videoLoopFilterBody,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkAlpha(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Flexible + isExpanded: at 3x the dropdown's own intrinsic
              // width is wider than the row leaves it, and a dropdown is the
              // one control here that cannot wrap. Bounded, it ellipsizes
              // the selected item instead of pushing the row off the edge.
              Flexible(
                child: DropdownButton<String>(
                  value: PlayerSettings.skipLoopFilter.value,
                  isExpanded: true,
                  dropdownColor: AppColors.raised,
                  underline: const SizedBox(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'nonkey',
                      child: Text(l10n.videoLoopFilterNonKey),
                    ),
                    DropdownMenuItem(
                      value: 'noref',
                      child: Text(l10n.videoLoopFilterNonRef),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(l10n.videoLoopFilterAll),
                    ),
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(l10n.videoLoopFilterNone),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) PlayerSettings.setSkipLoopFilter(val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 12),

          // 3. Decoding Threads
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.developer_board_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.videoThreadsTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      l10n.videoThreadsBody,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkAlpha(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: DropdownButton<int>(
                  value: PlayerSettings.lavcThreads.value,
                  isExpanded: true,
                  dropdownColor: AppColors.raised,
                  underline: const SizedBox(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.videoThreadsAuto),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(l10n.videoThreadsCount(1)),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text(l10n.videoThreadsCount(2)),
                    ),
                    DropdownMenuItem(
                      value: 4,
                      child: Text(l10n.videoThreadsCount(4)),
                    ),
                    DropdownMenuItem(
                      value: 8,
                      child: Text(l10n.videoThreadsCount(8)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) PlayerSettings.setLavcThreads(val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 12),

          // 4. Disk Stream Cache
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.disc_full_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoDiskCacheTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoDiskCacheBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.enableDiskCache.value,
            activeColor: const Color(0xFF8B5CF6),
            onChanged: (val) => PlayerSettings.setEnableDiskCache(val),
          ),
        ],
      ),
    );
  }

  Widget _buildBufferCushionCard(AppThemePalette palette) {
    final l10n = context.l10n;
    final currentBuffer = PlayerSettings.bufferPreset.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.videoPreloadTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      l10n.videoPreloadBody,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buffer Presets
          ...BufferResiliencePreset.values.map((preset) {
            final isSelected = currentBuffer == preset;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    PlayerSettings.setBufferPreset(preset);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
                          : AppColors.inkAlpha(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                            : AppColors.inkAlpha(0.06),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : AppColors.inkDisabled,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // A Wrap, not a Row: at 3x the preset label and
                              // the RECOMMENDED badge together are wider than
                              // the row, and the badge can move to a second
                              // line.
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    preset.label(l10n),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  if (preset ==
                                          BufferResiliencePreset
                                              .highResilience &&
                                      Platform.isAndroid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        l10n.videoRecommendedBadge,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preset.subtitle(l10n),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.inkAlpha(0.45),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // If Custom Buffer is selected, show sliders
          if (currentBuffer == BufferResiliencePreset.custom) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inkAlpha(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.videoBufferDuration,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      Text(
                        '${PlayerSettings.customBufferMs.value} ms (${(PlayerSettings.customBufferMs.value / 1000).toStringAsFixed(1)}s)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: PlayerSettings.customBufferMs.value.toDouble(),
                    min: 1000,
                    max: 20000,
                    divisions: 38,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (v) {
                      PlayerSettings.setCustomBuffer(
                        v.toInt(),
                        PlayerSettings.customBufferCount.value,
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.videoPacketCount,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      Text(
                        '${PlayerSettings.customBufferCount.value} pkts',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: PlayerSettings.customBufferCount.value.toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (v) {
                      PlayerSettings.setCustomBuffer(
                        PlayerSettings.customBufferMs.value,
                        v.toInt(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkReconnectCard(AppThemePalette palette) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoReconnectTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoReconnectBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.enableNetworkReconnect.value,
            activeColor: const Color(0xFF10B981),
            onChanged: (val) => PlayerSettings.setEnableNetworkReconnect(val),
          ),
          if (PlayerSettings.enableNetworkReconnect.value) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.videoReconnectDelay,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      Text(
                        '${PlayerSettings.reconnectDelayMax.value}s',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: PlayerSettings.reconnectDelayMax.value.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) =>
                        PlayerSettings.setReconnectDelayMax(v.toInt()),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioSyncCard(AppThemePalette palette) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.lock_clock_rounded,
                color: palette.primaryColor,
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoResyncTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoResyncBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.autoResyncOnStall.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setAutoResyncOnStall(val),
          ),

          const SizedBox(height: 8),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoAudioClockTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoAudioClockBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.hardwareAudioClock.value,
            activeColor: AppColors.accent,
            onChanged: (val) => PlayerSettings.setHardwareAudioClock(val),
          ),

          const SizedBox(height: 8),
          Divider(color: AppColors.inkAlpha(0.06), height: 1),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.inkAlpha(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: AppColors.inkMuted,
                size: 20,
              ),
            ),
            title: Text(
              l10n.videoLowLatencyTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              l10n.videoLowLatencyBody,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.inkAlpha(0.5),
                height: 1.3,
              ),
            ),
            value: PlayerSettings.lowLatency.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setLowLatency(val),
          ),

          if (Platform.isAndroid) ...[
            const SizedBox(height: 8),
            Divider(color: AppColors.inkAlpha(0.06), height: 1),
            const SizedBox(height: 8),

            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.layers_rounded,
                  color: palette.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                l10n.videoSurfaceTitle,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              subtitle: Text(
                l10n.videoSurfaceBody,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkAlpha(0.5),
                  height: 1.3,
                ),
              ),
              value: PlayerSettings.enableSurfaceProducer.value,
              activeColor: palette.primaryColor,
              onChanged: (val) => PlayerSettings.setEnableSurfaceProducer(val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitleAppearanceCard(AppThemePalette palette) {
    final l10n = context.l10n;
    final currentPreset = PlayerSettings.subStylePreset.value;
    final fontName = PlayerSettings.subFont.value == 'subfont'
        ? l10n.videoDefaultSubfont
        : PlayerSettings.subFont.value;
    final size = PlayerSettings.subFontSize.value;
    final scale = (PlayerSettings.subScale.value * 100).round();

    // Defaulted in the body rather than the signature: a default
    // parameter value must be a compile-time constant, and the ink
    // color is resolved from the active theme at call time.
    Color parseColor(String hex, {Color? fallback}) {
      var str = hex.replaceAll('#', '').trim();
      if (str.length == 6) str = 'FF$str';
      if (str.length == 8) {
        final val = int.tryParse(str, radix: 16);
        if (val != null) return Color(val);
      }
      return fallback ?? AppColors.ink;
    }

    final textColor = parseColor(PlayerSettings.subColor.value);
    final boxColor = parseColor(
      PlayerSettings.subBackColor.value,
      fallback: Colors.transparent,
    );
    final borderColor = parseColor(
      PlayerSettings.subBorderColor.value,
      fallback: Colors.black,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded, not a Wrap: a Wrap hands its children unbounded width,
          // so the title block sized to its natural width at 3x and ran off
          // the card. Bounded, the title wraps and the button keeps its
          // place on the right.
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.subtitles_rounded,
                        color: palette.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.videoSubtitleCardTitle,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            l10n.videoSubtitlePresetLine(
                              currentPreset.label(l10n),
                              fontName,
                              size,
                              scale,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkAlpha(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(
                  _subtitleEditorExpanded
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                  size: 16,
                ),
                label: Text(
                  _subtitleEditorExpanded
                      ? l10n.videoSubtitleDone
                      : l10n.videoSubtitleCustomize,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => setState(
                  () => _subtitleEditorExpanded = !_subtitleEditorExpanded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mini preview bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inkAlpha(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.videoSubtitlePreview,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PlayerSettings.subFont.value == 'subfont'
                            ? 'Poppins'
                            : PlayerSettings.subFont.value,
                        fontSize: 14,
                        fontWeight: PlayerSettings.subBold.value
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontStyle: PlayerSettings.subItalic.value
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: textColor,
                        shadows: [
                          if (PlayerSettings.subBorderSize.value > 0) ...[
                            Shadow(
                              color: borderColor,
                              offset: const Offset(-1.2, -1.2),
                            ),
                            Shadow(
                              color: borderColor,
                              offset: const Offset(1.2, -1.2),
                            ),
                            Shadow(
                              color: borderColor,
                              offset: const Offset(1.2, 1.2),
                            ),
                            Shadow(
                              color: borderColor,
                              offset: const Offset(-1.2, 1.2),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Full customizer, expanded in place — not a pop-up (#71): it
          // reads as part of this settings page instead of a dialog dropped
          // on top of it. The editor's own dark styling stands in for a
          // video frame, which is also why the mini preview above uses the
          // same fixed canvas color regardless of the app's light/dark theme.
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _subtitleEditorExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SizedBox(
                height: 560,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    // Fixed dark tokens, not theme-adaptive AppColors: the
                    // editor's own text/icons assume the same always-dark
                    // chrome it uses as a floating overlay above video, and
                    // would go unreadable (white-on-white) in light mode
                    // against a theme-adaptive background.
                    color: PlayerTheme.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PlayerTheme.edge),
                  ),
                  child: const SubtitleStyleEditor(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetToDefaults(AppThemePalette palette) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.videoResetConfirmTitle),
        content: Text(
          l10n.videoResetConfirmBody(_platformLabel(l10n)),
          style: TextStyle(color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            child: Text(
              l10n.videoCancel,
              style: TextStyle(color: AppColors.inkSubtle),
            ),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: Text(
              l10n.videoReset,
              style: TextStyle(
                color: palette.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await PlayerSettings.resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.videoResetDone(_platformLabel(l10n))),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildResetButton(AppThemePalette palette) {
    return Center(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: Text(context.l10n.videoResetButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkMuted,
          side: BorderSide(color: AppColors.inkAlpha(0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _confirmResetToDefaults(palette),
      ),
    );
  }

  void _showCustomDecodersDialog(AppThemePalette palette) {
    final l10n = context.l10n;
    final available = PlayerSettings.getAvailableRawDecoders();
    final selected = List<String>.from(
      PlayerSettings.customDecoders.value.isNotEmpty
          ? PlayerSettings.customDecoders.value
          : PlayerSettings.getEffectiveDecoders(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.ink),
                const SizedBox(width: 10),
                Text(
                  l10n.videoCustomChainTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              // Mobile-first: a flat 400 is wider than a 360dp phone once
              // the dialog's own margins are taken out, so this overflowed
              // on exactly the devices the app is mostly used on. Clamped
              // to what is actually available, and still 400 wherever
              // there is room.
              width: (MediaQuery.sizeOf(context).width - 80).clamp(0.0, 400.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.videoCustomChainBody,
                    style: TextStyle(fontSize: 12, color: AppColors.inkSubtle),
                  ),
                  const SizedBox(height: 14),
                  ...available.map((d) {
                    final isChecked = selected.contains(d);
                    final isFfmpeg = d == 'FFmpeg';

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        d + (isFfmpeg ? l10n.videoGuaranteedFallback : ''),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChecked
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isFfmpeg
                              ? const Color(0xFF10B981)
                              : AppColors.ink,
                        ),
                      ),
                      value: isFfmpeg ? true : isChecked,
                      activeColor: palette.primaryColor,
                      onChanged: isFfmpeg
                          ? null
                          : (val) {
                              setDlgState(() {
                                if (val == true) {
                                  selected.insert(0, d);
                                } else {
                                  selected.remove(d);
                                }
                              });
                            },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  l10n.videoCancel,
                  style: TextStyle(color: AppColors.inkSubtle),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  l10n.videoSaveChain,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  if (!selected.contains('FFmpeg')) selected.add('FFmpeg');
                  await PlayerSettings.setCustomDecoders(selected);
                  await PlayerSettings.setDecoderPreset(DecoderPreset.custom);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
