import 'package:flutter/material.dart';

/// A single section within the Media hub (Movies & Series, Anime, Live TV,
/// Library).
class HubSection {
  final String id;
  final String label;
  final IconData icon;

  const HubSection({
    required this.id,
    required this.label,
    required this.icon,
  });
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
        HubSection(id: 'movies', label: 'Movies', icon: Icons.theaters_rounded),
        HubSection(id: 'series', label: 'Series', icon: Icons.tv_rounded),
        HubSection(id: 'anime', label: 'Anime', icon: Icons.animation_rounded),
        HubSection(id: 'iptv', label: 'Live TV', icon: Icons.live_tv_rounded),
        HubSection(id: 'collection', label: 'Library', icon: Icons.video_library_rounded),
      ];

  String get currentSectionId => _mediaSection;

  void setCurrentSection(String id) => setMediaSection(id);
}
