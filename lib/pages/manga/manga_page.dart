import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/manga/manga_service.dart';
import '../../services/manga/manga_settings.dart';
import '../../widgets/common/custom_scroll_track.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/page_search_button.dart';
import '../../widgets/common/slider_arrow.dart';
import '../../widgets/manga/manga_card.dart';
import '../settings/appearance/manga_settings_page.dart';
import 'manga_reader_page.dart';

class MangaPage extends StatefulWidget {
  const MangaPage({super.key});

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  // Static cache to preserve state across navigations
  static List<Manga>? _cachedMangaList;
  static List<Map<String, dynamic>>? _cachedReadingHistory;
  static int _cachedCurrentPage = 1;
  static String _cachedSearchQuery = '';
  static double _cachedScrollOffset = 0.0;

  final MangaService _mangaService = MangaService();
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Manga> _mangaList = [];
  List<Map<String, dynamic>> _readingHistory = [];
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  String _searchQuery = '';
  
  // Track grid layout dimensions
  late double _screenWidth;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _cachedScrollOffset);
    _searchController.text = _cachedSearchQuery;
    
    MangaSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);

    if (_cachedMangaList != null && _cachedReadingHistory != null) {
      _mangaList = _cachedMangaList!;
      _readingHistory = _cachedReadingHistory!;
      _currentPage = _cachedCurrentPage;
      _searchQuery = _cachedSearchQuery;
      // Refresh reading history in background silently
      _mangaService.getReadingHistory().then((history) {
        if (mounted) {
          setState(() {
            _readingHistory = history;
            _cachedReadingHistory = history;
          });
        }
      });
    } else {
      _isLoading = true;
      _loadInitialData();
    }
    
    MangaService.readingHistoryRevision.addListener(_loadHistory);
    _scrollController.addListener(_onScroll);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    MangaSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    MangaService.readingHistoryRevision.removeListener(_loadHistory);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _cachedScrollOffset = _scrollController.offset;
    }
    if (_isLoading || _isLoadingMore) return;
    
    // If we're within 800 pixels of the bottom, load more
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    final history = await _mangaService.getReadingHistory();
    if (mounted) {
      setState(() {
        _readingHistory = history;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
      _mangaList.clear();
    });

    try {
      final results = await Future.wait([
        _searchQuery.isEmpty
            ? _mangaService.getManga(page: _currentPage)
            : _mangaService.searchManga(_searchQuery, page: _currentPage),
        _mangaService.getReadingHistory(),
      ]);

      if (mounted) {
        setState(() {
          _mangaList = results[0] as List<Manga>;
          _readingHistory = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;

          _cachedMangaList = _mangaList;
          _cachedReadingHistory = _readingHistory;
          _cachedCurrentPage = _currentPage;
          _cachedSearchQuery = _searchQuery;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);

    _currentPage++;
    try {
      final newManga = _searchQuery.isEmpty
          ? await _mangaService.getManga(page: _currentPage)
          : await _mangaService.searchManga(_searchQuery, page: _currentPage);

      if (mounted) {
        setState(() {
          _mangaList.addAll(newManga);
          _isLoadingMore = false;

          _cachedMangaList = _mangaList;
          _cachedCurrentPage = _currentPage;
        });
      }
    } catch (e) {
      _currentPage--;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _resumeReading(Map<String, dynamic> historyEntry) {
    final mangaJson = historyEntry['manga'];
    final manga = Manga.fromJson(mangaJson);
    final chapterIndex = historyEntry['chapterIndex'] as int;
    final pageIndex = historyEntry['pageIndex'] as int;
    final chaptersList = (historyEntry['chapters'] as List).map((c) => MangaChapter.fromJson(c)).toList();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MangaReaderPage(
          manga: manga,
          chapters: chaptersList,
          currentChapterIndex: chapterIndex,
          resumePageIndex: pageIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showMangaCustomizer(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF10131C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: palette.primaryColor, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Customize Manga Section',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  const Text(
                    'Poster Card Density',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<MangaCardDensity>(
                    valueListenable: MangaSettings.cardDensity,
                    builder: (context, density, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MangaCardDensity.values.map((d) {
                          final isSelected = d == density;
                          return ChoiceChip(
                            label: Text(d.label),
                            selected: isSelected,
                            selectedColor: palette.primaryColor.withValues(alpha: 0.25),
                            backgroundColor: const Color(0xFF0D1017),
                            labelStyle: TextStyle(
                              color: isSelected ? palette.primaryColor : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? palette.primaryColor.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            onSelected: (selected) {
                              if (selected) MangaSettings.setCardDensity(d);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.enableAmbientLights,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Moving Ambient Background Glow', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: enabled,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setEnableAmbientLights(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.showContinueReading,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show "Continue Reading" Slider', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: show,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setShowContinueReading(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: MangaSettings.showContentTypeBadge,
                    builder: (context, show, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Content Type Badge on Posters', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        value: show,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => MangaSettings.setShowContentTypeBadge(val),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primaryColor.withValues(alpha: 0.15),
                        foregroundColor: palette.primaryColor,
                        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text('More Appearance & Reader Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MangaSettingsPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.sizeOf(context).width;

    final showScrollTrack = MangaSettings.showScrollTrack.value;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: LiquidGlassView(
        pixelRatio: 0.25,
        refreshRate: LiquidGlassRefreshRate.low,
        backgroundWidget: _buildScrollableContent(),
        child: Stack(
          children: [
            // Custom Scroll Track (Desktop only)
            if (_screenWidth > 800 && showScrollTrack)
              Positioned(
                right: 24,
                bottom: 40,
                child: CustomScrollTrack(controller: _scrollController),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    // Guard against being laid out offstage with a zero width (e.g. inside an
    // IndexedStack before it is shown). A SliverGrid asserts
    // `crossAxisExtent > 0`, so showing the empty state avoids a crash.
    final density = MangaSettings.cardDensity.value;
    final sizing = _screenWidth > 0
        ? MangaCardSizing.fromWidth(_screenWidth, density: density)
        : null;
    final showContinue = MangaSettings.showContinueReading.value;
    final isMobile = _screenWidth < 600;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: 100), // Spacer for top bar
        ),
        
        // ── Continue Reading ──
        if (showContinue && _readingHistory.isNotEmpty && _searchQuery.isEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 32.0,
                vertical: isMobile ? 12.0 : 16.0,
              ),
              child: Text(
                'Continue Reading',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContinueReadingSlider(
              readingHistory: _readingHistory,
              onResume: _resumeReading,
              screenWidth: _screenWidth,
              isMobile: isMobile,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: isMobile ? 24 : 40),
          ),
        ],

        // ── Discovery / Search Results ──
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 32.0,
              vertical: isMobile ? 12.0 : 16.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'Search Results' : 'Discover Manga',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                  tooltip: 'Customize Manga Section',
                  onPressed: () => _showMangaCustomizer(context),
                ),
                const PageSearchButton(),
              ],
            ),
          ),
        ),
        
        if (_isLoading && _mangaList.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        else if (_errorMessage != null && _mangaList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              error: _errorMessage,
              onRetry: _loadInitialData,
              title: 'Could not load manga',
            ),
          )
        else if (_mangaList.isEmpty || sizing == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No manga found',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding, vertical: 8.0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: sizing.cardWidth + sizing.spacing * 2,
                mainAxisSpacing: 32.0,
                crossAxisSpacing: sizing.spacing,
                mainAxisExtent: sizing.totalHeight,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return MangaCard(manga: _mangaList[index]);
                },
                childCount: _mangaList.length,
              ),
            ),
          ),
          
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
        
        const SliverToBoxAdapter(
          child: SizedBox(height: 100), // Bottom padding
        ),
      ],
    );
  }

}

class _ContinueReadingSlider extends StatefulWidget {
  final List<Map<String, dynamic>> readingHistory;
  final void Function(Map<String, dynamic>) onResume;
  final double screenWidth;
  final bool isMobile;

  const _ContinueReadingSlider({
    required this.readingHistory,
    required this.onResume,
    required this.screenWidth,
    required this.isMobile,
  });

  @override
  State<_ContinueReadingSlider> createState() => _ContinueReadingSliderState();
}

class _ContinueReadingSliderState extends State<_ContinueReadingSlider> {
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final canLeft = _scrollController.position.pixels > 10;
    final canRight = _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double directionMultiplier) {
    if (!_scrollController.hasClients) return;
    final viewportWidth = _scrollController.position.viewportDimension;
    final scrollAmount = (viewportWidth * 0.75) * directionMultiplier;
    final target = (_scrollController.position.pixels + scrollAmount).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !widget.isMobile;

    return MouseRegion(
      onEnter: (_) {
        if (isDesktop) setState(() => _isHovering = true);
      },
      onExit: (_) {
        if (isDesktop) setState(() => _isHovering = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: widget.isMobile ? 200 : 240,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMobile ? 12.0 : 24.0,
              ),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.readingHistory.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(widget.readingHistory[index]);
              },
            ),
          ),
          if (isDesktop) ...[
            // Left Arrow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: _canScrollLeft && _isHovering ? 12 : -60,
              top: 0,
              bottom: 0,
              child: Center(
                child: SliderArrow(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => _scroll(-1),
                ),
              ),
            ),
            // Right Arrow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              right: _canScrollRight && _isHovering ? 12 : -60,
              top: 0,
              bottom: 0,
              child: Center(
                child: SliderArrow(
                  icon: Icons.arrow_forward_ios_rounded,
                  onTap: () => _scroll(1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final palette = AppThemeService.currentPalette.value;
    final mangaJson = entry['manga'];
    final title = mangaJson['title'] ?? 'Unknown';
    final coverUrl = mangaJson['cover_normal'] ?? mangaJson['cover_small'] ?? '';
    final chapterIndex = entry['chapterIndex'] as int;
    final chaptersList = entry['chapters'] as List;
    final chapterTitle = chaptersList.isNotEmpty && chapterIndex < chaptersList.length
        ? chaptersList[chapterIndex]['name'] ?? 'Chapter ${chaptersList[chapterIndex]['number']}'
        : 'Resume';

    return GestureDetector(
      onTap: () => widget.onResume(entry),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: widget.isMobile ? math.min(320.0, widget.screenWidth * 0.82) : 380,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                if (coverUrl.isNotEmpty)
                  Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                // Gradient Overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                    ),
                  ),
                ),
                // Frosted Info Panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: palette.primaryColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Play/Resume Overlay Icon
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.primaryColor.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
