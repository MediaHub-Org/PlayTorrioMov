// Sizes the two details pages share, in rem (one rem is 16 px at the default
// text size; see `AppUnits`). Read through `context.rem(DetailsSpace.md)`.
//
// `DetailsPage` and `AnimeDetailsPage` were one layout written twice, and
// each kept its own copy of these numbers. They are one set now, so the two
// pages cannot drift apart on the poster, the page gutter or the play button.

/// Spacing between blocks.
abstract final class DetailsSpace {
  static const xs = 0.5;
  static const sm = 0.75;
  static const md = 1.0;
  static const lg = 1.5;
  static const xl = 2.0;
  static const xxl = 3.0;
}

/// The rest of the shared sizes: poster widths, glow and shadow blurs, logo
/// caps, rail heights, fade widths and the episode card.
abstract final class DetailsDim {
  static const backButton = 2.75; // the floating back button's footprint
  static const errorIcon = 4.0;
  static const spinnerPadding = 2.5;
  static const desktopPoster = 17.5;
  static const mobilePoster = 6.875;
  static const posterRadius = 0.875;
  static const glowBlur = 2.875;
  static const glowSpread = 0.375;
  static const posterShadowBlur = 1.875;
  static const posterShadowLift = 0.875;
  static const mobileGlowBlur = 1.75;
  static const logoWidthDesktop = 23.75;
  static const logoWidthMobile = 13.75;
  static const logoHeightDesktop = 8.125;
  static const logoHeightMobile = 5.0;
  static const ratingPadX = 0.4375;
  static const ratingPadY = 0.1875;
  static const ratingRadius = 0.3125;
  static const ratingStar = 0.875;
  static const synopsisWidth = 45.0;
  static const creditsHeight = 9.25;
  static const railArrowTop = 0.625;
  static const railArrowBottom = 2.5;
  static const seasonPadX = 1.375;
  static const seasonRadius = 1.375;
  static const episodeWidthDesktop = 18.75;
  static const episodeWidthMobile = 14.375;
  static const episodeRailDesktop = 17.1875;
  static const episodeRailMobile = 15.3125;
  static const fadeDesktop = 3.75;
  static const fadeMobile = 2.5;
  static const fadeOverlap = 0.625;
  static const similarArrowBottom = 3.75;
  static const arrowSize = 2.625;
  static const playGlyphPad = 0.625;
  static const episodeRadius = 0.75;
  static const episodeShadowBlur = 1.125;
  static const contentMaxWidth = 90.0;
}
