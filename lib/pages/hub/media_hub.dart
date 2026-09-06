import 'package:flutter/material.dart';

import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../anime/anime_page.dart';
import '../collection/collection_page.dart';
import '../catalog/type_catalog_page.dart';
import '../iptv/iptv_page.dart';

/// Media hub: Movies, Series, Anime, Live TV, and the user's library.
///
/// Sections are switched via the [SectionTopBar] — chips on tablet/desktop,
/// a bottom tab bar on mobile. The active section is driven by the shared
/// [HubController] so navigation stays in sync.
class MediaHub extends StatelessWidget {
  const MediaHub({super.key});

  static Widget _buildSection(String activeSection) {
    switch (activeSection) {
      case 'movies':
        SearchScope.set('movie', label: 'Movies');
        return const TypeCatalogPage(
          key: ValueKey('movie'),
          type: 'movie',
          title: 'Movies',
        );
      case 'series':
        SearchScope.set('series', label: 'Series');
        return const TypeCatalogPage(
          key: ValueKey('series'),
          type: 'series',
          title: 'Series',
        );
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
        SearchScope.set('movie', label: 'Movies');
        return const TypeCatalogPage(
          key: ValueKey('movie'),
          type: 'movie',
          title: 'Movies',
        );
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
