import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A single section within the Media hub (Movies & Series, Anime, Live TV,
/// Library).
class HubSection {
  final String id;

  /// English fallback -- used if a [BuildContext] isn't available. Prefer
  /// [localizedLabel] wherever one is (every actual render site has one).
  final String label;

  final IconData icon;

  const HubSection({
    required this.id,
    required this.label,
    required this.icon,
  });

  /// The label to render, translated (#68). [HubController.currentSections]
  /// is `const`, so it cannot hold a context-dependent string itself --
  /// this resolves it at the point of display instead.
  ///
  /// Falls back to [label] when no [AppLocalizations] delegate is in scope
  /// -- deliberately `Localizations.of` directly rather than the generated
  /// `AppLocalizations.of`, which (via this app's `nullable-getter: false`
  /// in l10n.yaml) force-unwraps and throws instead of returning null.
  /// Several existing widget tests pump this widget in a bare `MaterialApp`
  /// with no localization delegates registered, same as any real screen
  /// this widget hasn't been retrofitted into yet.
  String localizedLabel(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l10n == null) return label;
    return switch (id) {
      'movies' => l10n.navMovies,
      'series' => l10n.navSeries,
      'anime' => l10n.navAnime,
      'iptv' => l10n.navLiveTv,
      'collection' => l10n.navLibrary,
      _ => label,
    };
  }
}

/// Global controller for the top-level navigation: which section is active.
/// The header and the hub both read/write this so navigation stays in sync.
class HubController extends ChangeNotifier {
  static final HubController instance = HubController._internal();
  HubController._internal();

  String _mediaSection = 'movies';

  String get mediaSection => _mediaSection;

  void setMediaSection(String id) {
    if (_mediaSection == id) return;
    _mediaSection = id;
    notifyListeners();
  }

  /// The Media hub's five sections, shown as chips on tablet/desktop
  /// (SectionTopBar) and as the bottom tab bar on mobile (AdaptiveNavShell).
  List<HubSection> get currentSections => const [
        HubSection(id: 'movies', label: 'Films', icon: Icons.theaters_rounded),
        HubSection(id: 'series', label: 'Series', icon: Icons.tv_rounded),
        HubSection(id: 'anime', label: 'Anime', icon: Icons.animation_rounded),
        HubSection(id: 'iptv', label: 'Live TV', icon: Icons.live_tv_rounded),
        HubSection(id: 'collection', label: 'Library', icon: Icons.video_library_rounded),
      ];

  String get currentSectionId => _mediaSection;

  void setCurrentSection(String id) => setMediaSection(id);
}
