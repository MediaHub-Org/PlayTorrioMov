import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../services/app_spacing.dart';
import '../../models/addon/addon.dart';
import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/metadata/metadata_service.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/movie/movie_card.dart';
import '../../services/app_breakpoints.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class DiscoverPage extends StatefulWidget {
  final String? query;
  final bool isGenre;
  final AddonCatalog? initialCatalog;
  final InstalledAddon? initialAddon;

  const DiscoverPage({
    super.key,
    this.query,
    this.isGenre = false,
    this.initialCatalog,
    this.initialAddon,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  // Legacy query mode (when query is passed)
  bool get _isLegacyMode => widget.query != null && widget.query!.isNotEmpty;

  // Legacy state
  bool _legacyLoading = true;
  String? _legacyError;
  List<MovieSection> _legacySections = [];

  // Full Discover state
  List<({InstalledAddon addon, AddonCatalog catalog})> _allCatalogs = [];
  List<String> _availableTypes = [];
  String _selectedType = 'movie';

  ({InstalledAddon addon, AddonCatalog catalog})? _selectedCatalogEntry;
  final Map<String, String> _selectedExtras = {};

  final List<Movie> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final ScrollController _filtersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (_isLegacyMode) {
      _fetchLegacyData();
    } else {
      _initDiscoverCatalogs();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filtersScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Legacy Search / Genre Mode ──
  Future<void> _fetchLegacyData() async {
    setState(() {
      _legacyLoading = true;
      _legacyError = null;
    });

    try {
      final manager = AddonManager.instance;
      List<MovieSection> sections;

      if (widget.isGenre) {
        sections = await manager.fetchByGenre(widget.query!);
      } else {
        sections = await manager.searchAll(widget.query!);
      }

      if (!mounted) return;
      setState(() {
        _legacySections = sections;
        _legacyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _legacyError = e.toString();
        _legacyLoading = false;
      });
    }
  }

  // ── Full Discover Mode ──
  void _initDiscoverCatalogs() {
    final catalogs = AddonManager.instance.getAvailableDiscoverCatalogs();
    final types = <String>{};
    for (final entry in catalogs) {
      types.add(entry.catalog.type);
    }

    final sortedTypes = types.toList();
    const priority = ['movie', 'series', 'anime', 'collections', 'collection'];
    sortedTypes.sort((a, b) {
      final idxA = priority.indexOf(a);
      final idxB = priority.indexOf(b);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return a.compareTo(b);
    });

    String initialType = widget.initialCatalog?.type ?? (sortedTypes.isNotEmpty ? sortedTypes.first : 'movie');
    if (!sortedTypes.contains(initialType) && sortedTypes.isNotEmpty) {
      initialType = sortedTypes.first;
    }

    ({InstalledAddon addon, AddonCatalog catalog})? initialEntry;
    if (widget.initialCatalog != null) {
      for (final entry in catalogs) {
        if (entry.catalog.id == widget.initialCatalog!.id &&
            (widget.initialAddon == null || entry.addon.manifest.id == widget.initialAddon!.manifest.id)) {
          initialEntry = entry;
          break;
        }
      }
    }

    initialEntry ??= catalogs.where((c) => c.catalog.type == initialType).firstOrNull ?? catalogs.firstOrNull;

    setState(() {
      _allCatalogs = catalogs;
      _availableTypes = sortedTypes;
      _selectedType = initialType;
      _selectedCatalogEntry = initialEntry;
    });

    _checkAndLoadCatalog();
  }

  List<({InstalledAddon addon, AddonCatalog catalog})> get _currentTypeCatalogs {
    return _allCatalogs.where((c) => c.catalog.type == _selectedType).toList();
  }

  bool get _hasVisibleExtras {
    if (_selectedCatalogEntry == null) return false;
    return _selectedCatalogEntry!.catalog.extra.any((e) =>
        e.name != 'skip' && (e.name != 'search' || e.isRequired));
  }

  List<CatalogExtra> get _missingRequiredExtras {
    if (_selectedCatalogEntry == null) return const [];
    final catalog = _selectedCatalogEntry!.catalog;
    return catalog.requiredExtras.where((req) {
      final val = _selectedExtras[req.name];
      return val == null || val.trim().isEmpty;
    }).toList();
  }

  bool get _areRequiredExtrasSatisfied => _missingRequiredExtras.isEmpty;

  void _onTypeChanged(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _selectedCatalogEntry = _allCatalogs.where((c) => c.catalog.type == type).firstOrNull;
      _selectedExtras.clear();
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onCatalogChanged(({InstalledAddon addon, AddonCatalog catalog}) entry) {
    if (_selectedCatalogEntry == entry) return;
    setState(() {
      _selectedCatalogEntry = entry;
      _selectedExtras.clear();
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onExtraOptionSelected(String extraName, String? value) {
    if (_selectedExtras[extraName] == value) return;
    setState(() {
      if (value == null || value.trim().isEmpty) {
        _selectedExtras.remove(extraName);
      } else {
        _selectedExtras[extraName] = value.trim();
      }
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _checkAndLoadCatalog();
  }

  void _onCustomExtraSubmitted(String extraName, String value) {
    if (value.trim().isEmpty) {
      setState(() {
        _selectedExtras.remove(extraName);
      });
    } else {
      setState(() {
        _selectedExtras[extraName] = value.trim();
      });
    }
    _checkAndLoadCatalog();
  }

  void _checkAndLoadCatalog() {
    if (_selectedCatalogEntry == null) {
      setState(() {
        _items.clear();
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    if (!_areRequiredExtrasSatisfied) {
      // Gating: DO NOT fire network requests until required extras are selected!
      setState(() {
        _items.clear();
        _isLoading = false;
        _hasMore = false;
        _error = null;
      });
      return;
    }

    _loadItems(refresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && _hasMore) {
        _loadItems();
      }
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (_selectedCatalogEntry == null) return;
    final entry = _selectedCatalogEntry!;

    if (refresh) {
      setState(() {
        _items.clear();
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore) return;
    if (!_areRequiredExtrasSatisfied) return;

    setState(() => _isLoading = true);

    try {
      List<Movie> newItems = [];

      final params = Map<String, String>.from(_selectedExtras);
      if (_searchQuery.isNotEmpty) {
        params['search'] = _searchQuery;
      }

      if (_isSearching && _searchQuery.isNotEmpty && !entry.catalog.supportsSkip) {
        newItems = await MetadataService.search(
          baseUrl: entry.addon.baseUrl,
          type: entry.catalog.type,
          catalogId: entry.catalog.id,
          query: _searchQuery,
        );
        _hasMore = false;
      } else {
        newItems = await MetadataService.fetchCatalog(
          baseUrl: entry.addon.baseUrl,
          type: entry.catalog.type,
          catalogId: entry.catalog.id,
          extraParams: params.isNotEmpty ? params : null,
          skip: entry.catalog.supportsSkip ? _items.length : 0,
        );

        if (!entry.catalog.supportsSkip) {
          _hasMore = false;
        }
      }

      if (!mounted) return;

      setState(() {
        if (newItems.isEmpty) {
          _hasMore = false;
        } else {
          _items.addAll(newItems);
          final declaredPageSize = entry.catalog.pageSize;
          if (declaredPageSize != null && newItems.length < declaredPageSize) {
            _hasMore = false;
          }
        }
        _isLoading = false;
      });

      // Auto load more if screen not filled yet
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

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _selectedExtras.remove('search');
      });
      _checkAndLoadCatalog();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query.trim();
      _selectedExtras['search'] = query.trim();
    });
    _checkAndLoadCatalog();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
    _checkAndLoadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    if (_isLegacyMode) {
      return _buildLegacyScaffold();
    }
    return _buildDiscoverScaffold();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Full Discover UI
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDiscoverScaffold() {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomInset = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;
    final isCompactScreen = screenHeight < 520;

    final sizing = MovieCardSizing.of(context);

    final hasExtras = _hasVisibleExtras;
    final toolbarH = isCompactScreen ? 46.0 : kToolbarHeight;
    final selectorH = isCompactScreen ? 44.0 : 50.0;
    final extrasH = isCompactScreen ? 42.0 : 48.0;

    final headerHeight = topPadding + toolbarH + selectorH + (hasExtras ? extrasH : 0);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          // ── Main Content Grid ──
          Positioned.fill(
            child: _buildDiscoverContent(headerHeight, sizing, bottomInset),
          ),

          // ── Glass App Bar & Filters ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(
              topPadding,
              hasExtras,
              isCompactScreen: isCompactScreen,
              toolbarH: toolbarH,
              selectorH: selectorH,
              extrasH: extrasH,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverContent(double topOffset, MovieCardSizing sizing, double bottomInset) {
    if (_selectedCatalogEntry == null) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.rem(1.25), topOffset + context.rem(1.875), context.rem(1.25), context.rem(6.25)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: context.rem(3), color: AppColors.inkAlpha(0.3)),
              SizedBox(height: context.rem(AppRem.ms)),
              Text(
                context.l10n.discoverNoCatalogs(_selectedType),
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Required extra gating prompt
    if (!_areRequiredExtrasSatisfied) {
      return _buildRequiredExtraGatingPrompt(topOffset);
    }

    if (_items.isEmpty && _isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_items.isEmpty && _error != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.rem(1.25), topOffset + context.rem(1.875), context.rem(1.25), context.rem(6.25)),
          child: ErrorView(
            title: context.l10n.catalogCouldNotLoad,
            error: _error,
            onRetry: () => _loadItems(refresh: true),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.rem(1.25), topOffset + context.rem(1.875), context.rem(1.25), context.rem(6.25)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: context.rem(3), color: AppColors.inkAlpha(0.3)),
              SizedBox(height: context.rem(AppRem.ms)),
              Text(
                context.l10n.discoverNoTitles,
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = ((screenWidth - sizing.sidePadding * 2 + sizing.spacing) /
            (sizing.cardWidth + sizing.spacing))
        .floor()
        .clamp(2, 10);
    final double cardAspectRatio = sizing.cardWidth / sizing.totalHeight;

    return FirstFocusScope(
      // The three isEmpty branches above already returned, so the grid
      // below always has something to land on the moment it mounts.
      ready: true,
      child: GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        sizing.sidePadding,
        topOffset + context.rem(0.875),
        sizing.sidePadding,
        110 + bottomInset,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: cardAspectRatio,
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
    );
  }

  Widget _buildRequiredExtraGatingPrompt(double topOffset) {
    final missing = _missingRequiredExtras;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < 420;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.rem(isNarrow ? AppRem.md : AppRem.lg),
          topOffset + context.rem(1.25),
          context.rem(isNarrow ? AppRem.md : AppRem.lg),
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: context.rem(30)),
          padding: EdgeInsets.symmetric(
            horizontal: context.rem(isNarrow ? 1.125 : 1.75),
            vertical: context.rem(isNarrow ? 1.25 : 1.75),
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(context.rem(1.25)),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.1),
                blurRadius: context.rem(AppRem.lg),
                offset: Offset(0, context.rem(AppRem.sm)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(context.rem(0.875)),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.tune_rounded, color: const Color(0xFF9D85FF), size: context.rem(1.875)),
              ),
              SizedBox(height: context.rem(AppRem.md)),
              Text(
                context.l10n.discoverSelectRequired,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: isNarrow ? AppType.subhead : AppType.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.rem(AppRem.sm)),
              Text(
                context.l10n.discoverRequiresSelecting(missing.map((e) => e.name).join(' & ')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkAlpha(0.7),
                  fontSize: isNarrow ? AppType.small : AppType.body,
                  height: 1.4, // ratio: a line height, not a size
                ),
              ),
              SizedBox(height: context.rem(1.25)),
              // Quick selection chips for missing extras
              Wrap(
                spacing: context.rem(AppRem.sm),
                runSpacing: context.rem(AppRem.sm),
                alignment: WrapAlignment.center,
                children: missing.map((extra) {
                  if (extra.options.isNotEmpty) {
                    return PopupMenuButton<String>(
                      tooltip: extra.name,
                      constraints: BoxConstraints(maxHeight: context.rem(22.5)),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                        side: BorderSide(color: AppColors.inkAlpha(0.1)),
                      ),
                      onSelected: (val) => _onExtraOptionSelected(extra.name, val),
                      itemBuilder: (context) => extra.options
                          .map(
                            (opt) => PopupMenuItem<String>(
                              value: opt,
                              child: Text(opt, style: TextStyle(color: AppColors.ink)),
                            ),
                          )
                          .toList(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(isNarrow ? 0.875 : AppRem.md),
                          vertical: context.rem(isNarrow ? 0.4375 : AppRem.sm),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(context.rem(1.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.discoverSelectExtra('${extra.name[0].toUpperCase()}${extra.name.substring(1)}'),
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: isNarrow ? AppType.captionPlus : AppType.body,
                              ),
                            ),
                            SizedBox(width: context.rem(AppRem.snug)),
                            Icon(Icons.arrow_drop_down, color: AppColors.ink, size: context.rem(AppRem.icon)),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return ElevatedButton.icon(
                      onPressed: () => _showCustomExtraDialog(extra.name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(isNarrow ? 0.875 : 1.125),
                          vertical: context.rem(isNarrow ? AppRem.sm : 0.625),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(1.25))),
                      ),
                      icon: Icon(Icons.edit_rounded, size: context.rem(AppRem.iconXs)),
                      label: Text(
                        context.l10n.discoverEnterExtra(extra.name),
                        style: TextStyle(fontSize: isNarrow ? AppType.captionPlus : AppType.body),
                      ),
                    );
                  }
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomExtraDialog(String extraName) {
    final controller = TextEditingController(text: _selectedExtras[extraName] ?? '');
    final screenWidth = MediaQuery.sizeOf(context).width;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
          side: BorderSide(color: AppColors.inkAlpha(0.1)),
        ),
        title: Text(
          context.l10n.discoverEnterExtra(extraName),
          style: TextStyle(color: AppColors.ink, fontSize: AppType.lead, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: (screenWidth - context.rem(AppRem.xl * 2)).clamp(context.rem(16.25), context.rem(26.25)),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: context.l10n.discoverTypeHere(extraName),
              hintStyle: TextStyle(color: AppColors.inkDisabled),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.inkAlpha(0.2)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (val) {
              Navigator.pop(ctx);
              _onCustomExtraSubmitted(extraName, val);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.libraryCancel, style: TextStyle(color: AppColors.inkSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _onCustomExtraSubmitted(extraName, controller.text);
            },
            child: Text(context.l10n.discoverApply),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _buildHeader(
    double topPadding,
    bool hasExtras, {
    bool isCompactScreen = false,
    double toolbarH = kToolbarHeight,
    double selectorH = 50.0,
    double extrasH = 48.0,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;
    final isNarrow = screenWidth < 400;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: EdgeInsets.only(top: AppSpacing.floatingTopInset(context)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.canvas.withValues(alpha: 0.95),
                AppColors.canvas.withValues(alpha: 0.80),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: AppColors.inkAlpha(0.06)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Title Row ──
              SizedBox(
                height: toolbarH,
                child: Row(
                  children: [
                    SizedBox(width: AppSpacing.pageInset(context)),
                    const GlassBackButton(),
                    SizedBox(width: context.rem(AppRem.xxs)),
                    if (!_isSearching) ...[
                      Icon(Icons.explore_rounded, color: AppColors.accent, size: context.rem(1.3125)),
                      SizedBox(width: context.rem(AppRem.sm)),
                      Text(
                        context.l10n.discoverTitle,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: isDesktop ? AppType.titleSm : (isNarrow ? AppType.subhead : AppType.lead),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    if (_isSearching)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(0.625)),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(color: AppColors.ink, fontSize: AppType.bodyMd),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _onSearchSubmitted,
                            decoration: InputDecoration(
                              hintText: isNarrow
                                  ? context.l10n.commonSearchEllipsis
                                  : context.l10n.discoverSearchWithin(_selectedCatalogEntry?.catalog.name ?? 'catalog'),
                              hintStyle: TextStyle(
                                color: AppColors.inkAlpha(0.4),
                                fontSize: AppType.body,
                              ),
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                tooltip: context.l10n.commonClose,
                                icon: Icon(Icons.close_rounded, size: context.rem(AppRem.iconSm), color: AppColors.inkMuted),
                                onPressed: _clearSearch,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    // Search toggle button
                    if (!_isSearching && (_selectedCatalogEntry?.catalog.supportsSearch ?? false))
                      IconButton(
                        icon: Icon(Icons.search_rounded, color: AppColors.inkMuted, size: context.rem(AppRem.iconMd)),
                        tooltip: context.l10n.discoverSearchCatalog,
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                    SizedBox(width: context.rem(AppRem.sm)),
                  ],
                ),
              ),

              // ── Type and Catalog Selector Row ──
              Container(
                height: selectorH,
                padding: EdgeInsets.symmetric(horizontal: context.rem(isNarrow ? 0.625 : AppRem.md)),
                child: Row(
                  children: [
                    // Type selector popup/dropdown
                    if (_availableTypes.isNotEmpty) ...[
                      PopupMenuButton<String>(
                        tooltip: context.l10n.discoverContentType,
                        constraints: BoxConstraints(maxHeight: context.rem(22.5)),
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                          side: BorderSide(color: AppColors.inkAlpha(0.1)),
                        ),
                        onSelected: _onTypeChanged,
                        itemBuilder: (context) => _availableTypes
                            .map(
                              (t) => PopupMenuItem<String>(
                                value: t,
                                child: Text(
                                  '${t[0].toUpperCase()}${t.substring(1)}',
                                  style: TextStyle(
                                    color: t == _selectedType ? AppColors.accent : AppColors.ink,
                                    fontWeight: t == _selectedType ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rem(isNarrow ? 0.625 : 0.875),
                            vertical: context.rem(AppRem.snug),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(context.rem(1.25)),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_selectedType[0].toUpperCase()}${_selectedType.substring(1)}',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? AppType.caption : AppType.small,
                                ),
                              ),
                              SizedBox(width: context.rem(AppRem.xs)),
                              Icon(Icons.arrow_drop_down, color: AppColors.inkMuted, size: context.rem(AppRem.iconSm)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: context.rem(isNarrow ? AppRem.snug : 0.625)),
                    ],

                    // Catalog selector horizontal scroll
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _currentTypeCatalogs.map((entry) {
                            final isSelected = _selectedCatalogEntry == entry;
                            final name = AddonManager.instance.catalogDisplayName(entry.catalog);
                            final hasReq = entry.catalog.hasRequiredExtra;

                            return Padding(
                              padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
                              child: HoverButton(
                                scaleAmount: 1.05,
                                showFocusRing: true,
                                focusRingBorderRadius: context.rem(1.25) + context.rem(AppRem.xxs),
                                onTap: () => _onCatalogChanged(entry),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.rem(isNarrow ? 0.6875 : 0.875),
                                    vertical: context.rem(AppRem.snug),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.inkAlpha(0.08),
                                    borderRadius: BorderRadius.circular(context.rem(1.25)),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.inkAlpha(0.12),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.accent.withValues(alpha: 0.3),
                                              blurRadius: context.rem(AppRem.sm),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.ink : AppColors.inkMuted,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: isNarrow ? AppType.caption : AppType.small,
                                        ),
                                      ),
                                      if (hasReq) ...[
                                        SizedBox(width: context.rem(AppRem.snug)),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: context.rem(0.3125), vertical: context.rem(0.0625)),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.inkFaint : Colors.amber.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                                          ),
                                          child: Text(
                                            context.l10n.discoverCustom,
                                            style: TextStyle(
                                              fontSize: TvType.scale(AppType.nanoPlus),
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? AppColors.ink : Colors.amber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Extra Selectors Row (Genre, Tag, Sort, Performer, etc.) ──
              if (hasExtras) ...[
                SizedBox(
                  height: extrasH,
                  child: ListView(
                    controller: _filtersScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: context.rem(isNarrow ? 0.625 : AppRem.md), vertical: context.rem(AppRem.snug)),
                    physics: const BouncingScrollPhysics(),
                    children: _selectedCatalogEntry!.catalog.extra.map((extra) {
                      if (extra.name == 'skip' || (extra.name == 'search' && !extra.isRequired)) {
                        return const SizedBox.shrink();
                      }

                      final currentVal = _selectedExtras[extra.name];
                      final isReq = extra.isRequired;
                      final isSelected = currentVal != null && currentVal.isNotEmpty;

                      // Dropdown for extras with predefined options
                      if (extra.options.isNotEmpty) {
                        return Padding(
                          padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
                          child: PopupMenuButton<String?>(
                            tooltip: extra.name,
                            constraints: BoxConstraints(maxHeight: context.rem(22.5)),
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                              side: BorderSide(color: AppColors.inkAlpha(0.1)),
                            ),
                            onSelected: (val) => _onExtraOptionSelected(extra.name, val),
                            itemBuilder: (context) => [
                              if (!isReq)
                                PopupMenuItem<String?>(
                                  value: null,
                                  child: Text(context.l10n.catalogAllOf(extra.name), style: TextStyle(color: AppColors.ink)),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rem(isNarrow ? 0.625 : 0.875),
                                vertical: context.rem(AppRem.snug),
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent
                                    : (isReq ? Colors.amber.withValues(alpha: 0.15) : AppColors.inkAlpha(0.08)),
                                borderRadius: BorderRadius.circular(context.rem(1.25)),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accent
                                      : (isReq ? Colors.amber.withValues(alpha: 0.4) : AppColors.inkAlpha(0.12)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${extra.name.toUpperCase()}: ${currentVal ?? (isReq ? context.l10n.discoverRequired : context.l10n.commonAll)}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.ink
                                          : (isReq ? Colors.amber : AppColors.inkAlpha(0.8)),
                                      fontWeight: FontWeight.w600,
                                      fontSize: isNarrow ? AppType.tinyPlus : AppType.caption,
                                    ),
                                  ),
                                  SizedBox(width: context.rem(AppRem.xs)),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: context.rem(AppRem.iconSm),
                                    color: isSelected
                                        ? AppColors.ink
                                        : (isReq ? Colors.amber : AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Text input chip for freeform extras (or search if isRequired)
                      return Padding(
                        padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.sm)),
                        child: HoverButton(
                          scaleAmount: 1.05,
                          showFocusRing: true,
                          focusRingBorderRadius: context.rem(1.25) + context.rem(AppRem.xxs),
                          onTap: () => _showCustomExtraDialog(extra.name),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rem(isNarrow ? 0.625 : 0.875),
                              vertical: context.rem(AppRem.snug),
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent
                                  : (isReq ? Colors.amber.withValues(alpha: 0.15) : AppColors.inkAlpha(0.08)),
                              borderRadius: BorderRadius.circular(context.rem(1.25)),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : (isReq ? Colors.amber.withValues(alpha: 0.4) : AppColors.inkAlpha(0.12)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${extra.name.toUpperCase()}: ${currentVal ?? (isReq ? context.l10n.discoverRequired : context.l10n.discoverEnter)}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.ink
                                        : (isReq ? Colors.amber : AppColors.inkAlpha(0.8)),
                                    fontWeight: FontWeight.w600,
                                    fontSize: isNarrow ? AppType.tinyPlus : AppType.caption,
                                  ),
                                ),
                                SizedBox(width: context.rem(AppRem.xs)),
                                Icon(
                                  Icons.edit_rounded,
                                  size: context.rem(0.875),
                                  color: isSelected
                                      ? AppColors.ink
                                      : (isReq ? Colors.amber : AppColors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Legacy Search/Genre Scaffold (Backwards compatibility)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLegacyScaffold() {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = AppBreakpoints.of(context) == ScreenTier.desktop;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          if (_legacyLoading)
            Center(child: CircularProgressIndicator(color: AppColors.accent))
          else if (_legacyError != null)
            ErrorView(
              title: context.l10n.discoverCouldNotLoadResults,
              error: _legacyError,
              onRetry: _fetchLegacyData,
            )
          else if (_legacySections.isEmpty)
            Center(
              child: Text(
                context.l10n.commonNoResultsFor(widget.query ?? ''),
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.bodyLg),
              ),
            )
          else
            _buildLegacySectionsList(topPadding + kToolbarHeight + 20),

          // Glass App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: kToolbarHeight + topPadding,
                  padding: EdgeInsetsDirectional.only(
                    top: topPadding,
                    start: AppSpacing.pageInset(context),
                    end: AppSpacing.pageInset(context),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.canvas.withValues(alpha: 0.6),
                    border: Border(
                      bottom: BorderSide(color: AppColors.inkAlpha(0.05), width: 1), // px: a hairline, not a layout size
                    ),
                  ),
                  child: Row(
                    children: [
                      const GlassBackButton(),
                      SizedBox(width: context.rem(AppRem.sm)),
                      Expanded(
                        child: Text(
                          widget.isGenre ? context.l10n.discoverGenreTitle(widget.query ?? '') : context.l10n.discoverSearchTitle(widget.query ?? ''),
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: isDesktop ? AppType.titleMd : AppType.titleSm,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  Widget _buildLegacySectionsList(double topPadding) {
    final allMoviesMap = <String, Movie>{};
    for (var section in _legacySections) {
      for (var movie in section.movies) {
        if (!allMoviesMap.containsKey(movie.id)) {
          allMoviesMap[movie.id] = movie;
        }
      }
    }
    final allMovies = allMoviesMap.values.toList();
    final sizing = MovieCardSizing.of(context);
    final double cardAspectRatio = sizing.cardWidth / sizing.totalHeight;

    return FirstFocusScope(
      ready: allMovies.isNotEmpty,
      child: GridView.builder(
      padding: EdgeInsets.fromLTRB(
        sizing.sidePadding,
        topPadding,
        sizing.sidePadding,
        110 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ((MediaQuery.sizeOf(context).width - sizing.sidePadding * 2 + sizing.spacing) /
                (sizing.cardWidth + sizing.spacing))
            .floor()
            .clamp(2, 10),
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: sizing.spacing,
        mainAxisSpacing: sizing.spacing,
      ),
      itemCount: allMovies.length,
      itemBuilder: (context, index) {
        return MovieCard(movie: allMovies[index]);
      },
      ),
    );
  }
}
