import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../widgets/common/arrow_affordance.dart';

import '../../services/app_spacing.dart';
import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../services/metadata/metadata_service.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/movie/movie_card.dart';
import '../../services/app_breakpoints.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';
import '../../widgets/common/focus_highlight.dart';

class CatalogPage extends StatefulWidget {
  final MovieSection section;

  const CatalogPage({
    super.key,
    required this.section,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final List<Movie> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  final Map<String, String> _selectedExtras = {};
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final ScrollController _genreScrollController = ScrollController();

  bool _canScrollGenresLeft = false;
  bool _canScrollGenresRight = true;
  bool _isHoveringGenres = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _genreScrollController.addListener(_updateGenreScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateGenreScrollButtons();
    });
    _loadItems(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _genreScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && _hasMore) {
        _loadItems();
      }
    }
  }

  void _updateGenreScrollButtons() {
    if (!_genreScrollController.hasClients) return;
    setState(() {
      _canScrollGenresLeft = _genreScrollController.position.pixels > 0;
      _canScrollGenresRight =
          _genreScrollController.position.pixels < _genreScrollController.position.maxScrollExtent;
    });
  }

  void _scrollGenres(double directionMultiplier) {
    if (!_genreScrollController.hasClients) return;
    final viewportWidth = _genreScrollController.position.viewportDimension;
    final target = _genreScrollController.offset + (viewportWidth * 0.7 * directionMultiplier);
    _genreScrollController.animateTo(
      target.clamp(0.0, _genreScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _items.clear();
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore) return;

    // Check if all required extras are selected
    if (widget.section.catalog.hasRequiredExtra) {
      for (final req in widget.section.catalog.requiredExtras) {
        final val = _selectedExtras[req.name];
        if (val == null || val.trim().isEmpty) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      List<Movie> newItems = [];

      if (_isSearching && _searchQuery.isNotEmpty) {
        if (refresh) {
          newItems = await MetadataService.search(
            baseUrl: widget.section.addonBaseUrl,
            type: widget.section.contentType,
            catalogId: widget.section.catalog.id,
            query: _searchQuery,
          );
          _hasMore = false;
        }
      } else {
        newItems = await MetadataService.fetchCatalog(
          baseUrl: widget.section.addonBaseUrl,
          type: widget.section.contentType,
          catalogId: widget.section.catalog.id,
          extraParams: _selectedExtras.isNotEmpty ? _selectedExtras : null,
          skip: _items.length,
        );
      }

      if (!mounted) return;

      setState(() {
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(newItems);
        }
        _isLoading = false;
      });

      // If content doesn't fill the viewport yet, load more immediately.
      // This fixes fullscreen mode where the initial batch doesn't produce
      // enough scroll extent to ever trigger _onScroll.
      if (_hasMore && !_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          if (_scrollController.position.maxScrollExtent <= 0) {
            _loadItems();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onExtraSelected(String extraName, String? value) {
    if (_selectedExtras[extraName] == value) return;
    setState(() {
      if (value == null || value.isEmpty) {
        _selectedExtras.remove(extraName);
      } else {
        _selectedExtras[extraName] = value;
      }
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadItems(refresh: true);
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _selectedExtras.remove('search');
      });
      _loadItems(refresh: true);
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query.trim();
      _selectedExtras.clear();
      _selectedExtras['search'] = query.trim();
    });
    _loadItems(refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _loadItems(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final sizing = MovieCardSizing.of(context);
    final isDesktop = AppBreakpoints.of(context) == ScreenTier.desktop;
    
    // Calculate safe top padding for grid based on if filters are available
    final selectableExtras = widget.section.catalog.selectableExtras;
    final hasFilters = selectableExtras.isNotEmpty && !_isSearching;
    final gridTopPadding = topPadding + kToolbarHeight + context.rem(hasFilters ? 3.75 : 1.25) + context.rem(1.25);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          // ── Main Content Grid ──
          if (_items.isEmpty && _isLoading)
            Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          else if (_items.isEmpty && _error != null)
            ErrorView(
              title: context.l10n.catalogCouldNotLoad,
              error: _error,
              onRetry: () => _loadItems(refresh: true),
            )
          else if (_items.isEmpty)
            Center(
              child: Text(
                context.l10n.catalogNoItems,
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
              ),
            )
          else
            FirstFocusScope(
              // Only reached once _items is non-empty, so the grid below
              // always has something to land on the moment it mounts.
              ready: true,
              child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                sizing.sidePadding,
                gridTopPadding,
                sizing.sidePadding,
                40 + MediaQuery.paddingOf(context).bottom, // Bottom padding
              ),
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ((MediaQuery.sizeOf(context).width - sizing.sidePadding * 2 + sizing.spacing) / (sizing.cardWidth + sizing.spacing)).floor().clamp(2, 10),
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
                crossAxisSpacing: sizing.spacing,
                mainAxisSpacing: sizing.spacing,
              ),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }
                return MovieCard(movie: _items[index]);
              },
              ),
            ),

          // ── App Bar & Filters ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  padding: EdgeInsets.only(
                    top: AppSpacing.floatingTopInset(context),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.canvas.withValues(alpha: 0.90),
                        AppColors.canvas.withValues(alpha: 0.60),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.inkAlpha(0.06),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row
                      SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            SizedBox(width: AppSpacing.pageInset(context)),
                            const GlassBackButton(),
                            SizedBox(width: context.rem(0.625)),
                            if (!_isSearching)
                              Expanded(
                                child: Text(
                                  widget.section.title,
                                  style: TextStyle(
                                    fontSize: AppType.lead,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (_isSearching)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.md)),
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: TextStyle(color: AppColors.ink, fontSize: AppType.bodyLg),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: _onSearchSubmitted,
                                    decoration: InputDecoration(
                                      hintText: context.l10n.commonSearchEllipsis,
                                      hintStyle: TextStyle(color: AppColors.inkAlpha(0.4)),
                                      border: InputBorder.none,
                                      suffixIcon: IconButton(
                                        tooltip: context.l10n.commonClose,
                                        icon: Icon(Icons.close_rounded, size: context.rem(AppRem.icon)),
                                        color: AppColors.inkMuted,
                                        onPressed: _clearSearch,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!_isSearching && widget.section.catalog.supportsSearch)
                              IconButton(
                                icon: const Icon(Icons.search_rounded),
                                tooltip: context.l10n.commonSearch,
                                color: AppColors.inkMuted,
                                onPressed: () {
                                  setState(() {
                                    _isSearching = true;
                                  });
                                },
                              ),
                            if (!_isSearching)
                              SizedBox(width: context.rem(AppRem.sm)),
                          ],
                        ),
                      ),
                      
                      // Selectable Extras Row (Genre, Tag, Sort, etc.)
                      if (hasFilters)
                        _buildFilterRow(selectableExtras, isDesktop),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<CatalogExtra> selectableExtras, bool isDesktop) {
    if (selectableExtras.length == 1) {
      final singleExtra = selectableExtras.first;
      final options = singleExtra.options;
      return MouseRegion(
        onEnter: (_) => setState(() => _isHoveringGenres = true),
        onExit: (_) => setState(() => _isHoveringGenres = false),
        child: Stack(
          children: [
            SizedBox(
              height: AppSpacing.textScaledHeight(context, 50),
              child: ListView.separated(
                controller: _genreScrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.sm)),
                physics: const BouncingScrollPhysics(),
                itemCount: options.length + (singleExtra.isRequired ? 0 : 1),
                separatorBuilder: (context, index) => SizedBox(width: context.rem(AppRem.sm)),
                itemBuilder: (context, index) {
                  if (!singleExtra.isRequired) {
                    if (index == 0) {
                      return _GenreChip(
                        label: context.l10n.commonAll,
                        isSelected: _selectedExtras[singleExtra.name] == null,
                        onTap: () => _onExtraSelected(singleExtra.name, null),
                      );
                    }
                    final opt = options[index - 1];
                    return _GenreChip(
                      label: opt,
                      isSelected: _selectedExtras[singleExtra.name] == opt,
                      onTap: () => _onExtraSelected(singleExtra.name, opt),
                    );
                  }
                  final opt = options[index];
                  return _GenreChip(
                    label: opt,
                    isSelected: _selectedExtras[singleExtra.name] == opt,
                    onTap: () => _onExtraSelected(singleExtra.name, opt),
                  );
                },
              ),
            ),
            if (isDesktop) ...[
              if (_canScrollGenresLeft)
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildScrollArrow(
                    Icons.arrow_back_ios_new_rounded,
                    () => _scrollGenres(-1),
                    _isHoveringGenres,
                  ),
                ),
              if (_canScrollGenresRight)
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildScrollArrow(
                    Icons.arrow_forward_ios_rounded,
                    () => _scrollGenres(1),
                    _isHoveringGenres,
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: AppSpacing.textScaledHeight(context, 50),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.sm)),
        physics: const BouncingScrollPhysics(),
        itemCount: selectableExtras.length,
        separatorBuilder: (context, index) => SizedBox(width: context.rem(AppRem.sm)),
        itemBuilder: (context, index) {
          final extra = selectableExtras[index];
          final currentVal = _selectedExtras[extra.name];
          final label = currentVal ?? (extra.isRequired ? context.l10n.discoverSelectExtra(extra.name) : context.l10n.catalogAllOf(extra.name));
          return FocusHighlight(
            borderRadius: context.rem(1.25),
            child: PopupMenuButton<String?>(
              tooltip: extra.name,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                side: BorderSide(color: AppColors.inkAlpha(0.1)),
              ),
              onSelected: (val) => _onExtraSelected(extra.name, val),
              itemBuilder: (context) => [
                if (!extra.isRequired)
                  PopupMenuItem<String?>(
                    value: null,
                    child: Text(
                      context.l10n.commonAll,
                      style: TextStyle(color: AppColors.ink),
                    ),
                  ),
                ...extra.options.map(
                  (opt) => PopupMenuItem<String?>(
                    value: opt,
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: opt == currentVal ? AppColors.accent : AppColors.ink,
                        fontWeight: opt == currentVal ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.snug)),
                decoration: BoxDecoration(
                  color: currentVal != null ? AppColors.accent : AppColors.inkAlpha(0.08),
                  borderRadius: BorderRadius.circular(context.rem(1.25)),
                  border: Border.all(
                    color: currentVal != null ? AppColors.accent : AppColors.inkAlpha(0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${extra.name.toUpperCase()}: $label',
                      style: TextStyle(
                        color: currentVal != null ? AppColors.ink : AppColors.inkAlpha(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: AppType.small,
                      ),
                    ),
                    SizedBox(width: context.rem(AppRem.xs)),
                    Icon(
                      Icons.arrow_drop_down,
                      size: context.rem(AppRem.iconSm),
                      color: currentVal != null ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScrollArrow(IconData icon, VoidCallback onTap, bool isVisible) {
    final arrow = Center(
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !isVisible,
          child: ExcludeFocus(
            excluding: !isVisible,
            child: HoverButton(
            scaleAmount: 1.1,
            showFocusRing: true,
            onTap: onTap,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: context.rem(AppRem.xs)),
              padding: EdgeInsets.all(context.rem(AppRem.sm)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inkFaint),
              ),
              child: Icon(
                readingOrderArrow(context, icon),
                color: AppColors.ink,
                size: context.rem(AppRem.iconXs),
              ),
            ),
            ),
          ),
        ),
      ),
    );
    return ArrowTooltip(icon: icon, child: arrow);
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return HoverButton(
      scaleAmount: 1.05,
      focusFillRadius: context.rem(1.25),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.snug)),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.inkAlpha(0.08),
          borderRadius: BorderRadius.circular(context.rem(1.25)),
          border: Border.all(
            color: isSelected 
              ? AppColors.accent 
              : AppColors.inkAlpha(0.12),
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: context.rem(AppRem.sm))] 
            : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.ink : AppColors.inkAlpha(0.7),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: AppType.small,
          ),
        ),
      ),
    );
  }
}
