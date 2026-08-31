import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/books/book_library_service.dart';
import '../../services/books/book_progress_service.dart';
import '../../services/books/books_service.dart';
import 'book_reader_page.dart';
import '../../widgets/common/like_button.dart';

/// Books section in the Read hub: search libgen.li, download an epub, and
/// read it in-app. Ported/restyled from PlayTorrioV2's `books_screen.dart`.
class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final BooksService _service = BooksService();
  final TextEditingController _searchController = TextEditingController();

  List<BookResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<BookProgress> _reading = [];

  List<BookResult> _browsing = [];
  bool _isBrowsingLoading = true;

  @override
  void initState() {
    super.initState();
    BookLibraryService.instance.init();
    _loadReadingList();
    _loadBrowse();
  }

  Future<void> _toggleLike(BookResult book) async {
    await BookLibraryService.instance.toggleLike(book);
    if (mounted) setState(() {});
  }

  Future<void> _loadBrowse() async {
    final results = await _service.browseRecent();
    if (mounted) {
      setState(() {
        _browsing = results;
        _isBrowsingLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReadingList() async {
    final entries = await BookProgressService.instance.loadAll();
    if (mounted) setState(() => _reading = entries);
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _results = [];
    });
    final results = await _service.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _openDownloadDialog(BookResult book, {int resumeChapter = 0}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadDialog(
        service: _service,
        book: book,
        onFileReady: (file) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookReaderPage(
                file: file,
                title: book.title,
                bookResult: book,
                initialChapter: resumeChapter,
              ),
            ),
          ).then((_) => _loadReadingList());
        },
      ),
    );
  }

  Future<void> _resumeBook(BookProgress entry) async {
    final file = File(entry.filePath);
    if (file.existsSync() && file.lengthSync() > 1000) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookReaderPage(
            file: file,
            title: entry.book.title,
            bookResult: entry.book,
            initialChapter: entry.chapter,
          ),
        ),
      );
      _loadReadingList();
    } else {
      _openDownloadDialog(entry.book, resumeChapter: entry.chapter);
    }
  }

  Future<void> _deleteBook(BookProgress entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F121C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Book', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${entry.book.title}" and its reading progress?',
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
      await BookProgressService.instance.delete(entry.book.editionId);
      _loadReadingList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Books',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'Search books (title, author...)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF7C5CFF)),
                      onPressed: () => _search(_searchController.text),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_hasSearched) ...[
          if (_reading.isNotEmpty) ..._continueReadingSlivers(),
          ..._browseSlivers(),
        ] else if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF))),
          )
        else if (_results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No epub results found.', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BookRow(
                  book: _results[index],
                  onTap: () => _openDownloadDialog(_results[index]),
                  isLiked: BookLibraryService.instance.isLiked(_results[index].editionId),
                  onToggleLike: () => _toggleLike(_results[index]),
                ),
                childCount: _results.length,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _browseSlivers() {
    if (_isBrowsingLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.only(top: 40),
          sliver: SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF))),
          ),
        ),
      ];
    }
    if (_browsing.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.import_contacts_rounded, color: Colors.white24, size: 64),
                  SizedBox(height: 16),
                  Text('Search for a book to get started', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Recently Added',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _BookRow(
              book: _browsing[index],
              onTap: () => _openDownloadDialog(_browsing[index]),
              isLiked: BookLibraryService.instance.isLiked(_browsing[index].editionId),
              onToggleLike: () => _toggleLike(_browsing[index]),
            ),
            childCount: _browsing.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _continueReadingSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Continue Reading',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = _reading[index];
              return _ContinueReadingRow(
                entry: entry,
                onTap: () => _resumeBook(entry),
                onDelete: () => _deleteBook(entry),
              );
            },
            childCount: _reading.length,
          ),
        ),
      ),
    ];
  }
}

class _BookRow extends StatelessWidget {
  final BookResult book;
  final VoidCallback onTap;
  final bool isLiked;
  final VoidCallback onToggleLike;

  const _BookRow({
    required this.book,
    required this.onTap,
    required this.isLiked,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C5CFF), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (book.author.isNotEmpty) book.author,
                          if (book.year.isNotEmpty) book.year,
                          if (book.size.isNotEmpty) book.size,
                        ].join(' · '),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                LikeButton(
                  isLiked: isLiked,
                  onTap: onToggleLike,
                  style: LikeButtonStyle.icon,
                  size: 20,
                ),
                const Icon(Icons.download_rounded, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingRow extends StatelessWidget {
  final BookProgress entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ContinueReadingRow({required this.entry, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF7C5CFF), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.book.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Chapter ${entry.chapter + 1}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  final BooksService service;
  final BookResult book;
  final void Function(File file) onFileReady;

  const _DownloadDialog({required this.service, required this.book, required this.onFileReady});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  String _status = 'Resolving download link...';
  bool _failed = false;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final filePath = await BookProgressService.instance.bookFilePath(widget.book.editionId);
      final cacheFile = File(filePath);
      if (cacheFile.existsSync() && cacheFile.lengthSync() > 1000) {
        if (mounted) widget.onFileReady(cacheFile);
        return;
      }

      if (mounted) setState(() => _status = 'Resolving download link...');
      final downloadUrl = await widget.service.resolveDownloadUrl(widget.book.editionId);
      if (downloadUrl == null) {
        if (mounted) {
          setState(() {
            _status = 'Could not resolve download link. Try again later.';
            _failed = true;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'Downloading...';
          _downloadProgress = 0;
        });
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      final total = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
      }

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _status = 'Download failed (HTTP ${response.statusCode})';
            _failed = true;
          });
        }
        return;
      }

      if (mounted) setState(() => _status = 'Opening book...');
      await cacheFile.writeAsBytes(bytes);
      if (mounted) widget.onFileReady(cacheFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F121C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: Color(0xFF7C5CFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.book.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_downloadProgress != null) ...[
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.white12,
              color: const Color(0xFF7C5CFF),
            ),
            const SizedBox(height: 12),
          ] else if (!_failed) ...[
            const CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            const SizedBox(height: 12),
          ],
          Text(_status, style: TextStyle(color: _failed ? Colors.redAccent : Colors.white70, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_failed ? 'Close' : 'Cancel', style: const TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
