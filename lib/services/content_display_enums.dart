/// Shared display-style enums used across the per-content-type settings
/// services (audiobook/music/manga/iptv "player studio" customization).
/// Extracted out of the old `home_page_settings.dart` (removed along with
/// the old HomePage/LiquidDock navigation this app no longer uses) since
/// these enums themselves are generic display styling, not tied to that
/// removed page.
library;

enum HeroStyle {
  immersive('Immersive Cinematic Carousel'),
  compact('Compact Spotlight'),
  minimalist('Minimalist Header');

  final String label;
  const HeroStyle(this.label);
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
  compact('Compact (Dense Grid)'),
  standard('Standard Balanced'),
  cinematic('Cinematic (Large Posters)');

  final String label;
  const CardDensity(this.label);
}
