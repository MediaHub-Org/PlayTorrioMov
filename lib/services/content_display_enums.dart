/// Shared display-style enums used across the per-content-type settings
/// services (audiobook/music/manga/iptv "player studio" customization).
/// Extracted out of the old `home_page_settings.dart` (removed along with
/// the old HomePage/LiquidDock navigation this app no longer uses) since
/// these enums themselves are generic display styling, not tied to that
/// removed page.
library;

import '../l10n/app_localizations.dart';

enum HeroStyle {
  immersive,
  compact,
  minimalist;

  /// The chip text, in the app's language.
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    HeroStyle.immersive => l10n.liveTvHeroImmersive,
    HeroStyle.compact => l10n.liveTvHeroCompact,
    HeroStyle.minimalist => l10n.liveTvHeroMinimalist,
  };
}

enum AmbientLightPattern {
  dualOrbs('Dual Floating Orbs'),
  topAurora('Top Aurora Horizon'),
  fullMesh('Full Deep Ambient Mesh'),
  centerPulse('Pulsing Core');

  final String label;
  const AmbientLightPattern(this.label);
}

enum CardDensity {
  compact,
  standard,
  cinematic;

  /// The chip text, in the app's language.
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    CardDensity.compact => l10n.liveTvDensityCompact,
    CardDensity.standard => l10n.liveTvDensityStandard,
    CardDensity.cinematic => l10n.liveTvDensityCinematic,
  };
}
