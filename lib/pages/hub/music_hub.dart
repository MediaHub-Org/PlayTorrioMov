import 'package:flutter/material.dart';

import '../../utils/search_scope.dart';
import '../music/music_page.dart';

/// Listen hub: hosts [MusicPage], which owns its own section switching
/// (Music/Search/Radio/Podcasts/Library) plus ambient background, keyboard
/// shortcuts, and drawer/modal overlays -- a genuinely different shell shape
/// than [SectionedHubScaffold], not a copy of it. Genre browsing lives inline
/// inside the Music tab, not as its own top-level section.
class MusicHub extends StatelessWidget {
  const MusicHub({super.key});

  @override
  Widget build(BuildContext context) {
    SearchScope.set('music', label: 'Music');
    return const MusicPage();
  }
}
