import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../content_display_enums.dart';

enum MangaCardDensity {
  compact('Compact (Dense Grid)', 0.88),
  standard('Standard (Balanced)', 1.0),
  spacious('Spacious (Large Posters)', 1.15);

  final String label;
  final double scale;
  const MangaCardDensity(this.label, this.scale);
}

enum MangaReadingMode {
  webtoon('Vertical Continuous (Webtoon)'),
  horizontalLtr('Horizontal (Left to Right)'),
  horizontalRtl('Horizontal (Right to Left / Manga)');

  final String label;
  const MangaReadingMode(this.label);
}

enum MangaReaderMaxWidth {
  full('Full Screen (100%)', null),
  compact('Compact (720px)', 720.0),
  standard('Standard (900px)', 900.0),
  wide('Wide (1150px)', 1150.0);

  final String label;
  final double? width;
  const MangaReaderMaxWidth(this.label, this.width);
}

enum MangaReaderBackground {
  pitchBlack('Pitch Black', Color(0xFF000000)),
  deepCharcoal('Deep Charcoal', Color(0xFF0B0D13)),
  darkSlate('Dark Slate', Color(0xFF131722)),
  sepiaDark('Sepia Dark', Color(0xFF1B1612));

  final String label;
  final Color color;
  const MangaReaderBackground(this.label, this.color);
}

enum MangaControlBarStyle {
  floatingGlass('Floating Glass Island'),
  dockedBar('Docked Bottom Bar'),
  minimalPill('Minimalist Floating Pill');

  final String label;
  const MangaControlBarStyle(this.label);
}

abstract final class MangaSettings {
  static const _keyEnableAmbientLights = 'manga_enable_ambient_lights';
  static const _keyAmbientPattern = 'manga_ambient_pattern';
  static const _keyAmbientIntensity = 'manga_ambient_intensity';
  static const _keyAmbientSpeed = 'manga_ambient_speed';
  static const _keyShowContinueReading = 'manga_show_continue_reading';
  static const _keyCardDensity = 'manga_card_density';
  static const _keyShowContentTypeBadge = 'manga_show_content_type_badge';
  static const _keyShowMangaYear = 'manga_show_manga_year';
  static const _keyShowScrollTrack = 'manga_show_scroll_track';
  static const _keyAmbientCardGlow = 'manga_ambient_card_glow';

  // Reader keys
  static const _keyDefaultReadingMode = 'manga_default_reading_mode';
  static const _keyReaderMaxWidth = 'manga_reader_max_width';
  static const _keyReaderBackground = 'manga_reader_background';
  static const _keyReaderControlBarStyle = 'manga_reader_control_bar_style';
  static const _keyShowPageDeck = 'manga_show_page_deck';
  static const _keyShowPageScrubber = 'manga_show_page_scrubber';
  static const _keyEnableNextChapterDeck = 'manga_enable_next_chapter_deck';
  static const _keyPageGap = 'manga_page_gap';

  // Atmosphere Notifiers
  static final ValueNotifier<bool> enableAmbientLights = ValueNotifier<bool>(true);
  static final ValueNotifier<AmbientLightPattern> ambientLightPattern =
      ValueNotifier<AmbientLightPattern>(AmbientLightPattern.dualOrbs);
  static final ValueNotifier<double> ambientLightIntensity = ValueNotifier<double>(0.22);
  static final ValueNotifier<double> ambientLightSpeed = ValueNotifier<double>(1.0);

  // Cards & Layout Notifiers
  static final ValueNotifier<bool> showContinueReading = ValueNotifier<bool>(true);
  static final ValueNotifier<MangaCardDensity> cardDensity =
      ValueNotifier<MangaCardDensity>(MangaCardDensity.standard);
  static final ValueNotifier<bool> showContentTypeBadge = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showMangaYear = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showScrollTrack = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> ambientCardGlow = ValueNotifier<bool>(true);

  // Reader Experience Notifiers
  static final ValueNotifier<MangaReadingMode> defaultReadingMode =
      ValueNotifier<MangaReadingMode>(MangaReadingMode.webtoon);
  static final ValueNotifier<MangaReaderMaxWidth> readerMaxWidth =
      ValueNotifier<MangaReaderMaxWidth>(MangaReaderMaxWidth.standard);
  static final ValueNotifier<MangaReaderBackground> readerBackground =
      ValueNotifier<MangaReaderBackground>(MangaReaderBackground.pitchBlack);
  static final ValueNotifier<MangaControlBarStyle> readerControlBarStyle =
      ValueNotifier<MangaControlBarStyle>(MangaControlBarStyle.floatingGlass);
  static final ValueNotifier<bool> showPageDeck = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> showPageScrubber = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> enableNextChapterDeck = ValueNotifier<bool>(true);
  static final ValueNotifier<double> pageGap = ValueNotifier<double>(6.0);

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    enableAmbientLights.value = prefs.getBool(_keyEnableAmbientLights) ?? true;
    final patternStr = prefs.getString(_keyAmbientPattern);
    ambientLightPattern.value = AmbientLightPattern.values.firstWhere(
      (p) => p.name == patternStr,
      orElse: () => AmbientLightPattern.dualOrbs,
    );
    ambientLightIntensity.value = prefs.getDouble(_keyAmbientIntensity) ?? 0.22;
    ambientLightSpeed.value = prefs.getDouble(_keyAmbientSpeed) ?? 1.0;

    showContinueReading.value = prefs.getBool(_keyShowContinueReading) ?? true;
    final densityStr = prefs.getString(_keyCardDensity);
    cardDensity.value = MangaCardDensity.values.firstWhere(
      (d) => d.name == densityStr,
      orElse: () => MangaCardDensity.standard,
    );
    showContentTypeBadge.value = prefs.getBool(_keyShowContentTypeBadge) ?? true;
    showMangaYear.value = prefs.getBool(_keyShowMangaYear) ?? true;
    showScrollTrack.value = prefs.getBool(_keyShowScrollTrack) ?? true;
    ambientCardGlow.value = prefs.getBool(_keyAmbientCardGlow) ?? true;

    final readModeStr = prefs.getString(_keyDefaultReadingMode);
    defaultReadingMode.value = MangaReadingMode.values.firstWhere(
      (m) => m.name == readModeStr,
      orElse: () => MangaReadingMode.webtoon,
    );

    final widthStr = prefs.getString(_keyReaderMaxWidth);
    readerMaxWidth.value = MangaReaderMaxWidth.values.firstWhere(
      (w) => w.name == widthStr,
      orElse: () => MangaReaderMaxWidth.standard,
    );

    final bgStr = prefs.getString(_keyReaderBackground);
    readerBackground.value = MangaReaderBackground.values.firstWhere(
      (b) => b.name == bgStr,
      orElse: () => MangaReaderBackground.pitchBlack,
    );

    final barStyleStr = prefs.getString(_keyReaderControlBarStyle);
    readerControlBarStyle.value = MangaControlBarStyle.values.firstWhere(
      (s) => s.name == barStyleStr,
      orElse: () => MangaControlBarStyle.floatingGlass,
    );

    showPageDeck.value = prefs.getBool(_keyShowPageDeck) ?? true;
    showPageScrubber.value = prefs.getBool(_keyShowPageScrubber) ?? true;
    enableNextChapterDeck.value = prefs.getBool(_keyEnableNextChapterDeck) ?? true;
    pageGap.value = prefs.getDouble(_keyPageGap) ?? 6.0;
  }

  // Setters
  static Future<void> setEnableAmbientLights(bool val) async {
    enableAmbientLights.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableAmbientLights, val);
  }

  static Future<void> setAmbientLightPattern(AmbientLightPattern val) async {
    ambientLightPattern.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAmbientPattern, val.name);
  }

  static Future<void> setAmbientLightIntensity(double val) async {
    ambientLightIntensity.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientIntensity, val);
  }

  static Future<void> setAmbientLightSpeed(double val) async {
    ambientLightSpeed.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAmbientSpeed, val);
  }

  static Future<void> setShowContinueReading(bool val) async {
    showContinueReading.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowContinueReading, val);
  }

  static Future<void> setCardDensity(MangaCardDensity val) async {
    cardDensity.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardDensity, val.name);
  }

  static Future<void> setShowContentTypeBadge(bool val) async {
    showContentTypeBadge.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowContentTypeBadge, val);
  }

  static Future<void> setShowMangaYear(bool val) async {
    showMangaYear.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowMangaYear, val);
  }

  static Future<void> setShowScrollTrack(bool val) async {
    showScrollTrack.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowScrollTrack, val);
  }

  static Future<void> setAmbientCardGlow(bool val) async {
    ambientCardGlow.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAmbientCardGlow, val);
  }

  static Future<void> setDefaultReadingMode(MangaReadingMode val) async {
    defaultReadingMode.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultReadingMode, val.name);
  }

  static Future<void> setReaderMaxWidth(MangaReaderMaxWidth val) async {
    readerMaxWidth.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderMaxWidth, val.name);
  }

  static Future<void> setReaderBackground(MangaReaderBackground val) async {
    readerBackground.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderBackground, val.name);
  }

  static Future<void> setReaderControlBarStyle(MangaControlBarStyle val) async {
    readerControlBarStyle.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReaderControlBarStyle, val.name);
  }

  static Future<void> setShowPageDeck(bool val) async {
    showPageDeck.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowPageDeck, val);
  }

  static Future<void> setShowPageScrubber(bool val) async {
    showPageScrubber.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowPageScrubber, val);
  }

  static Future<void> setEnableNextChapterDeck(bool val) async {
    enableNextChapterDeck.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableNextChapterDeck, val);
  }

  static Future<void> setPageGap(double val) async {
    pageGap.value = val;
    changeNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPageGap, val);
  }
}
