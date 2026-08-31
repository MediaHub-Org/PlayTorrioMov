import 'package:flutter/material.dart';

import '../../widgets/common/section_sub_tabs.dart';
import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../anime/anime_page.dart';
import '../collection/collection_page.dart';
import '../catalog/type_catalog_page.dart';
import '../iptv/iptv_page.dart';

/// Watch hub: Movies/Series, Anime, Live TV, and the user's library.
///
/// Sections are switched via the [SectionTopBar] — chips on tablet/desktop,
/// a dropdown on mobile. The active section is driven by the shared
/// [HubController] so navigation stays in sync.
class MediaHub extends StatelessWidget {
  const MediaHub({super.key});

  static const _watchTabs = [
    SubTab(id: 'movie', label: 'Movies', icon: Icons.movie_rounded),
    SubTab(id: 'series', label: 'Series', icon: Icons.live_tv_rounded),
  ];

  /// Movies and Series share one section but stay separate catalogs, one tap
  /// apart. See [SectionSubTabs] for why.
  static Widget _buildWatch() {
    final type = HubController.instance.watchType;
    final isSeries = type == 'series';
    SearchScope.set(
      isSeries ? 'series' : 'movie',
      label: isSeries ? 'Series' : 'Movies',
    );
    return SectionSubTabs(
      tabs: _watchTabs,
      activeId: type,
      onSelected: HubController.instance.setWatchType,
      child: isSeries
          ? const TypeCatalogPage(
              key: ValueKey('series'),
              type: 'series',
              title: 'Series',
            )
          : const TypeCatalogPage(
              key: ValueKey('movie'),
              type: 'movie',
              title: 'Movies',
            ),
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
