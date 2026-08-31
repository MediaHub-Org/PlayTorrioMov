import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudiobookPlayerPreset {
  modernGlass('Modern Glass Island', 'Sleek floating glassmorphism player with waveform scrubber & ambient glow'),
  vinylStudio('Vinyl Turntable Studio', 'Rotating vinyl disc, tonearm animation & analog vintage VU styling'),
  minimalCapsule('Minimalist Focus Capsule', 'Compact distraction-free floating capsule with essential controls'),
  immersiveCanvas('Immersive Canvas Studio', 'Full-screen cinematic ambient blur canvas with oversized artwork'),
  customStudio('Custom Drag & Drop Studio', 'Your fully customized, arranged and styled audio player');

  final String label;
  final String description;
  const AudiobookPlayerPreset(this.label, this.description);
}

enum AudiobookSeekbarStyle {
  audioWaveformCanvas('Dynamic Audio Waveform Canvas', 'Procedural animated waveform bars with live equalizer scrubbing'),
  gradientProgress('Neon Gradient Progress Bar', 'Multi-color vibrant linear gradient scrubber with glowing tip'),
  standardSlider('Precision Glass Slider', 'Tactile interactive glass track with timecode readouts'),
  circularRing('Radial Circular Ring Scrubber', 'Radial circular dial scrubber for compact modern interfaces');

  final String label;
  final String description;
  const AudiobookSeekbarStyle(this.label, this.description);
}

enum AudiobookPlayButtonStyle {
  circleGlow('Circle Aura Glow'),
  liquidGlassNeo('Liquid Glass Neomorphic'),
  roundedSquare('Rounded Glass Square'),
  accentPill('Wide Accent Pill');

  final String label;
  const AudiobookPlayButtonStyle(this.label);
}

enum AudiobookHoverEffect {
  scaleBounce('Scale & Spring Bounce'),
  glowAura('Theme Accent Glow Aura'),
  glassRipple('Liquid Glass Ripple'),
  tilt3D('3D Subtle Tilt Perspective');

  final String label;
  const AudiobookHoverEffect(this.label);
}

enum AudiobookArtworkStyle {
  square3D('3D Rounded Square with Glow'),
  vinylDisc('Spinning Vinyl Disc'),
  floatingCard('Floating Glass Card'),
  hidden('Hidden / Focus Mode');

  final String label;
  const AudiobookArtworkStyle(this.label);
}

enum AudiobookCardDensity {
  compact('Compact (Dense Grid)', 0.88),
  standard('Standard (Balanced)', 1.0),
  spacious('Spacious (Large Covers)', 1.15);

  final String label;
  final double scale;
  const AudiobookCardDensity(this.label, this.scale);
}

abstract final class AudiobookSettings {
  // Atmosphere & Lighting Keys
  static const _keyEnableAmbientLights = 'audiobook_enable_ambient_lights';

  // Discovery & UI Keys
  static const _keyEnableSpotlight = 'audiobook_enable_spotlight';
  static const _keyShowContinueListening = 'audiobook_show_continue_listening';
  static const _keyCardDensity = 'audiobook_card_density';
  static const _keyShowCategoryPills = 'audiobook_show_category_pills';
  static const _keyCardHoverGlow = 'audiobook_card_hover_glow';

  // Player Engine Keys
  static const _keySelectedPlayerPreset = 'audiobook_selected_player_preset';
  static const _keyCustomSeekbarStyle = 'audiobook_custom_seekbar_style';
  static const _keyCustomPlayButtonStyle = 'audiobook_custom_play_button_style';
  static const _keyCustomHoverEffect = 'audiobook_custom_hover_effect';
  static const _keyCustomArtworkStyle = 'audiobook_custom_artwork_style';
  static const _keyComponentOrder = 'audiobook_component_order';

  // Atmosphere Notifiers
  static final ValueNotifier<bool> enableAmbientLights = ValueNotifier<bool>(true);

  // Discovery Notifiers
  static final ValueNotifier<bool> enableSpotlight = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showContinueListening = ValueNotifier<bool>(true);
  static final ValueNotifier<AudiobookCardDensity> cardDensity =
      ValueNotifier<AudiobookCardDensity>(AudiobookCardDensity.standard);
  static final ValueNotifier<bool> showCategoryPills = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> cardHoverGlow = ValueNotifier<bool>(true);

  // Player Engine Notifiers
  static final ValueNotifier<AudiobookPlayerPreset> selectedPlayerPreset =
      ValueNotifier<AudiobookPlayerPreset>(AudiobookPlayerPreset.modernGlass);
  static final ValueNotifier<AudiobookSeekbarStyle> customSeekbarStyle =
      ValueNotifier<AudiobookSeekbarStyle>(AudiobookSeekbarStyle.audioWaveformCanvas);
  static final ValueNotifier<AudiobookPlayButtonStyle> customPlayButtonStyle =
      ValueNotifier<AudiobookPlayButtonStyle>(AudiobookPlayButtonStyle.circleGlow);
  static final ValueNotifier<AudiobookHoverEffect> customHoverEffect =
      ValueNotifier<AudiobookHoverEffect>(AudiobookHoverEffect.glowAura);
  static final ValueNotifier<AudiobookArtworkStyle> customArtworkStyle =
      ValueNotifier<AudiobookArtworkStyle>(AudiobookArtworkStyle.square3D);
  static final ValueNotifier<List<String>> componentOrder = ValueNotifier<List<String>>([
    'artwork',
    'title',
    'seekbar',
    'mainControls',
    'secondaryControls',
    'chaptersButton',
  ]);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    enableAmbientLights.value = prefs.getBool(_keyEnableAmbientLights) ?? true;

    enableSpotlight.value = prefs.getBool(_keyEnableSpotlight) ?? true;
    showContinueListening.value = prefs.getBool(_keyShowContinueListening) ?? true;
    final densityStr = prefs.getString(_keyCardDensity);
    cardDensity.value = AudiobookCardDensity.values.firstWhere(
      (d) => d.name == densityStr,
      orElse: () => AudiobookCardDensity.standard,
    );
    showCategoryPills.value = prefs.getBool(_keyShowCategoryPills) ?? true;
    cardHoverGlow.value = prefs.getBool(_keyCardHoverGlow) ?? true;

    final presetStr = prefs.getString(_keySelectedPlayerPreset);
    selectedPlayerPreset.value = AudiobookPlayerPreset.values.firstWhere(
      (p) => p.name == presetStr,
      orElse: () => AudiobookPlayerPreset.modernGlass,
    );

    final seekbarStr = prefs.getString(_keyCustomSeekbarStyle);
    customSeekbarStyle.value = AudiobookSeekbarStyle.values.firstWhere(
      (s) => s.name == seekbarStr,
      orElse: () => AudiobookSeekbarStyle.audioWaveformCanvas,
    );

    final playBtnStr = prefs.getString(_keyCustomPlayButtonStyle);
    customPlayButtonStyle.value = AudiobookPlayButtonStyle.values.firstWhere(
      (b) => b.name == playBtnStr,
      orElse: () => AudiobookPlayButtonStyle.circleGlow,
    );

    final hoverStr = prefs.getString(_keyCustomHoverEffect);
    customHoverEffect.value = AudiobookHoverEffect.values.firstWhere(
      (h) => h.name == hoverStr,
      orElse: () => AudiobookHoverEffect.glowAura,
    );

    final artStr = prefs.getString(_keyCustomArtworkStyle);
    customArtworkStyle.value = AudiobookArtworkStyle.values.firstWhere(
      (a) => a.name == artStr,
      orElse: () => AudiobookArtworkStyle.square3D,
    );


    final orderList = prefs.getStringList(_keyComponentOrder);
    if (orderList != null && orderList.isNotEmpty) {
      componentOrder.value = orderList;
    }
  }

  // Setters
  static Future<void> setEnableAmbientLights(bool val) async {
    enableAmbientLights.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableAmbientLights, val);
  }




  static Future<void> setEnableSpotlight(bool val) async {
    enableSpotlight.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableSpotlight, val);
  }

  static Future<void> setShowContinueListening(bool val) async {
    showContinueListening.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowContinueListening, val);
  }

  static Future<void> setCardDensity(AudiobookCardDensity val) async {
    cardDensity.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardDensity, val.name);
  }

  static Future<void> setShowCategoryPills(bool val) async {
    showCategoryPills.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowCategoryPills, val);
  }


  static Future<void> setCardHoverGlow(bool val) async {
    cardHoverGlow.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCardHoverGlow, val);
  }

  static Future<void> setSelectedPlayerPreset(AudiobookPlayerPreset val) async {
    selectedPlayerPreset.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedPlayerPreset, val.name);
  }

  static Future<void> setCustomSeekbarStyle(AudiobookSeekbarStyle val) async {
    customSeekbarStyle.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomSeekbarStyle, val.name);
  }

  static Future<void> setCustomPlayButtonStyle(AudiobookPlayButtonStyle val) async {
    customPlayButtonStyle.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPlayButtonStyle, val.name);
  }

  static Future<void> setCustomHoverEffect(AudiobookHoverEffect val) async {
    customHoverEffect.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomHoverEffect, val.name);
  }

  static Future<void> setCustomArtworkStyle(AudiobookArtworkStyle val) async {
    customArtworkStyle.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomArtworkStyle, val.name);
  }





  static Future<void> setComponentOrder(List<String> val) async {
    componentOrder.value = List.from(val);
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyComponentOrder, val);
  }

  static Future<void> reorderComponents(int oldIndex, int newIndex) async {
    final list = List<String>.from(componentOrder.value);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await setComponentOrder(list);
  }
}
