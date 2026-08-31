import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available decoder preset types tailored for each platform.
enum DecoderPreset {
  hardwareAuto('Hardware Accelerated (Auto)', 'Fastest performance, GPU hardware decoded with automatic software fallback.'),
  hardwareSafe('Hardware Safe Copy', 'GPU decoded with surface copy to fix frame tearing/glitches on certain chipsets.'),
  softwareSafe('Software Safe (Perfect A/V Sync)', 'CPU decoded via FFmpeg/dav1d. Recommended on slow internet & Android to eliminate buffer desync.'),
  nvidiaCuda('NVIDIA CUDA / NVDEC', 'Dedicated NVIDIA hardware acceleration for Windows & Linux.'),
  custom('Custom Decoder Chain', 'User-defined prioritized decoder fallback list.');

  final String title;
  final String description;
  const DecoderPreset(this.title, this.description);
}

/// Buffer resilience cushion preset for network streams.
enum BufferResiliencePreset {
  minimal('Minimal (50MB / 5s)', 'Fast start, for high-speed local streams.', 1000, 50, 52428800, 5),
  standard('Standard (150MB / 15s)', 'Balanced buffering for general streaming.', 3000, 150, 157286400, 15),
  highResilience('High Resilience (300MB / 30s)', 'Recommended for Android & Wi-Fi. Pre-buffers cushion to prevent rebuffer stalls & A/V drift.', 6000, 300, 314572800, 30),
  maximum('Maximum (600MB / 60s)', 'Extra large buffer for torrent streaming & congested connections.', 12000, 600, 629145600, 60),
  custom('Custom Buffer', 'Custom duration and byte capacity.', 6000, 300, 314572800, 30);

  final String label;
  final String subtitle;
  final int durationMs;
  final int packetCount;
  final int maxBytes;
  final int cacheSecs;
  const BufferResiliencePreset(this.label, this.subtitle, this.durationMs, this.packetCount, this.maxBytes, this.cacheSecs);
}

/// Subtitle styling preset for rapid 1-tap appearance selection.
enum SubtitleStylePreset {
  classicWhite('Classic White', 'Crisp white text with black outline', '#FFFFFFFF', '#00000000', '#FF000000', 2.0, 0.0, '#00000000', false, false),
  cinemaYellow('Cinema Yellow', 'Warm yellow text with subtle shadow and border', '#FFFFEB3B', '#00000000', '#FF000000', 2.5, 1.5, '#80000000', false, false),
  streamingBox('Streaming Box', 'White text inside a 50% translucent black box', '#FFFFFFFF', '#80000000', '#00000000', 0.0, 0.0, '#00000000', false, false),
  highContrast('High Contrast', 'Bold yellow text with solid opaque black box', '#FFFFD600', '#FF000000', '#FF000000', 0.0, 0.0, '#00000000', true, false),
  animeClean('Anime Clean', 'Bold white text with deep outline & shadow', '#FFFFFFFF', '#00000000', '#FF000000', 3.5, 2.0, '#BF000000', true, false),
  cyberpunkCyan('Cyberpunk Cyan', 'Vibrant cyan text with dark border', '#00E5FF', '#00000000', '#FF0D111A', 2.5, 1.0, '#6600E5FF', false, false),
  nightModeSoft('Night Mode Warm', 'Soft cream text with 40% translucent background', '#FFF8E1', '#66000000', '#00000000', 0.0, 0.0, '#00000000', false, false),
  custom('Custom', 'User configured custom subtitle styles', '#FFFFFFFF', '#00000000', '#FF000000', 2.0, 0.0, '#00000000', false, false);

  final String label;
  final String description;
  final String textColor;
  final String backColor;
  final String borderColor;
  final double borderSize;
  final double shadowOffset;
  final String shadowColor;
  final bool bold;
  final bool italic;

  const SubtitleStylePreset(
    this.label,
    this.description,
    this.textColor,
    this.backColor,
    this.borderColor,
    this.borderSize,
    this.shadowOffset,
    this.shadowColor,
    this.bold,
    this.italic,
  );
}

/// Central service managing video engine properties, decoder fallback chains,
/// buffer resilience, anti-desync options, and libass subtitle customization using media_kit / libmpv.
abstract final class PlayerSettings {
  static const _keyDecoderPreset = 'player_decoder_preset';
  static const _keyForceSoftwareDecoding = 'player_force_software_decoding';
  static const _keyCustomDecoders = 'player_custom_decoders';
  static const _keyBufferPreset = 'player_buffer_preset';
  static const _keyCustomBufferMs = 'player_custom_buffer_ms';
  static const _keyCustomBufferCount = 'player_custom_buffer_count';
  static const _keyEnableFastDecode = 'player_enable_fast_decode';
  static const _keySkipLoopFilter = 'player_skip_loop_filter';
  static const _keyLavcThreads = 'player_lavc_threads';
  static const _keyEnableDiskCache = 'player_enable_disk_cache';
  static const _keyEnableNetworkReconnect = 'player_enable_network_reconnect';
  static const _keyReconnectDelayMax = 'player_reconnect_delay_max';
  static const _keyAutoResyncOnStall = 'player_auto_resync_on_stall';
  static const _keyLowLatency = 'player_low_latency';
  static const _keyHardwareAudioClock = 'player_hardware_audio_clock';
  static const _keyAudioDelayDefault = 'player_audio_delay_default';
  static const _keyAutoNextEnabled = 'player_auto_next_enabled';

  // Subtitle Customization Keys
  static const _keySubStylePreset = 'player_sub_style_preset';
  static const _keySubFont = 'player_sub_font';
  static const _keySubFontSize = 'player_sub_font_size';
  static const _keySubScale = 'player_sub_scale';
  static const _keySubColor = 'player_sub_color';
  static const _keySubBackColor = 'player_sub_back_color';
  static const _keySubBorderColor = 'player_sub_border_color';
  static const _keySubBorderSize = 'player_sub_border_size';
  static const _keySubShadowOffset = 'player_sub_shadow_offset';
  static const _keySubShadowColor = 'player_sub_shadow_color';
  static const _keySubBold = 'player_sub_bold';
  static const _keySubItalic = 'player_sub_italic';
  static const _keySubMarginY = 'player_sub_margin_y';
  static const _keySubPos = 'player_sub_pos';
  static const _keySubAlignX = 'player_sub_align_x';
  static const _keySubAssOverride = 'player_sub_ass_override';

  // ValueNotifiers for reactive UI binding
  static final ValueNotifier<DecoderPreset> decoderPreset =
      ValueNotifier<DecoderPreset>(DecoderPreset.hardwareAuto);
  static final ValueNotifier<bool> forceSoftwareDecoding =
      ValueNotifier<bool>(false);
  static final ValueNotifier<List<String>> customDecoders =
      ValueNotifier<List<String>>(<String>[]);
  static final ValueNotifier<BufferResiliencePreset> bufferPreset =
      ValueNotifier<BufferResiliencePreset>(
        // On Android default to high resilience to combat Wi-Fi drops & sync loss
        Platform.isAndroid ? BufferResiliencePreset.highResilience : BufferResiliencePreset.standard,
      );
  static final ValueNotifier<int> customBufferMs = ValueNotifier<int>(6000);
  static final ValueNotifier<int> customBufferCount = ValueNotifier<int>(300);
  static final ValueNotifier<bool> enableFastDecode = ValueNotifier<bool>(true);
  static final ValueNotifier<String> skipLoopFilter = ValueNotifier<String>('nonkey');
  static final ValueNotifier<int> lavcThreads = ValueNotifier<int>(4);
  static final ValueNotifier<bool> enableDiskCache = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> enableNetworkReconnect = ValueNotifier<bool>(false);
  static final ValueNotifier<int> reconnectDelayMax = ValueNotifier<int>(5);
  static final ValueNotifier<bool> autoResyncOnStall = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> lowLatency = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> hardwareAudioClock = ValueNotifier<bool>(true);
  static final ValueNotifier<double> audioDelayDefault = ValueNotifier<double>(0.0);
  static final ValueNotifier<bool> autoNextEnabled = ValueNotifier<bool>(true);

  // Subtitle Customization ValueNotifiers
  static final ValueNotifier<SubtitleStylePreset> subStylePreset =
      ValueNotifier<SubtitleStylePreset>(SubtitleStylePreset.classicWhite);
  static final ValueNotifier<String> subFont = ValueNotifier<String>('subfont');
  static final ValueNotifier<int> subFontSize = ValueNotifier<int>(32);
  static final ValueNotifier<double> subScale = ValueNotifier<double>(1.0);
  static final ValueNotifier<String> subColor = ValueNotifier<String>('#FFFFFFFF');
  static final ValueNotifier<String> subBackColor = ValueNotifier<String>('#00000000');
  static final ValueNotifier<String> subBorderColor = ValueNotifier<String>('#FF000000');
  static final ValueNotifier<double> subBorderSize = ValueNotifier<double>(2.0);
  static final ValueNotifier<double> subShadowOffset = ValueNotifier<double>(0.0);
  static final ValueNotifier<String> subShadowColor = ValueNotifier<String>('#80000000');
  static final ValueNotifier<bool> subBold = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> subItalic = ValueNotifier<bool>(false);
  static final ValueNotifier<double> subMarginY = ValueNotifier<double>(30.0);
  static final ValueNotifier<double> subPos = ValueNotifier<double>(100.0);
  static final ValueNotifier<String> subAlignX = ValueNotifier<String>('center');
  static final ValueNotifier<String> subAssOverride = ValueNotifier<String>('no');
  static const String _keyUseLibass = 'player_use_libass';
  static final ValueNotifier<bool> useLibass = ValueNotifier<bool>(false);
  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  // Extracted font paths for libass font fallback
  static String? _extractedFontDir;
  static String? _extractedFontPath;
  static String? get extractedFontDir => _extractedFontDir;
  static String? get extractedFontPath => _extractedFontPath;

  /// Popular available system fonts across platforms
  static const List<String> popularFonts = [
    'subfont',
    'Poppins',
    'Roboto',
    'Arial',
    'Trebuchet MS',
    'Open Sans',
    'Montserrat',
    'Comic Sans MS',
    'Courier New',
    'Georgia',
    'Times New Roman',
    'Impact',
    'Verdana',
  ];

  /// Returns available decoder presets for the current OS platform.
  static List<DecoderPreset> getAvailablePresetsForPlatform() {
    if (Platform.isAndroid) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else if (Platform.isWindows) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.nvidiaCuda,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else if (Platform.isMacOS || Platform.isIOS) {
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.hardwareSafe,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    } else {
      // Linux & other
      return [
        DecoderPreset.hardwareAuto,
        DecoderPreset.nvidiaCuda,
        DecoderPreset.softwareSafe,
        DecoderPreset.custom,
      ];
    }
  }

  /// Returns all available raw decoders suitable for custom decoder chain building on current platform.
  static List<String> getAvailableRawDecoders() {
    if (Platform.isAndroid) {
      // 'mediacodec' (direct-to-Surface) is deliberately absent: it renders
      // black under enableAndroidSurfaceProducer: false. See
      // _getDefaultDecodersForPreset.
      return ['mediacodec-copy', 'auto-safe', 'auto-copy', 'no'];
    } else if (Platform.isWindows) {
      return ['d3d11va', 'd3d11va-copy', 'nvdec', 'nvdec-copy', 'auto-safe', 'auto-copy', 'no'];
    } else if (Platform.isMacOS || Platform.isIOS) {
      return ['videotoolbox', 'videotoolbox-copy', 'auto-safe', 'auto-copy', 'no'];
    } else {
      return ['vaapi', 'vaapi-copy', 'nvdec', 'nvdec-copy', 'auto-safe', 'auto-copy', 'no'];
    }
  }

  /// Initializes preferences from disk and extracts the bundled font for libass.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final presetStr = prefs.getString(_keyDecoderPreset);
    if (presetStr != null) {
      decoderPreset.value = DecoderPreset.values.firstWhere(
        (p) => p.name == presetStr,
        orElse: () => DecoderPreset.hardwareAuto,
      );
    } else {
      decoderPreset.value = DecoderPreset.hardwareAuto;
    }

    forceSoftwareDecoding.value = prefs.getBool(_keyForceSoftwareDecoding) ?? false;

    final savedCustom = prefs.getStringList(_keyCustomDecoders);
    if (savedCustom != null && savedCustom.isNotEmpty) {
      customDecoders.value = _sanitizeDecoders(savedCustom);
    } else {
      customDecoders.value = _getDefaultDecodersForPreset(decoderPreset.value);
    }

    final bufStr = prefs.getString(_keyBufferPreset);
    if (bufStr != null) {
      bufferPreset.value = BufferResiliencePreset.values.firstWhere(
        (b) => b.name == bufStr,
        orElse: () => Platform.isAndroid
            ? BufferResiliencePreset.highResilience
            : BufferResiliencePreset.standard,
      );
    }

    customBufferMs.value = prefs.getInt(_keyCustomBufferMs) ?? 6000;
    customBufferCount.value = prefs.getInt(_keyCustomBufferCount) ?? 300;
    enableFastDecode.value = prefs.getBool(_keyEnableFastDecode) ?? true;
    skipLoopFilter.value = prefs.getString(_keySkipLoopFilter) ?? 'nonkey';
    lavcThreads.value = prefs.getInt(_keyLavcThreads) ?? 4;
    enableDiskCache.value = prefs.getBool(_keyEnableDiskCache) ?? true;
    enableNetworkReconnect.value = prefs.getBool(_keyEnableNetworkReconnect) ?? false;
    reconnectDelayMax.value = prefs.getInt(_keyReconnectDelayMax) ?? 5;
    autoResyncOnStall.value = prefs.getBool(_keyAutoResyncOnStall) ?? true;
    lowLatency.value = prefs.getBool(_keyLowLatency) ?? false;
    hardwareAudioClock.value = prefs.getBool(_keyHardwareAudioClock) ?? true;
    audioDelayDefault.value = prefs.getDouble(_keyAudioDelayDefault) ?? 0.0;
    autoNextEnabled.value = prefs.getBool(_keyAutoNextEnabled) ?? true;

    // Load Subtitle Customization Preferences
    final subPresetStr = prefs.getString(_keySubStylePreset);
    if (subPresetStr != null) {
      subStylePreset.value = SubtitleStylePreset.values.firstWhere(
        (p) => p.name == subPresetStr,
        orElse: () => SubtitleStylePreset.classicWhite,
      );
    }
    subFont.value = prefs.getString(_keySubFont) ?? 'subfont';
    subFontSize.value = prefs.getInt(_keySubFontSize) ?? 32;
    subScale.value = prefs.getDouble(_keySubScale) ?? 1.0;
    subColor.value = prefs.getString(_keySubColor) ?? '#FFFFFFFF';
    subBackColor.value = prefs.getString(_keySubBackColor) ?? '#00000000';
    subBorderColor.value = prefs.getString(_keySubBorderColor) ?? '#FF000000';
    subBorderSize.value = prefs.getDouble(_keySubBorderSize) ?? 2.0;
    subShadowOffset.value = prefs.getDouble(_keySubShadowOffset) ?? 0.0;
    subShadowColor.value = prefs.getString(_keySubShadowColor) ?? '#80000000';
    subBold.value = prefs.getBool(_keySubBold) ?? false;
    subItalic.value = prefs.getBool(_keySubItalic) ?? false;
    subMarginY.value = prefs.getDouble(_keySubMarginY) ?? 30.0;
    subPos.value = prefs.getDouble(_keySubPos) ?? 100.0;
    subAlignX.value = prefs.getString(_keySubAlignX) ?? 'center';
    subAssOverride.value = prefs.getString(_keySubAssOverride) ?? 'no';
    useLibass.value = prefs.getBool(_keyUseLibass) ?? false;

    // Extract bundled font for libass fallback
    await _extractLibassFontFallback();
  }

  /// Extracts assets/fonts/Poppins-Medium.ttf or subfont.ttf to persistent disk storage for libass font provider
  static Future<void> _extractLibassFontFallback() async {
    try {
      Directory? targetDir;
      try {
        targetDir = await getApplicationSupportDirectory();
      } catch (_) {
        targetDir = await getTemporaryDirectory();
      }

      final fontsDir = Directory(p.join(targetDir.path, 'fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      final fontFile = File(p.join(fontsDir.path, 'Poppins.ttf'));
      if (!await fontFile.exists() || (await fontFile.length()) == 0) {
        ByteData? data;
        final candidateAssets = [
          'assets/fonts/Poppins-Medium.ttf',
          'assets/fonts/Poppins-SemiBold.ttf',
          'assets/fonts/Poppins-Regular.ttf',
          'assets/fonts/subfont.ttf',
        ];
        for (final candidate in candidateAssets) {
          try {
            data = await rootBundle.load(candidate);
            if (data.lengthInBytes > 0) break;
          } catch (_) {}
        }

        if (data != null) {
          await fontFile.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
        }
      }

      if (await fontFile.exists() && (await fontFile.length()) > 0) {
        _extractedFontDir = fontsDir.path;
        _extractedFontPath = fontFile.path;
        debugPrint('[PlayerSettings] libass font extracted successfully to: $_extractedFontPath');
      }
    } catch (e) {
      debugPrint('[PlayerSettings] Error extracting libass font fallback: $e');
    }
  }

  /// Returns effective max bytes for demuxer cache
  static int getEffectiveMaxBytes() {
    if (bufferPreset.value == BufferResiliencePreset.custom) {
      return (customBufferMs.value * 50000).clamp(52428800, 629145600);
    }
    return bufferPreset.value.maxBytes;
  }

  /// Returns effective back bytes buffer
  static int getEffectiveMaxBackBytes() {
    return 52428800; // 50 MB back buffer
  }

  /// Returns effective cache seconds for readahead
  static int getEffectiveCacheSecs() {
    if (bufferPreset.value == BufferResiliencePreset.custom) {
      return (customBufferMs.value / 1000).round().clamp(5, 120);
    }
    return bufferPreset.value.cacheSecs;
  }

  /// Returns the effective decoder list for UI or custom decoder configuration.
  static List<String> getEffectiveDecoders() {
    if (forceSoftwareDecoding.value) {
      return ['no'];
    }

    if (decoderPreset.value == DecoderPreset.custom && customDecoders.value.isNotEmpty) {
      return List<String>.from(customDecoders.value);
    }
    return _getDefaultDecodersForPreset(decoderPreset.value);
  }

  /// Drops decoders that cannot work in this build's configuration, so a
  /// value persisted by an older version can't strand playback.
  ///
  /// Android only: earlier builds seeded the chain with bare 'mediacodec',
  /// which renders black here (see [_getDefaultDecodersForPreset]). Rewrite
  /// it to the copy-back variant rather than dropping it, so users who had
  /// hardware decoding keep it.
  static List<String> _sanitizeDecoders(List<String> decoders) {
    if (!Platform.isAndroid) return decoders;
    final out = <String>[];
    for (final d in decoders) {
      final fixed = d == 'mediacodec' ? 'mediacodec-copy' : d;
      if (!out.contains(fixed)) out.add(fixed);
    }
    return out;
  }

  static List<String> _getDefaultDecodersForPreset(DecoderPreset preset) {
    switch (preset) {
      case DecoderPreset.softwareSafe:
        return ['no'];

      case DecoderPreset.hardwareSafe:
        return Platform.isAndroid ? ['mediacodec-copy', 'no'] : ['auto-copy', 'no'];

      case DecoderPreset.nvidiaCuda:
        return Platform.isWindows ? ['nvdec', 'd3d11va', 'no'] : ['nvdec', 'vaapi', 'no'];

      case DecoderPreset.hardwareAuto:
      case DecoderPreset.custom:
        if (Platform.isWindows) {
          return ['d3d11va', 'nvdec', 'auto-safe', 'no'];
        } else if (Platform.isMacOS || Platform.isIOS) {
          return ['videotoolbox', 'auto-safe', 'no'];
        } else if (Platform.isAndroid) {
          // MUST stay '-copy'. The Android VideoController is built with
          // enableAndroidSurfaceProducer: false, so frames are read back
          // through a texture; plain 'mediacodec' decodes straight to a
          // Surface we never attach and plays as a black screen with audio.
          // This list also seeds the 'custom' preset, whose hwdec string is
          // its first entry -- so a bare 'mediacodec' here breaks that too.
          return ['mediacodec-copy', 'auto-safe', 'no'];
        } else {
          return ['vaapi', 'nvdec', 'auto-safe', 'no'];
        }
    }
  }

  /// Returns the effective hwdec string for media_kit / libmpv based on active preset & platform
  static String getEffectiveHwdecString() {
    if (forceSoftwareDecoding.value) return 'no';
    switch (decoderPreset.value) {
      case DecoderPreset.hardwareAuto:
        return Platform.isAndroid ? 'mediacodec-copy' : (Platform.isWindows ? 'd3d11va' : 'auto-safe');
      case DecoderPreset.hardwareSafe:
        return Platform.isAndroid ? 'mediacodec-copy' : 'auto-copy';
      case DecoderPreset.softwareSafe:
        return 'no';
      case DecoderPreset.nvidiaCuda:
        return 'nvdec';
      case DecoderPreset.custom:
        final list = customDecoders.value;
        if (list.isEmpty || list.contains('no')) return 'no';
        return list.first;
    }
  }

  /// Returns a configured [VideoControllerConfiguration] for media_kit [VideoController].
  static VideoControllerConfiguration getVideoControllerConfiguration() {
    final hwdec = getEffectiveHwdecString();
    return VideoControllerConfiguration(
      hwdec: hwdec,
      enableHardwareAcceleration: hwdec != 'no',
      androidAttachSurfaceAfterVideoParameters: true,
      enableAndroidSurfaceProducer: false,
    );
  }

  /// Returns a configured [VideoControllerConfiguration] for media_kit_video.
  static VideoControllerConfiguration getMediaKitVideoControllerConfiguration() {
    return const VideoControllerConfiguration(
      enableAndroidSurfaceProducer: false,
    );
  }

  /// Returns a configured [PlayerConfiguration] for constructing a media_kit [Player].
  static PlayerConfiguration getMediaKitPlayerConfiguration() {
    return PlayerConfiguration(
      libass: useLibass.value,
      libassAndroidFont: 'assets/fonts/Poppins-Medium.ttf',
      libassAndroidFontName: 'Poppins',
      bufferSize: getEffectiveMaxBytes(),
      logLevel: MPVLogLevel.warn,
    );
  }

  /// Configures network stream continuity with strict separation between Live IPTV and VOD.
  static Future<void> applyStreamContinuity(Player player, {bool isLive = false}) async {
    try {
      final dynamic platform = player.platform;
      if (platform == null) return;
      // The reconnect knobs in Settings apply here. They are honoured for live
      // streams always, and for VOD only when the user opts in -- FFmpeg
      // treats HLS segments as unseekable while reconnect=1 is active, so
      // enabling it for VOD trades seeking for dropout resilience.
      final wantsReconnect = isLive || enableNetworkReconnect.value;
      if (wantsReconnect) {
        final delayMax = reconnectDelayMax.value;
        await platform.setProperty(
          'stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
              'reconnect_on_http_error=500,502,503,504,'
              'reconnect_delay_max=$delayMax',
        );
      } else {
        await platform.setProperty('stream-lavf-o', '');
      }
    } catch (e) {
      debugPrint('[PlayerSettings] applyStreamContinuity warning: $e');
    }
  }

  /// Pre-Open Properties: Demuxer, hardware decoder, cache buffer, disk cache dir,
  /// and FFmpeg fast-decode flags that MUST be configured before opening media.
  static Future<void> applyPreOpenProperties(Player player, {bool isLive = false, bool isTorrent = false}) async {
    try {
      final dynamic platform = player.platform;
      if (platform == null) return;

      // 1. Demuxer disk cache directory (Smooth AnymeX chunk buffering)
      if (enableDiskCache.value) {
        try {
          final tempDir = await getTemporaryDirectory();
          await platform.setProperty('demuxer-cache-dir', tempDir.path);
        } catch (_) {}
      }

      // 1. Audio Filter & Volume
      await platform.setProperty('af', 'scaletempo2=max-speed=8');
      await platform.setProperty('volume-max', '200');

      // 2. Hardware Decoder selection
      final effectiveHwdec = getEffectiveHwdecString();
      await platform.setProperty('hwdec', effectiveHwdec);

      // 3. Libass Engine & Font directory pre-configuration
      if (useLibass.value) {
        if (_extractedFontDir != null) {
          await platform.setProperty('sub-fonts-dir', _extractedFontDir!);
        }
        if (_extractedFontPath != null) {
          await platform.setProperty('sub-font-file', _extractedFontPath!);
        }
        await platform.setProperty('sub-ass', 'yes');
        await platform.setProperty('sub-visibility', 'yes');
      } else {
        await platform.setProperty('sub-visibility', 'no');
      }

      // 4. Default Audio Delay
      if (audioDelayDefault.value != 0.0) {
        await platform.setProperty('audio-delay', audioDelayDefault.value.toString());
      }

      // 5. A/V sync master timeline. This setting was stored and read back but
      // never applied to a player, so turning it off did nothing.
      if (hardwareAudioClock.value) {
        await platform.setProperty('video-sync', 'audio');
      }

      // ──────────────────────────────────────────────────────────────────────
      // TORRENT STREAMS. This branch used to return early, on the theory that
      // TorrServer does its own read-ahead and mpv's cache would fight it. That
      // was wrong, and upstream (whose author wrote the torrent engine) fixed
      // it in v1.0.7: TorrServer is a local HTTP server serving a file that is
      // still downloading, so it *will* have gaps, and an mpv with no cache and
      // a short timeout dies on the first one rather than waiting it out --
      // which is exactly the "stream error / stuck" symptom torrent playback
      // showed. Buffer sizes still follow the user's preset; the long timeout
      // and the reconnect flags are torrent-specific and not worth exposing.
      // ──────────────────────────────────────────────────────────────────────
      if (isTorrent) {
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('demuxer-max-bytes', '${getEffectiveMaxBytes()}');
        await platform.setProperty('demuxer-max-back-bytes', '${getEffectiveMaxBackBytes()}');
        await platform.setProperty('cache-secs', '${getEffectiveCacheSecs()}');
        await platform.setProperty('demuxer-readahead-secs', '${getEffectiveCacheSecs()}');
        await platform.setProperty('network-timeout', '60');
        await platform.setProperty(
          'stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,'
              'reconnect_on_network_error=1,reconnect_delay_max=10',
        );
        return;
      }

      // 6. Video Decoder Optimizations (AnymeX)
      await platform.setProperty('vd-lavc-fast', enableFastDecode.value ? 'yes' : 'no');
      await platform.setProperty('vd-lavc-skiploopfilter', skipLoopFilter.value);
      if (lavcThreads.value > 0) {
        await platform.setProperty('vd-lavc-threads', '${lavcThreads.value}');
      } else {
        await platform.setProperty('vd-lavc-threads', 'auto');
      }

      // 7. Buffer & Demuxer Cache Configuration (HTTP VOD only)
      await platform.setProperty('cache', 'yes');
      await platform.setProperty('demuxer-max-bytes', '${getEffectiveMaxBytes()}');
      await platform.setProperty('demuxer-max-back-bytes', '${getEffectiveMaxBackBytes()}');
      await platform.setProperty('cache-secs', '${getEffectiveCacheSecs()}');
      await platform.setProperty('demuxer-readahead-secs', '${getEffectiveCacheSecs()}');
      await platform.setProperty('network-timeout', '30');

      // 8. Network Stream Continuity (Live IPTV vs VOD separation)
      await applyStreamContinuity(player, isLive: isLive);

      // 9. Native HLS & image-disguised (.jpg/.png) stream probing
      await platform.setProperty('hls-bitrate', 'max');
      await platform.setProperty('demuxer-lavf-probesize', '32768000');
      await platform.setProperty('demuxer-lavf-analyzeduration', '20');
      await platform.setProperty('demuxer-lavf-o', 'strict=experimental');
    } catch (e) {
      debugPrint('[PlayerSettings] applyPreOpenProperties warning: $e');
    }
  }

  /// Post-Open / Dynamic Properties: Subtitle styling and real-time tweaks that can be
  /// applied safely after media open or during live playback.
  static Future<void> applyPostOpenProperties(Player player) async {
    try {
      await applySubtitleStyling(player);
    } catch (e) {
      debugPrint('[PlayerSettings] applyPostOpenProperties warning: $e');
    }
  }

  /// Automatically resolves all required Referer, Origin, and User-Agent headers for known streaming CDNs.
  static Map<String, String> resolveStreamHeaders(String url, [Map<String, String>? initialHeaders]) {
    final h = <String, String>{
      'Connection': 'keep-alive',
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    };
    if (initialHeaders != null) {
      h.addAll(initialHeaders);
    }

    final lower = url.toLowerCase();
    if (lower.contains('hakunaymatata.com')) {
      h['User-Agent'] = 'Lavf/60.16.100';
    } else if (lower.contains('movieboxnoob.cc') ||
        lower.contains('moviebox.ph') ||
        lower.contains('cinejoy.to') ||
        lower.contains('cinejoy')) {
      h['Referer'] = 'https://cinejoy.to/';
      h['Origin'] = 'https://cinejoy.to';
    } else if (lower.contains('peakstorm.top') ||
        lower.contains('majorplay.net') ||
        lower.contains('slast430did.com') ||
        lower.contains('vidzy.cc') ||
        lower.contains('vimeos.zip') ||
        lower.contains('wecollege.net')) {
      h['Referer'] = 'https://www.movy.bz/';
      h['Origin'] = 'https://www.movy.bz';
    } else if (lower.contains('chillflix.lol')) {
      h['Referer'] = 'https://www.chillflix.lol/';
      h['Origin'] = 'https://www.chillflix.lol';
    } else if (lower.contains('hclod.qzz.io') || lower.contains('watchplay.shop')) {
      h['Referer'] = 'https://v1.watchplay.shop/';
      h['Origin'] = 'https://v1.watchplay.shop';
    } else if (lower.contains('valhallastream') || lower.contains('1shows.app') || lower.contains('rivestream')) {
      h['Referer'] = 'https://www.rivestream.app/';
      h['Origin'] = 'https://www.rivestream.app';
    } else if (lower.contains('videasy') || lower.contains('speedracelight')) {
      h['Referer'] = 'https://player.videasy.to/';
      h['Origin'] = 'https://player.videasy.to';
    } else if (lower.contains('streamraiwind.stream') || lower.contains('vuflix.co')) {
      h['Referer'] = 'https://vuflix.co/';
      h['Origin'] = 'https://vuflix.co';
    } else if (lower.contains('net77.cc') || lower.contains('nm-cdn4.top')) {
      h['Referer'] = 'https://net77.cc/';
      h['Origin'] = 'https://net77.cc';
    } else if (lower.contains('gn1r5n.org') || lower.contains('owphbf24.com')) {
      h['Referer'] = 'https://gn1r5n.org/';
      h['Origin'] = 'https://gn1r5n.org';
    } else if (lower.contains('watching.onl') ||
        lower.contains('livedns.my') ||
        lower.contains('sugevideo.xyz') ||
        lower.contains('anivideo.sbs') ||
        lower.contains('trycloud.pro') ||
        lower.contains('cloudvideo.lat') ||
        lower.contains('megaplay.buzz') ||
        lower.contains('vidwish.live') ||
        (initialHeaders != null && initialHeaders['Referer']?.contains('megaplay.buzz') == true) ||
        (initialHeaders != null && initialHeaders['Referer']?.contains('vidwish') == true)) {
      h['Referer'] = 'https://megaplay.buzz/';
      h['Origin'] = 'https://megaplay.buzz';
      h['Cookie'] = 'SITE_TOTAL_ID=ce655f0eea754f2888ea98ded373e3b5';
    } else if (lower.contains('anidb.app') ||
        lower.contains('hls.anidb.app') ||
        (initialHeaders != null && initialHeaders['Referer']?.contains('anidb.app') == true)) {
      h['Referer'] = 'https://anidb.app/';
      h['Origin'] = 'https://anidb.app';
    }
    return h;
  }

  /// Convenience method that applies both pre-open and post-open properties to a media_kit [Player].
  static Future<void> applyToPlayer(Player player, {bool isLive = false}) async {
    await applyPreOpenProperties(player, isLive: isLive);
    await applyPostOpenProperties(player);
  }

  /// Live-applies all subtitle appearance properties directly to the underlying libmpv instance.
  static Future<void> applySubtitleStyling(Player player) async {
    try {
      final dynamic platform = player.platform;
      if (platform != null) {
        if (useLibass.value) {
          // Ensure subtitle visibility and libass engine are activated in libmpv
          await platform.setProperty('sub-visibility', 'yes');
          await platform.setProperty('sub-ass', 'yes');

          // Font paths
          if (_extractedFontDir != null) {
            await platform.setProperty('sub-fonts-dir', _extractedFontDir!);
          }
          if (_extractedFontPath != null) {
            await platform.setProperty('sub-font-file', _extractedFontPath!);
          }

          // Font family
          final font = (subFont.value.trim().isEmpty || subFont.value == 'subfont')
              ? 'Poppins'
              : subFont.value.trim();
          await platform.setProperty('sub-font', font);

          // Typography
          await platform.setProperty('sub-font-size', subFontSize.value.toString());
          await platform.setProperty('sub-scale', subScale.value.toStringAsFixed(2));
          await platform.setProperty('sub-bold', subBold.value ? 'yes' : 'no');
          await platform.setProperty('sub-italic', subItalic.value ? 'yes' : 'no');

          // Colors
          await platform.setProperty('sub-color', _formatMpvColor(subColor.value));
          await platform.setProperty('sub-back-color', _formatMpvColor(subBackColor.value));

          // Borders & Outlines
          await platform.setProperty('sub-border-color', _formatMpvColor(subBorderColor.value));
          await platform.setProperty('sub-border-size', subBorderSize.value.toStringAsFixed(1));

          // Shadows
          await platform.setProperty('sub-shadow-offset', subShadowOffset.value.toStringAsFixed(1));
          await platform.setProperty('sub-shadow-color', _formatMpvColor(subShadowColor.value));

          // Positioning & Layout
          await platform.setProperty('sub-margin-y', subMarginY.value.round().toString());
          await platform.setProperty('sub-pos', subPos.value.round().toString());
          await platform.setProperty('sub-align-x', subAlignX.value);

          // ASS/SSA Script Preservation vs Override
          await platform.setProperty('sub-ass-override', subAssOverride.value);
          await platform.setProperty('sub-ass-force-margins', 'yes');
          await platform.setProperty('sub-use-margins', 'yes');

          // Force style string for ASS subtitles when override is active
          if (subAssOverride.value != 'no') {
            final assForceStyle = _buildAssForceStyleString(font);
            if (assForceStyle.isNotEmpty) {
              await platform.setProperty('sub-ass-force-style', assForceStyle);
            }
          }
        } else {
          // Flutter Subtitle Engine: hide native MPV text rendering so Flutter's SubtitleView renders cleanly
          await platform.setProperty('sub-visibility', 'no');
        }
      }
    } catch (e) {
      debugPrint('[PlayerSettings] applySubtitleStyling error: $e');
    }
  }

  /// Builds a reactive [SubtitleViewConfiguration] for Flutter's subtitle overlay widget.
  static SubtitleViewConfiguration getSubtitleViewConfiguration() {
    if (useLibass.value) {
      return const SubtitleViewConfiguration(
        visible: false,
      );
    }

    Color parseColor(String hex, {Color fallback = Colors.white}) {
      var str = hex.replaceAll('#', '').trim();
      if (str.length == 6) str = 'FF$str';
      if (str.length == 8) {
        final val = int.tryParse(str, radix: 16);
        if (val != null) return Color(val);
      }
      return fallback;
    }

    final textColor = parseColor(subColor.value);
    final boxColor = parseColor(subBackColor.value, fallback: Colors.transparent);
    final borderColor = parseColor(subBorderColor.value, fallback: Colors.black);
    final shadowColor = parseColor(subShadowColor.value, fallback: Colors.black54);

    final font = (subFont.value.isEmpty || subFont.value == 'subfont') ? 'Poppins' : subFont.value;
    final align = subAlignX.value == 'left'
        ? TextAlign.left
        : (subAlignX.value == 'right' ? TextAlign.right : TextAlign.center);

    final shadows = <Shadow>[];
    if (subBorderSize.value > 0) {
      final b = subBorderSize.value;
      final r = b * 0.8;
      final d = r * 0.707;
      shadows.addAll([
        Shadow(color: borderColor, offset: Offset(-r, 0)),
        Shadow(color: borderColor, offset: Offset(r, 0)),
        Shadow(color: borderColor, offset: Offset(0, -r)),
        Shadow(color: borderColor, offset: Offset(0, r)),
        Shadow(color: borderColor, offset: Offset(-d, -d)),
        Shadow(color: borderColor, offset: Offset(d, -d)),
        Shadow(color: borderColor, offset: Offset(-d, d)),
        Shadow(color: borderColor, offset: Offset(d, d)),
      ]);
    }
    if (subShadowOffset.value > 0) {
      shadows.add(
        Shadow(
          color: shadowColor,
          offset: Offset(subShadowOffset.value, subShadowOffset.value),
          blurRadius: 3.0,
        ),
      );
    }

    return SubtitleViewConfiguration(
      visible: true,
      textAlign: align,
      padding: EdgeInsets.fromLTRB(
        subAlignX.value == 'left' ? 32 : 16,
        0,
        subAlignX.value == 'right' ? 32 : 16,
        subMarginY.value.clamp(8.0, 300.0),
      ),
      style: TextStyle(
        fontFamily: font,
        fontSize: (subFontSize.value * subScale.value).clamp(12.0, 96.0),
        fontWeight: subBold.value ? FontWeight.bold : FontWeight.w600,
        fontStyle: subItalic.value ? FontStyle.italic : FontStyle.normal,
        color: textColor,
        backgroundColor: boxColor,
        shadows: shadows.isNotEmpty ? shadows : null,
      ),
    );
  }

  static String _formatMpvColor(String hex) {
    var str = hex.replaceAll('#', '').trim().toUpperCase();
    if (str.length == 6) {
      return '#FF$str';
    }
    if (str.length == 8) {
      return '#$str';
    }
    return '#FFFFFFFF';
  }

  static String _buildAssForceStyleString(String font) {
    try {
      final isBoxed = subBackColor.value != '#00000000' && !subBackColor.value.startsWith('#00');
      final borderStyle = isBoxed ? 3 : 1;
      final primaryColour = _toAssColor(subColor.value);
      final outlineColour = _toAssColor(subBorderColor.value);
      final backColour = _toAssColor(isBoxed ? subBackColor.value : subShadowColor.value);

      final size = (subFontSize.value * subScale.value).round();
      final bold = subBold.value ? 1 : 0;
      final italic = subItalic.value ? 1 : 0;
      final outline = subBorderSize.value.toStringAsFixed(1);
      final shadow = subShadowOffset.value.toStringAsFixed(1);
      final marginV = subMarginY.value.round();

      return 'Fontname=$font,Fontsize=$size,PrimaryColour=$primaryColour,BackColour=$backColour,OutlineColour=$outlineColour,Bold=$bold,Italic=$italic,BorderStyle=$borderStyle,Outline=$outline,Shadow=$shadow,MarginV=$marginV';
    } catch (e) {
      debugPrint('[_buildAssForceStyleString] error: $e');
      return '';
    }
  }

  static String _toAssColor(String hex) {
    var str = hex.replaceAll('#', '').trim().toUpperCase();
    if (str.length == 6) {
      str = 'FF$str';
    }
    if (str.length != 8) return '&H00FFFFFF';

    final alpha = int.tryParse(str.substring(0, 2), radix: 16) ?? 255;
    final r = str.substring(2, 4);
    final g = str.substring(4, 6);
    final b = str.substring(6, 8);

    // Invert alpha for ASS (00 = opaque, FF = transparent)
    final assAlpha = (255 - alpha).toRadixString(16).padLeft(2, '0').toUpperCase();

    return '&H$assAlpha$b$g$r';
  }

  /// Backward compatible stub for any controller calls
  static void applyToController(dynamic controller) {
    // No-op for media_kit
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mutation & Persistence
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> setDecoderPreset(DecoderPreset val) async {
    decoderPreset.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDecoderPreset, val.name);
    _notify();
  }

  static Future<void> setForceSoftwareDecoding(bool val) async {
    forceSoftwareDecoding.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForceSoftwareDecoding, val);
    _notify();
  }

  static Future<void> setCustomDecoders(List<String> list) async {
    customDecoders.value = List.from(list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCustomDecoders, list);
    _notify();
  }

  static Future<void> setBufferPreset(BufferResiliencePreset val) async {
    bufferPreset.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBufferPreset, val.name);
    _notify();
  }

  static Future<void> setCustomBuffer(int durationMs, int packetCount) async {
    customBufferMs.value = durationMs;
    customBufferCount.value = packetCount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomBufferMs, durationMs);
    await prefs.setInt(_keyCustomBufferCount, packetCount);
    _notify();
  }

  static Future<void> setEnableNetworkReconnect(bool val) async {
    enableNetworkReconnect.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableNetworkReconnect, val);
    _notify();
  }

  static Future<void> setReconnectDelayMax(int val) async {
    reconnectDelayMax.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReconnectDelayMax, val);
    _notify();
  }

  static Future<void> setAutoResyncOnStall(bool val) async {
    autoResyncOnStall.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoResyncOnStall, val);
    _notify();
  }

  static Future<void> setLowLatency(bool val) async {
    lowLatency.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowLatency, val);
    _notify();
  }

  static Future<void> setHardwareAudioClock(bool val) async {
    hardwareAudioClock.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHardwareAudioClock, val);
    _notify();
  }

  static Future<void> setAudioDelayDefault(double val) async {
    audioDelayDefault.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAudioDelayDefault, val);
    _notify();
  }

  static Future<void> setAutoNextEnabled(bool val) async {
    autoNextEnabled.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNextEnabled, val);
    _notify();
  }

  // ── Subtitle Customization Setters ──

  static Future<void> setSubStylePreset(SubtitleStylePreset preset, {Player? player}) async {
    subStylePreset.value = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubStylePreset, preset.name);

    if (preset != SubtitleStylePreset.custom) {
      await setSubColor(preset.textColor, notify: false);
      await setSubBackColor(preset.backColor, notify: false);
      await setSubBorderColor(preset.borderColor, notify: false);
      await setSubBorderSize(preset.borderSize, notify: false);
      await setSubShadowOffset(preset.shadowOffset, notify: false);
      await setSubShadowColor(preset.shadowColor, notify: false);
      await setSubBold(preset.bold, notify: false);
      await setSubItalic(preset.italic, notify: false);
    }

    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubFont(String font, {Player? player}) async {
    subFont.value = font;
    subStylePreset.value = SubtitleStylePreset.custom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubFont, font);
    await prefs.setString(_keySubStylePreset, SubtitleStylePreset.custom.name);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubFontSize(int size, {Player? player}) async {
    subFontSize.value = size.clamp(14, 80);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubFontSize, subFontSize.value);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubScale(double scale, {Player? player}) async {
    subScale.value = (scale.clamp(0.5, 3.0) * 100).round() / 100.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubScale, subScale.value);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubColor(String hex, {bool notify = true, Player? player}) async {
    subColor.value = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubColor, hex);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubBackColor(String hex, {bool notify = true, Player? player}) async {
    subBackColor.value = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubBackColor, hex);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubBorderColor(String hex, {bool notify = true, Player? player}) async {
    subBorderColor.value = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubBorderColor, hex);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubBorderSize(double size, {bool notify = true, Player? player}) async {
    subBorderSize.value = size.clamp(0.0, 8.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubBorderSize, subBorderSize.value);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubShadowOffset(double offset, {bool notify = true, Player? player}) async {
    subShadowOffset.value = offset.clamp(0.0, 8.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubShadowOffset, subShadowOffset.value);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubShadowColor(String hex, {bool notify = true, Player? player}) async {
    subShadowColor.value = hex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubShadowColor, hex);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubBold(bool val, {bool notify = true, Player? player}) async {
    subBold.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubBold, val);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubItalic(bool val, {bool notify = true, Player? player}) async {
    subItalic.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubItalic, val);
    if (player != null) applySubtitleStyling(player);
    if (notify) _notify();
  }

  static Future<void> setSubMarginY(double val, {Player? player}) async {
    subMarginY.value = val.clamp(0.0, 200.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubMarginY, subMarginY.value);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubPos(double val, {Player? player}) async {
    subPos.value = val.clamp(0.0, 100.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySubPos, subPos.value);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubAlignX(String val, {Player? player}) async {
    subAlignX.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubAlignX, val);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setSubAssOverride(String val, {Player? player}) async {
    subAssOverride.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubAssOverride, val);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setUseLibass(bool val, {Player? player}) async {
    useLibass.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseLibass, val);
    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> resetSubtitleDefaults({Player? player}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySubStylePreset);
    await prefs.remove(_keySubFont);
    await prefs.remove(_keySubFontSize);
    await prefs.remove(_keySubScale);
    await prefs.remove(_keySubColor);
    await prefs.remove(_keySubBackColor);
    await prefs.remove(_keySubBorderColor);
    await prefs.remove(_keySubBorderSize);
    await prefs.remove(_keySubShadowOffset);
    await prefs.remove(_keySubShadowColor);
    await prefs.remove(_keySubBold);
    await prefs.remove(_keySubItalic);
    await prefs.remove(_keySubMarginY);
    await prefs.remove(_keySubPos);
    await prefs.remove(_keySubAlignX);
    await prefs.remove(_keySubAssOverride);
    await prefs.remove(_keyUseLibass);

    useLibass.value = false;
    subStylePreset.value = SubtitleStylePreset.classicWhite;
    subFont.value = 'Poppins';
    subFontSize.value = 32;
    subScale.value = 1.0;
    subColor.value = '#FFFFFFFF';
    subBackColor.value = '#00000000';
    subBorderColor.value = '#FF000000';
    subBorderSize.value = 2.0;
    subShadowOffset.value = 0.0;
    subShadowColor.value = '#80000000';
    subBold.value = false;
    subItalic.value = false;
    subMarginY.value = 30.0;
    subPos.value = 100.0;
    subAlignX.value = 'center';
    subAssOverride.value = 'no';

    if (player != null) applySubtitleStyling(player);
    _notify();
  }

  static Future<void> setEnableFastDecode(bool val) async {
    enableFastDecode.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableFastDecode, val);
    _notify();
  }

  static Future<void> setSkipLoopFilter(String val) async {
    skipLoopFilter.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkipLoopFilter, val);
    _notify();
  }

  static Future<void> setLavcThreads(int val) async {
    lavcThreads.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLavcThreads, val);
    _notify();
  }

  static Future<void> setEnableDiskCache(bool val) async {
    enableDiskCache.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableDiskCache, val);
    _notify();
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDecoderPreset);
    await prefs.remove(_keyForceSoftwareDecoding);
    await prefs.remove(_keyCustomDecoders);
    await prefs.remove(_keyBufferPreset);
    await prefs.remove(_keyCustomBufferMs);
    await prefs.remove(_keyCustomBufferCount);
    await prefs.remove(_keyEnableFastDecode);
    await prefs.remove(_keySkipLoopFilter);
    await prefs.remove(_keyLavcThreads);
    await prefs.remove(_keyEnableDiskCache);
    await prefs.remove(_keyEnableNetworkReconnect);
    await prefs.remove(_keyReconnectDelayMax);
    await prefs.remove(_keyAutoResyncOnStall);
    await prefs.remove(_keyLowLatency);
    await prefs.remove(_keyHardwareAudioClock);
    await prefs.remove(_keyAudioDelayDefault);
    await prefs.remove(_keyAutoNextEnabled);

    decoderPreset.value = DecoderPreset.hardwareAuto;
    forceSoftwareDecoding.value = false;
    bufferPreset.value = Platform.isAndroid
        ? BufferResiliencePreset.highResilience
        : BufferResiliencePreset.standard;
    customBufferMs.value = 6000;
    customBufferCount.value = 300;
    enableFastDecode.value = true;
    skipLoopFilter.value = 'nonkey';
    lavcThreads.value = 4;
    enableDiskCache.value = true;
    enableNetworkReconnect.value = false;
    reconnectDelayMax.value = 5;
    autoResyncOnStall.value = true;
    lowLatency.value = false;
    hardwareAudioClock.value = true;
    audioDelayDefault.value = 0.0;
    autoNextEnabled.value = true;
    customDecoders.value = _getDefaultDecodersForPreset(DecoderPreset.hardwareAuto);

    await resetSubtitleDefaults();
    _notify();
  }

  static void _notify() {
    changeNotifier.value++;
  }
}
