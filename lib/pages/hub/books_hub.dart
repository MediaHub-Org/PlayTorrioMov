import 'package:flutter/material.dart';

import '../../widgets/common/section_sub_tabs.dart';
import '../../widgets/common/sectioned_hub_scaffold.dart';
import '../../utils/hub_controller.dart';
import '../../utils/search_scope.dart';
import '../audiobooks/audiobooks_page.dart';
import '../manga/manga_page.dart';
import '../collection/books_library_page.dart';
import '../catalog/comics_page.dart';
import '../read/books_page.dart';

/// Read hub: Audiobooks, Books, Comics/Manga, and the user's library.
///
/// Sections are switched via the [SectionTopBar] — chips on tablet/desktop,
/// a dropdown on mobile. The active section is driven by the shared
/// [HubController] so navigation stays in sync.
class BooksHub extends StatelessWidget {
  const BooksHub({super.key});

  static const _readableTabs = [
    SubTab(id: 'manga', label: 'Manga', icon: Icons.auto_stories_rounded),
    SubTab(id: 'comics', label: 'Comics', icon: Icons.menu_book_rounded),
  ];

  /// Comics and Manga share one section but stay separate readers, one tap
  /// apart. See [SectionSubTabs] for why.
  static Widget _buildReadables() {
    final type = HubController.instance.readableType;
    final isComics = type == 'comics';
    SearchScope.set(isComics ? null : 'manga',
        label: isComics ? 'Comics' : 'Manga');
    return SectionSubTabs(
      tabs: _readableTabs,
      activeId: type,
      onSelected: HubController.instance.setReadableType,
      child: isComics ? const ComicsPage() : const MangaPage(),
    );
  }

  static Widget _buildSection(String activeSection) {
    switch (activeSection) {
      case 'readables':
        return _buildReadables();
      case 'books':
        SearchScope.set(null, label: 'Books');
        return const BooksPage();
      case 'audiobooks':
        SearchScope.set('audiobook', label: 'Audiobooks');
        return const AudiobooksPage();
      case 'collection':
        SearchScope.set(null, label: 'Library');
        return const BooksLibraryPage();
      default:
        SearchScope.set('audiobook', label: 'Audiobooks');
        return const AudiobooksPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionedHubScaffold(
      activeSectionOf: () => HubController.instance.booksSection,
      buildSection: _buildSection,
    );
  }
}
