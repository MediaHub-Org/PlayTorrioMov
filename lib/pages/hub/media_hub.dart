import 'package:flutter/material.dart';

import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../anime/anime_page.dart';
import '../collection/collection_page.dart';
import '../catalog/type_catalog_page.dart';
import '../iptv/iptv_page.dart';

/// Watch hub: Movies/Series, Anime, Live TV, and the user's library.
///
/// Movies and Series share one section but stay separate catalogs, one tap
/// apart. The type pills render inside TypeCatalogPage itself, beside its
/// other filter controls -- this just owns which type is active.
///
/// Sections are switched via the [SectionTopBar] — chips on tablet/desktop,
/// a bottom tab bar on mobile. The active section is driven by the shared
/// [HubController] so navigation stays in sync.
class MediaHub extends StatelessWidget {
  const MediaHub({super.key});

  static Widget _buildWatch() {
    final type = HubController.instance.watchType;
    final isSeries = type == 'series';
    SearchScope.set(
      isSeries ? 'series' : 'movie',
      label: isSeries ? 'Series' : 'Movies',
    );
    return isSeries
        ? TypeCatalogPage(
            key: const ValueKey('series'),
            type: 'series',
            title: 'Series',
            onTypeChanged: HubController.instance.setWatchType,
          )
        : TypeCatalogPage(
            key: const ValueKey('movie'),
            type: 'movie',
            title: 'Movies',
            onTypeChanged: HubController.instance.setWatchType,
          );
  }

  static Widget _buildSection(String activeSection) {
    switch (activeSection) {
      case 'watch':
        return _buildWatch();
      case 'anime':
        SearchScope.set('anime', label: 'Anime');
        return const AnimePage();
      case 'iptv':
        SearchScope.set('iptv', label: 'Live TV');
        return const IptvPage();
      case 'collection':
        SearchScope.set(null, label: 'Library');
        return const CollectionPage();
      default:
        return _buildWatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionedHubScaffold(
      activeSectionOf: () => HubController.instance.mediaSection,
      buildSection: _buildSection,
    );
  }
}
