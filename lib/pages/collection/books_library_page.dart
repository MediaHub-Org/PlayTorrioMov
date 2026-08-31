import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/audiobook/audiobook_model.dart';
import '../../models/download/download_task_model.dart';
import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/audiobook/audiobook_library_service.dart';
import '../../services/audiobook/audiobook_player_controller.dart';
import '../../services/audiobook/audiobook_progress_service.dart';
import '../../services/books/book_library_service.dart';
import '../../services/books/book_progress_service.dart';
import '../../services/books/books_service.dart';
import '../../services/download/download_service.dart';
import '../../services/manga/manga_service.dart';
import '../../widgets/common/library_sections.dart';
import '../../widgets/common/library_tabs.dart';
import '../../widgets/common/section_sub_tabs.dart';
import '../../widgets/manga/manga_card.dart';
import '../audiobooks/audiobook_detail_page.dart';
import '../audiobooks/audiobook_route_transitions.dart';
import '../manga/manga_details_page.dart';
import '../manga/manga_reader_page.dart';
import '../read/book_reader_page.dart';
import '../../utils/navigation/route_transitions.dart';

/// The Read hub's Library.
///
/// Carries the same four tabs as every other hub (see [LibrarySection]). The
/// three content types it holds -- audiobooks, books, manga -- are a sub-tab
/// inside Saved rather than three top-level tabs, which is what used to make
/// this Library five tabs wide while Watch's was four.
class BooksLibraryPage extends StatefulWidget {
  const BooksLibraryPage({super.key});

  @override
  State<BooksLibraryPage> createState() => _BooksLibraryPageState();
}

class _BooksLibraryPageState extends State<BooksLibraryPage> {
  final MangaService _mangaService = MangaService();
  List<Manga> _likedManga = [];
  bool _loadingManga = true;

  List<_HistoryEntry> _historyEntries = [];
  bool _loadingHistory = true;

  /// Which content type Saved is showing.
  String _savedType = 'audiobooks';

  /// Anything past this counts as finished, so it drops out of Continue and
  /// stays only in History. Readers rarely close a book on the exact last
  /// page, so the threshold is short of 100%.
  static const double _finishedAt = 0.95;

  List<_HistoryEntry> get _inProgressEntries => _historyEntries
      .where((e) => e.progress != null && e.progress! < _finishedAt)
      .toList();

  @override
  void initState() {
    super.initState();
    AudiobookLibraryService.instance.init();
    BookLibraryService.instance.init();
    _loadLikedManga();
    _loadHistory();
  }

  Future<void> _openLikedBook(BookResult book) async {
    final progress = await BookProgressService.instance.loadAll();
    if (!mounted) return;
    final entry = progress.where((p) => p.book.editionId == book.editionId).firstOrNull;
    if (entry != null && File(entry.filePath).existsSync() && File(entry.filePath).lengthSync() > 1000) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookReaderPage(
            file: File(entry.filePath),
            title: book.title,
            bookResult: book,
            initialChapter: entry.chapter,
          ),
        ),
      );
      _loadHistory();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search for "${book.title}" in Books to download it.')),
      );
    }
  }

  Future<void> _loadLikedManga() async {
    final liked = await _mangaService.getLikedManga();
    if (mounted) {
      setState(() {
        _likedManga = liked;
        _loadingManga = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final results = await Future.wait([
      AudiobookProgressService.instance.getAllProgress(),
      BookProgressService.instance.loadAll(),
      _mangaService.getReadingHistory(),
    ]);
    final audiobooks = results[0] as List<AudiobookProgress>;
    final books = results[1] as List<BookProgress>;
    final manga = results[2] as List<Map<String, dynamic>>;

    final entries = <_HistoryEntry>[
      for (final p in audiobooks) _historyEntryFromAudiobook(p),
      for (final b in books) _historyEntryFromBook(b),
      for (final m in manga) _historyEntryFromManga(m),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _historyEntries = entries;
        _loadingHistory = false;
      });
    }
  }

  _HistoryEntry _historyEntryFromAudiobook(AudiobookProgress p) {
    final percent = p.durationMs > 0 ? p.positionMs / p.durationMs : null;
    return _HistoryEntry(
      title: p.audiobook.title,
      coverUrl: p.audiobook.coverImage.isNotEmpty ? p.audiobook.coverImage : null,
      fallbackIcon: Icons.headphones_rounded,
      subtitle: percent != null ? '${(percent * 100).toInt()}% listened' : 'Listening',
      progress: percent,
      timestamp: DateTime.fromMillisecondsSinceEpoch(p.lastListenedTimestamp),
      onTap: () {
        AudiobookPlayerController.instance.play(
          p.audiobook,
          p.chapters,
          chapterIndex: p.chapterIndex,
          initialPosition: Duration(milliseconds: p.positionMs),
        );
      },
      onDelete: () async {
        await AudiobookProgressService.instance.removeProgress(p.key);
        _loadHistory();
      },
    );
  }

  _HistoryEntry _historyEntryFromBook(BookProgress p) {
    return _HistoryEntry(
      title: p.book.title,
      coverUrl: null,
      fallbackIcon: Icons.menu_book_rounded,
      subtitle: 'Chapter ${p.chapter + 1}',
      progress: null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(p.lastReadTimestamp),
      onTap: () async {
        final file = File(p.filePath);
        if (file.existsSync() && file.lengthSync() > 1000) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookReaderPage(
                file: file,
                title: p.book.title,
                bookResult: p.book,
                initialChapter: p.chapter,
              ),
            ),
          );
          _loadHistory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File no longer available — redownload from Books.')),
          );
        }
      },
      onDelete: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F121C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Book', style: TextStyle(color: Colors.white)),
            content: Text(
              'Delete "${p.book.title}" and its reading progress?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await BookProgressService.instance.delete(p.book.editionId);
          _loadHistory();
        }
      },
    );
  }

  _HistoryEntry _historyEntryFromManga(Map<String, dynamic> entry) {
    final manga = Manga.fromJson(entry['manga']);
    final chapterIndex = entry['chapterIndex'] as int;
    final pageIndex = entry['pageIndex'] as int;
    final chapters = (entry['chapters'] as List).map((c) => MangaChapter.fromJson(c)).toList();
    final percent = chapters.isNotEmpty ? (chapterIndex + 1) / chapters.length : null;
    return _HistoryEntry(
      title: manga.title,
      coverUrl: manga.coverSmall.isNotEmpty ? manga.coverSmall : null,
      fallbackIcon: Icons.auto_stories_rounded,
      subtitle: chapters.isNotEmpty
          ? 'Chapter ${chapterIndex + 1} of ${chapters.length}'
          : 'Chapter ${chapterIndex + 1}',
      progress: percent,
      timestamp: DateTime.tryParse(entry['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MangaReaderPage(
              manga: manga,
              chapters: chapters,
              currentChapterIndex: chapterIndex,
              resumePageIndex: pageIndex,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      onDelete: () async {
        await _mangaService.removeHistory(manga.id);
        _loadHistory();
      },
    );
  }

  void _openManga(Manga manga) {
    Navigator.push(
      context,
      LiquidRevealRoute(page: MangaDetailsPage(manga: manga), tapPosition: null),
    ).then((_) => _loadLikedManga());
  }

  void _openAudiobook(Audiobook book) {
    Navigator.push(
      context,
      AudiobookPageRoute(page: AudiobookDetailPage(audiobook: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingManga || _loadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
      );
    }

    return LibraryTabs(
      title: 'Library',
      titleIcon: Icons.collections_bookmark_rounded,
      tabs: [
        for (final section in LibrarySection.values)
          LibraryTab(
            label: section.label,
            icon: section.icon,
            builder: (_) => switch (section) {
              LibrarySection.saved => _buildSavedTab(),
              LibrarySection.inProgress => _buildInProgressTab(),
              LibrarySection.history => _buildHistoryTab(),
              LibrarySection.downloads => _buildDownloadsTab(),
            },
          ),
      ],
    );
  }

  Widget _buildSavedTab() {
    return SectionSubTabs(
      activeId: _savedType,
      onSelected: (id) => setState(() => _savedType = id),
      tabs: const [
        SubTab(
          id: 'audiobooks',
          label: 'Audiobooks',
          icon: Icons.headphones_rounded,
        ),
        SubTab(
          id: 'books',
          label: 'Books',
          icon: Icons.import_contacts_rounded,
        ),
        SubTab(id: 'manga', label: 'Manga', icon: Icons.auto_stories_rounded),
      ],
      child: switch (_savedType) {
        'books' => _buildBooksTab(),
        'manga' => _buildMangaTab(),
        _ => _buildAudiobooksTab(),
      },
    );
  }

  Widget _buildDownloadsTab() {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadService.instance.tasksNotifier,
      builder: (context, allDownloads, _) {
        final downloads = allDownloads.where((t) => t.type == 'audiobook').toList();
        if (downloads.isEmpty) {
          return const LibraryEmptyState(
            icon: Icons.download_done_rounded,
            title: 'No Downloads',
            subtitle: 'Downloaded audiobook chapters will appear here for offline listening.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: downloads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = downloads[index];
            final progress = item.totalBytes > 0 ? item.receivedBytes / item.totalBytes : 0.0;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.posterUrl != null
                        ? Image.network(
                            item.posterUrl!,
                            width: 50,
                            height: 75,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 75,
                              color: Colors.white10,
                              child: const Icon(Icons.headphones_rounded, color: Colors.white30),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 75,
                            color: Colors.white10,
                            child: const Icon(Icons.headphones_rounded, color: Colors.white30),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C5CFF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.status.name.toUpperCase()} • ${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => DownloadService.instance.deleteDownload(item.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMangaTab() {
    if (_likedManga.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.auto_stories_rounded,
        title: 'No liked manga',
        subtitle: 'Tap the heart on a manga to save it here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        mainAxisExtent: 300,
      ),
      itemCount: _likedManga.length,
      itemBuilder: (context, index) {
        final manga = _likedManga[index];
        return MangaCard(manga: manga, onTap: () => _openManga(manga));
      },
    );
  }

  Widget _buildAudiobooksTab() {
    final liked = AudiobookLibraryService.instance.liked;
    if (liked.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.headphones_rounded,
        title: 'No liked audiobooks',
        subtitle: 'Tap the heart on an audiobook to save it here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        mainAxisExtent: 300,
      ),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        final book = liked[index];
        return _LikedAudiobookCard(book: book, onTap: () => _openAudiobook(book));
      },
    );
  }

  Widget _buildBooksTab() {
    final liked = BookLibraryService.instance.liked;
    if (liked.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.import_contacts_rounded,
        title: 'No liked books',
        subtitle: 'Tap the heart on a book to save it here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
        mainAxisExtent: 300,
      ),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        final book = liked[index];
        return _LikedBookCard(book: book, onTap: () => _openLikedBook(book));
      },
    );
  }

  /// Started but not finished. Same store as History, filtered on progress --
  /// there is only one reading log, and splitting it in the service would be
  /// a migration for a distinction the UI can make for free.
  Widget _buildInProgressTab() {
    final entries = _inProgressEntries;
    if (entries.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'Nothing in progress',
        subtitle: 'Audiobooks, books and manga you are partway through wait '
            'for you here.',
      );
    }
    return _entryList(entries);
  }

  Widget _buildHistoryTab() {
    if (_historyEntries.isEmpty) {
      return const LibraryEmptyState(
        icon: Icons.history_rounded,
        title: 'No reading history',
        subtitle: 'Everything you open is logged here, finished or not.',
      );
    }
    return _entryList(_historyEntries);
  }

  Widget _entryList(List<_HistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return GestureDetector(
          onTap: entry.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: entry.coverUrl != null
                      ? Image.network(
                          entry.coverUrl!,
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 75,
                            color: Colors.white10,
                            child: Icon(entry.fallbackIcon, color: Colors.white30),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 75,
                          color: Colors.white10,
                          child: Icon(entry.fallbackIcon, color: Colors.white30),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (entry.progress != null) ...[
                        LinearProgressIndicator(
                          value: entry.progress!.clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C5CFF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        entry.subtitle,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                  onPressed: entry.onDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEntry {
  final String title;
  final String? coverUrl;
  final IconData fallbackIcon;
  final String subtitle;
  final double? progress;
  final DateTime timestamp;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryEntry({
    required this.title,
    required this.coverUrl,
    required this.fallbackIcon,
    required this.subtitle,
    required this.progress,
    required this.timestamp,
    required this.onTap,
    required this.onDelete,
  });
}

class _LikedAudiobookCard extends StatelessWidget {
  final Audiobook book;
  final VoidCallback onTap;

  const _LikedAudiobookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCover = book.coverImage.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: hasCover
                  ? Image.network(
                      book.coverImage,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF141824),
                        child: const Icon(Icons.headphones_rounded,
                            color: Colors.white24, size: 40),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF141824),
                      child: const Icon(Icons.headphones_rounded,
                          color: Colors.white24, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LikedBookCard extends StatelessWidget {
  final BookResult book;
  final VoidCallback onTap;

  const _LikedBookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFF141824),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white24, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
