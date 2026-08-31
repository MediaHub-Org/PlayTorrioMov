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

/// Global controller for the top-level navigation: which section is active,
/// and (for the Movies & Series section) which of its two sub-tabs is
/// showing. The header and the hub both read/write this so navigation stays
/// in sync.
class HubController extends ChangeNotifier {
  static final HubController instance = HubController._internal();
  HubController._internal();

  String _mediaSection = 'watch';

  // Movies and Series share one section but stay separate catalogs, one tap
  // apart. See SectionSubTabs for why.
  String _watchType = 'movie'; // 'movie' | 'series'

  String get mediaSection => _mediaSection;
  String get watchType => _watchType;

  void setWatchType(String type) {
    if (_watchType == type) return;
    _watchType = type;
    notifyListeners();
  }

  void setMediaSection(String id) {
    if (_mediaSection == id) return;
    _mediaSection = id;
    notifyListeners();
  }

  /// The Media hub's four sections, shown as chips on tablet/desktop
  /// (SectionTopBar) and as the bottom tab bar on mobile (AdaptiveNavShell).
  List<HubSection> get currentSections => const [
        HubSection(id: 'watch', label: 'Movies & Series', icon: Icons.movie_rounded),
        HubSection(id: 'anime', label: 'Anime', icon: Icons.animation_rounded),
        HubSection(id: 'iptv', label: 'Live TV', icon: Icons.live_tv_rounded),
        HubSection(id: 'collection', label: 'Library', icon: Icons.video_library_rounded),
      ];

  String get currentSectionId => _mediaSection;

  void setCurrentSection(String id) => setMediaSection(id);
}
