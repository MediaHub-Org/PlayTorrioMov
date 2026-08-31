import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/player/player_settings.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/player/player_sub_style_modal.dart';

class VideoPlayerSettingsPage extends StatefulWidget {
  const VideoPlayerSettingsPage({super.key});

  @override
  State<VideoPlayerSettingsPage> createState() => _VideoPlayerSettingsPageState();
}

class _VideoPlayerSettingsPageState extends State<VideoPlayerSettingsPage> {
  String get _platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isLinux) return 'Linux';
    return 'Desktop/Mobile';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<int>(
      valueListenable: PlayerSettings.changeNotifier,
      builder: (context, _, __) {
        final palette = AppThemeService.currentPalette.value;

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
              'Video Player & Engine Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            actions: [
              IconButton(
                tooltip: 'Reset to Defaults',
                icon: const Icon(Icons.restart_alt_rounded, size: 22),
                onPressed: () => _confirmResetToDefaults(palette),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: AnimatedAmbientBackground(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + bottomInset),
                  children: [
                    // ── Device & Platform Status Card ──
                    _buildDeviceStatusCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 1: Video Decoders & Hardware Acceleration ──
                    _buildSectionHeader('VIDEO DECODERS & HARDWARE ACCELERATION'),
                    const SizedBox(height: 12),
                    _buildDecodersCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 2: Engine Performance & Fast Decode (AnymeX) ──
                    _buildSectionHeader('ENGINE DECODE OPTIMIZATIONS & CACHING'),
                    const SizedBox(height: 12),
                    _buildPerformanceOptimizationCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 3: Buffer Cushion & Anti-Desync Engine ──
                    _buildSectionHeader('BUFFER CUSHION & DEMUXER RESILIENCE'),
                    const SizedBox(height: 12),
                    _buildBufferCushionCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 4: Network Continuity & Auto-Reconnect ──
                    _buildSectionHeader('STREAM CONTINUITY & NETWORK RECONNECT'),
                    const SizedBox(height: 12),
                    _buildNetworkReconnectCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 5: A/V Master Clock & Sync Calibration ──
                    _buildSectionHeader('A/V MASTER CLOCK & SYNC CALIBRATION'),
                    const SizedBox(height: 12),
                    _buildAudioSyncCard(palette),

                    const SizedBox(height: 24),

                    // ── Section 6: Subtitle Appearance & libass Styling ──
                    _buildSectionHeader('SUBTITLE APPEARANCE & LIBASS STYLING'),
                    const SizedBox(height: 12),
                    _buildSubtitleAppearanceCard(palette),

                    const SizedBox(height: 32),

                    // ── Reset to Defaults ──
                    _buildResetButton(palette),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
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
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(AppThemePalette palette) {
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
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.25),
        ),
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
                          : (Platform.isMacOS || Platform.isIOS ? Icons.apple_rounded : Icons.computer_rounded)),
                  color: palette.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$_platformName Video Engine',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Crash-Free Fallback',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'libmpv hardware accelerated pipeline with auto software failover.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.55),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded, size: 14, color: Colors.white54),
                const SizedBox(width: 8),
                const Text(
                  'Active Decoder Chain: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
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
    final presets = PlayerSettings.getAvailablePresetsForPlatform();
    final currentPreset = PlayerSettings.decoderPreset.value;
    final isForceSoftware = PlayerSettings.forceSoftwareDecoding.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.memory_rounded,
                color: isForceSoftware ? const Color(0xFFF59E0B) : Colors.white54,
                size: 20,
              ),
            ),
            title: const Text(
              'Software Safe Mode (CPU Decode)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Bypasses GPU hardware decoders. Recommended on Android if video & audio lose sync when buffering stalls.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
            ),
            value: isForceSoftware,
            activeColor: const Color(0xFFF59E0B),
            onChanged: (val) => PlayerSettings.setForceSoftwareDecoding(val),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),

          Text(
            'DECODER PRESET (${_platformName.toUpperCase()})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
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
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? palette.primaryColor.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.06),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? palette.primaryColor : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isForceSoftware ? Colors.white38 : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preset.description,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCustom)
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.white70),
                            onPressed: isForceSoftware ? null : () => _showCustomDecodersDialog(palette),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              child: Icon(Icons.flash_on_rounded, color: palette.primaryColor, size: 20),
            ),
            title: const Text(
              'Fast Video Decoding (vd-lavc-fast)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Enables high-throughput FFmpeg fast decode paths to minimize stutter on high-bitrate streams.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
            ),
            value: PlayerSettings.enableFastDecode.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setEnableFastDecode(val),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
                child: const Icon(Icons.filter_alt_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deblocking Loop Filter',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Skip deblocking filter on non-critical frames to reduce CPU/GPU load.',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              DropdownButton<String>(
                value: PlayerSettings.skipLoopFilter.value,
                dropdownColor: const Color(0xFF1E2330),
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'nonkey', child: Text('Non-Key (Fast)')),
                  DropdownMenuItem(value: 'noref', child: Text('Non-Ref')),
                  DropdownMenuItem(value: 'all', child: Text('Skip All')),
                  DropdownMenuItem(value: 'none', child: Text('None (Quality)')),
                ],
                onChanged: (val) {
                  if (val != null) PlayerSettings.setSkipLoopFilter(val);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
                child: const Icon(Icons.developer_board_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Decoder Worker Threads',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Multi-threaded FFmpeg decode workers (Default: 4).',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              DropdownButton<int>(
                value: PlayerSettings.lavcThreads.value,
                dropdownColor: const Color(0xFF1E2330),
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Auto')),
                  DropdownMenuItem(value: 1, child: Text('1 Thread')),
                  DropdownMenuItem(value: 2, child: Text('2 Threads')),
                  DropdownMenuItem(value: 4, child: Text('4 Threads')),
                  DropdownMenuItem(value: 8, child: Text('8 Threads')),
                ],
                onChanged: (val) {
                  if (val != null) PlayerSettings.setLavcThreads(val);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
              child: const Icon(Icons.disc_full_rounded, color: Color(0xFF8B5CF6), size: 20),
            ),
            title: const Text(
              'Disk Stream Buffer Cache',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Smoothly caches media chunks into the OS temporary directory to eliminate RAM pressure.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
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
    final currentBuffer = PlayerSettings.bufferPreset.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                child: const Icon(Icons.speed_rounded, color: Color(0xFF00E5FF), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preload Buffer Cushion',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Higher cushions buffer ahead to prevent playback hiccups and A/V desync.',
                      style: TextStyle(fontSize: 11.5, color: Colors.white54),
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
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    preset.label,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (preset == BufferResiliencePreset.highResilience && Platform.isAndroid) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'RECOMMENDED',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                preset.subtitle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.45),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Buffer Duration Cushion',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      Text(
                        '${PlayerSettings.customBufferMs.value} ms (${(PlayerSettings.customBufferMs.value / 1000).toStringAsFixed(1)}s)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF00E5FF)),
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
                      PlayerSettings.setCustomBuffer(v.toInt(), PlayerSettings.customBufferCount.value);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Packet Count Buffer',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      Text(
                        '${PlayerSettings.customBufferCount.value} pkts',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF00E5FF)),
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
                      PlayerSettings.setCustomBuffer(PlayerSettings.customBufferMs.value, v.toInt());
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              child: const Icon(Icons.sync_problem_rounded, color: Color(0xFF10B981), size: 20),
            ),
            title: const Text(
              'Network Auto-Reconnect',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Seamlessly reconnects HLS / HTTP video demuxers without tearing down playback or corrupting timestamps on brief connection drops. '
              'Always on for Live TV. Enabling it for movies and episodes can disable seeking on some HLS streams.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
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
                      const Text(
                        'Max Reconnect Delay Timeout',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      Text(
                        '${PlayerSettings.reconnectDelayMax.value}s',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  Slider(
                    value: PlayerSettings.reconnectDelayMax.value.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) => PlayerSettings.setReconnectDelayMax(v.toInt()),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              child: Icon(Icons.lock_clock_rounded, color: palette.primaryColor, size: 20),
            ),
            title: const Text(
              'Auto-Resync On Buffer Recovery',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Recalibrates the video clock with the master audio timeline immediately after a network stall recovers.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
            ),
            value: PlayerSettings.autoResyncOnStall.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setAutoResyncOnStall(val),
          ),

          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF7C5CFF), size: 20),
            ),
            title: const Text(
              'Master Audio Clock Sync',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Uses hardware audio clock as master timeline for uncompromised audio fidelity and tight frame locking.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
            ),
            value: PlayerSettings.hardwareAudioClock.value,
            activeColor: const Color(0xFF7C5CFF),
            onChanged: (val) => PlayerSettings.setHardwareAudioClock(val),
          ),

          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white70, size: 20),
            ),
            title: const Text(
              'Low Latency Mode',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            subtitle: Text(
              'Minimizes buffering queue for live streams (disables deep preloading cushion).',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.3),
            ),
            value: PlayerSettings.lowLatency.value,
            activeColor: palette.primaryColor,
            onChanged: (val) => PlayerSettings.setLowLatency(val),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleAppearanceCard(AppThemePalette palette) {
    final currentPreset = PlayerSettings.subStylePreset.value;
    final fontName = PlayerSettings.subFont.value == 'subfont' ? 'Default (PlayTorrio Subfont)' : PlayerSettings.subFont.value;
    final size = PlayerSettings.subFontSize.value;
    final scale = (PlayerSettings.subScale.value * 100).round();

    Color parseColor(String hex, {Color fallback = Colors.white}) {
      var str = hex.replaceAll('#', '').trim();
      if (str.length == 6) str = 'FF$str';
      if (str.length == 8) {
        final val = int.tryParse(str, radix: 16);
        if (val != null) return Color(val);
      }
      return fallback;
    }

    final textColor = parseColor(PlayerSettings.subColor.value);
    final boxColor = parseColor(PlayerSettings.subBackColor.value, fallback: Colors.transparent);
    final borderColor = parseColor(PlayerSettings.subBorderColor.value, fallback: Colors.black);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.subtitles_rounded, color: palette.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subtitle Styling & Engine Customization',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Preset: ${currentPreset.label} • $fontName (${size}pt / $scale%)',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Customize'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openSubtitleCustomizer,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mini preview bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PlayTorrio • Sample Subtitle Preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PlayerSettings.subFont.value == 'subfont' ? 'Poppins' : PlayerSettings.subFont.value,
                        fontSize: 14,
                        fontWeight: PlayerSettings.subBold.value ? FontWeight.bold : FontWeight.w600,
                        fontStyle: PlayerSettings.subItalic.value ? FontStyle.italic : FontStyle.normal,
                        color: textColor,
                        shadows: [
                          if (PlayerSettings.subBorderSize.value > 0) ...[
                            Shadow(color: borderColor, offset: const Offset(-1.2, -1.2)),
                            Shadow(color: borderColor, offset: const Offset(1.2, -1.2)),
                            Shadow(color: borderColor, offset: const Offset(1.2, 1.2)),
                            Shadow(color: borderColor, offset: const Offset(-1.2, 1.2)),
                          ],
                        ],
                      ),
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

  void _openSubtitleCustomizer() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => PlayerSubStyleModal(
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _confirmResetToDefaults(AppThemePalette palette) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Player Settings?'),
        content: Text(
          'This will restore all video decoding, fast-decode optimizations, caching, buffering, and sync settings to recommended defaults for $_platformName.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: Text('Reset', style: TextStyle(color: palette.primaryColor, fontWeight: FontWeight.bold)),
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
            content: Text('Video settings reset to $_platformName defaults.'),
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
        label: const Text('Reset Video Engine to Platform Defaults'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _confirmResetToDefaults(palette),
      ),
    );
  }

  void _showCustomDecodersDialog(AppThemePalette palette) {
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
            backgroundColor: const Color(0xFF13151F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Custom Decoder Chain', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select prioritized decoders. FFmpeg (software) will always be appended as final crash-free safety fallback.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 14),
                  ...available.map((d) {
                    final isChecked = selected.contains(d);
                    final isFfmpeg = d == 'FFmpeg';

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        d + (isFfmpeg ? ' (Guaranteed Fallback)' : ''),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: isFfmpeg ? const Color(0xFF10B981) : Colors.white,
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
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Chain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
