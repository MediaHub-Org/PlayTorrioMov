/// Single source of truth for how the app names itself to the user.
///
/// Every user-visible occurrence of the app's name should read from here --
/// the window/task-switcher title, the header wordmark, the splash screen,
/// Settings, and the updater. Before this existed the string was duplicated
/// across those files, so a rename meant hunting literals and missing some.
///
/// Deliberately NOT the place for two other things that merely look like the
/// app's name:
///
///  * **Stream source identifiers** -- `'PlayTorrio'` and `'PlayTorrioHTTP'`
///    are the built-in scrapers' `name`/`addonName`. They are compared against
///    in `StreamScraper` (to gate P2P) and in `ContinueWatchingService`, and
///    they are *persisted* inside saved continue-watching entries. Renaming
///    them would strand every saved resume point, so they stay literals.
///  * **Executable and bundle names** -- the Windows/Linux `BINARY_NAME`, the
///    macOS `PRODUCT_NAME` and the platform bundle identifiers are build
///    inputs baked into installers and packaging scripts, not display
///    strings. They read `PlayTorrioMod` / `com.mediahub.playtorriomod` to
///    match, but changing them means changing the packaging in step, so they
///    are not driven from here.
abstract final class AppInfo {
  /// The app's display name. Shown wherever the product names itself.
  static const String name = 'PlayTorrioMod';

  /// The subtitle under [name] on the splash screen.
  static const String tagline = 'Your Cinema Universe';

  /// Build channel, appended in parentheses wherever the version is shown.
  ///
  /// The releases are ordinary semver versions -- `1.1.3`, not
  /// `1.1.3-alpha.1` -- but nothing here has been through device testing yet,
  /// so every build says so. Set this to an empty string when a release has
  /// actually been verified on hardware and the marker should disappear.
  static const String channel = 'dev';

  /// Whether this build carries a channel marker. Handy for showing a badge
  /// without string-comparing [channel] at each call site.
  static bool get isPrerelease => channel.isNotEmpty;

  /// Version fallback used when `package_info_plus` cannot read the platform
  /// bundle (which happens in tests and on some desktop launch paths).
  ///
  /// Kept in step with `pubspec.yaml` by a test, so it can never drift into
  /// reporting a version the app has not been at for several releases.
  static const String fallbackVersion = '1.1.3';

  /// Build-number counterpart to [fallbackVersion].
  static const String fallbackBuildNumber = '11';

  /// Renders a version for display: `1.1.3` on a stable build, `1.1.3 (dev)`
  /// on a channel build. Every user-visible version string goes through here
  /// so the marker cannot be shown in one screen and missed in another.
  static String versionLabel(String? version) {
    final v = (version == null || version.isEmpty) ? fallbackVersion : version;
    return channel.isEmpty ? v : '$v ($channel)';
  }
}
