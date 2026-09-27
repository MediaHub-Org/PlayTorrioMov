import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../models/iptv/iptv_models.dart';
import '../../models/iptv/m3u_models.dart';
import '../../services/theme/app_theme_service.dart';
import '../../widgets/common/filter_dropdown.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_network.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/iptv/iptv_storage.dart';
import '../../utils/navigation/route_transitions.dart';
import 'iptv_player_page.dart';
import '../../services/app_breakpoints.dart';
import '../../services/theme/app_colors.dart';
import '../../widgets/common/setting_choice_chip.dart';
import '../../widgets/common/clamped_text_scale.dart';

class IptvPortalBrowserPage extends StatefulWidget {
  final VerifiedPortal? portal;
  final M3uPlaylist? m3uPlaylist;

  const IptvPortalBrowserPage({
    super.key,
    this.portal,
    this.m3uPlaylist,
  });

  @override
  State<IptvPortalBrowserPage> createState() => _IptvPortalBrowserPageState();
}

/// The region a portal category belongs to, from the prefix portals file
/// them under (`AR | Sports`, `UK: News`).
///
/// Portals shelve the same kinds per region, so without this the category
/// list is one long run of near-duplicates. Null when the name carries no
/// prefix -- those shelves are regionless and always shown.
String? regionPrefixOf(String name) {
  final match =
      RegExp(r'^([A-Za-z]{2,3})\s*[|:\-–—]\s*.+').firstMatch(name.trim());
  if (match == null) return null;
  return match.group(1)!.toUpperCase();
}

/// One `(group, stream)` per group a playlist files a channel under.
///
/// iptv-org playlists tag a channel with several groups at once
/// (`News;Public`), and keeping that as one category name put an ugly
/// combined bucket in the list. Split on `;` so each group is its own
/// shelf; a channel in two groups appears in both, the way a TV guide
/// lists it twice. Ungrouped channels pool under `General`, as before.
/// Pure and synchronous -- the playlist is already in memory.
List<(String, IptvStream)> expandM3uGroups(M3uPlaylist pl) {
  final entries = <(String, IptvStream)>[];
  for (final c in pl.channels) {
    final groups = c.group
        .split(';')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();
    for (final group in groups.isEmpty ? const ['General'] : groups) {
      entries.add((
        group,
        IptvStream(
          streamId: c.url,
          name: c.name,
          icon: c.logo,
          categoryId: group,
          containerExt: 'm3u8',
          kind: 'live',
        ),
      ));
    }
  }
  return entries;
}

class _IptvPortalBrowserPageState extends State<IptvPortalBrowserPage> {
  static const String favoritesCategoryId = '__favorites__';

  bool _isLoading = true;
  String? _errorMessage;

  List<IptvCategory> _categories = [];
  String _selectedCategoryId = '';
  List<IptvStream> _allStreams = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _catSearchCtrl = TextEditingController();
  String _searchQuery = '';
  String _catSearchQuery = '';

  // Scroll Controllers with Desktop Arrow Navigation
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _contentScrollController = ScrollController();


  // Stream Health / Alive Checker State
  bool _isCheckingAlive = false;
  int _aliveChecked = 0;
  int _aliveTotal = 0;
  Set<String> _aliveStreamIds = {};
  bool _cancelAlive = false;

  // Favorited Streams in this Portal
  Set<String> _favoriteStreamIds = {};

  /// The picked region prefix, or null for every region. Portals shelve the
  /// same kinds per region (`AR | Sports`, `UK | Sports`), so picking one
  /// narrows categories and streams together; regionless shelves belong to
  /// no region to exclude and stay visible either way.
  String? _regionFilter;

  String get _storageKey {
    if (widget.portal != null) {
      return IptvPortalFavoritesStore.portalKey(widget.portal!.portal);
    } else if (widget.m3uPlaylist != null) {
      return 'm3u_${widget.m3uPlaylist!.id}';
    }
    return '';
  }

  // Static in-memory EPG cache shared across rows to avoid duplicate network fetches
  static final Map<String, List<EpgEntry>> _sharedEpgCache = {};

  @override
  void initState() {
    super.initState();
    IptvSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
    _loadFavorites();
    _loadSectionData();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadFavorites() async {
    final key = _storageKey;
    if (key.isEmpty) return;
    final favs = await IptvPortalFavoritesStore.load(key);
    if (mounted) {
      setState(() => _favoriteStreamIds = favs);
    }
  }

  Future<void> _toggleFavoriteStream(String streamId) async {
    final key = _storageKey;
    if (key.isEmpty) return;
    setState(() {
      if (_favoriteStreamIds.contains(streamId)) {
        _favoriteStreamIds.remove(streamId);
      } else {
        _favoriteStreamIds.add(streamId);
      }
    });
    await IptvPortalFavoritesStore.save(key, _favoriteStreamIds);
  }

  @override
  void dispose() {
    _cancelAlive = true;
    IptvSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    _categoryScrollController.dispose();
    _contentScrollController.dispose();
    _searchCtrl.dispose();
    _catSearchCtrl.dispose();
    super.dispose();
  }

  void _showBrowserCustomizer(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.inkAlpha(0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
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
                      Text(
                        context.l10n.iptvCustomizeBrowser,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.l10n.commonClose,
                        icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.inkAlpha(0.08)),
                  const SizedBox(height: 12),

                  Text(
                    context.l10n.iptvStreamLayoutMode,
                    style: TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<PortalBrowserLayout>(
                    valueListenable: IptvSettings.browserLayout,
                    builder: (context, layout, _) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PortalBrowserLayout.values.map((l) {
                          final isSelected = l == layout;
                          return SettingChoiceChip(
                            label: l.localizedLabel(context.l10n),
                            selected: isSelected,
                            onSelect: () => IptvSettings.setBrowserLayout(l),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  ValueListenableBuilder<PortalBrowserLayout>(
                    valueListenable: IptvSettings.browserLayout,
                    builder: (context, layout, _) {
                      if (layout != PortalBrowserLayout.grid) return const SizedBox.shrink();
                      return ValueListenableBuilder<int>(
                        valueListenable: IptvSettings.browserGridColumns,
                        builder: (context, cols, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(context.l10n.liveTvGridColumns, style: TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(context.l10n.liveTvColumnsN(cols), style: TextStyle(color: palette.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: palette.primaryColor,
                                  inactiveTrackColor: AppColors.inkAlpha(0.12),
                                  thumbColor: palette.primaryColor,
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: cols.toDouble(),
                                  min: 2,
                                  max: 6,
                                  divisions: 4,
                                  onChanged: (val) => IptvSettings.setBrowserGridColumns(val.round()),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: IptvSettings.showStreamLogos,
                    builder: (context, showLogos, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.liveTvShowLogos, style: TextStyle(color: AppColors.ink, fontSize: 13.5)),
                        value: showLogos,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => IptvSettings.setShowStreamLogos(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: IptvSettings.showEpgSnippet,
                    builder: (context, showEpg, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.liveTvShowEpg, style: TextStyle(color: AppColors.ink, fontSize: 13.5)),
                        value: showEpg,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => IptvSettings.setShowEpgSnippet(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: IptvSettings.showCategoryCount,
                    builder: (context, showCount, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.liveTvShowCounts, style: TextStyle(color: AppColors.ink, fontSize: 13.5)),
                        value: showCount,
                        activeColor: palette.primaryColor,
                        onChanged: (val) => IptvSettings.setShowCategoryCount(val),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isDesktop(BuildContext context) {
    return AppBreakpoints.of(context) == ScreenTier.desktop;
  }

  String _selectedCategoryName() {
    if (_selectedCategoryId == favoritesCategoryId) return context.l10n.iptvPinned;
    if (_selectedCategoryId.isEmpty) return context.l10n.iptvAllCategories;
    final found = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => IptvCategory(id: '', name: context.l10n.iptvAllCategories),
    );
    return found.name;
  }

  Future<void> _loadSectionData() async {
    if (widget.portal == null && widget.m3uPlaylist == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchQuery = '';
      _searchCtrl.clear();
      _catSearchQuery = '';
      _catSearchCtrl.clear();
    });

    // Read before the first await: the synthetic category names below are
    // translated when the list is built, and there is no context to do it
    // with once the network calls return.
    final l10n = context.l10n;

    try {
      if (widget.portal != null) {
        final p = widget.portal!.portal;
        // Live channels only. A portal also carries movies and series, but
        // those are not live: giving them tabs here rebuilt the app's own
        // Films/Series navigation inside a source browser.
        final cats = await IptvClient.categories(p, IptvSection.live);
        final streams = await IptvClient.streams(p, IptvSection.live, '');

        if (!mounted) return;
        setState(() {
          _categories = [
            IptvCategory(id: '', name: l10n.iptvAllCategories),
            IptvCategory(id: favoritesCategoryId, name: l10n.iptvPinned),
            ...cats,
          ];
          _selectedCategoryId = '';
          _allStreams = streams;
          _isLoading = false;
        });

        _loadSavedAliveSnapshot();
      } else if (widget.m3uPlaylist != null) {
        final pl = widget.m3uPlaylist!;

        final cats = <String>{};
        final streams = <IptvStream>[];
        for (final entry in expandM3uGroups(pl)) {
          cats.add(entry.$1);
          streams.add(entry.$2);
        }

        if (!mounted) return;
        setState(() {
          _categories = [
            IptvCategory(id: '', name: l10n.iptvAllCategories),
            IptvCategory(id: favoritesCategoryId, name: l10n.iptvPinned),
            ...cats.map((g) => IptvCategory(id: g, name: g)),
          ];
          _selectedCategoryId = '';
          _allStreams = streams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.iptvLoadFailed('$e');
      });
    }
  }

  Future<void> _loadSavedAliveSnapshot() async {
    if (widget.portal == null) return;
    final key = IptvAliveStore.portalKey(widget.portal!.portal);
    final snap = await IptvAliveStore.load(key);
    if (snap != null && mounted) {
      setState(() {
        _aliveStreamIds = snap.aliveIds;
      });
    }
  }

  Future<void> _startAliveCheck() async {
    if (widget.portal == null || _isCheckingAlive) return;

    final p = widget.portal!.portal;
    final filtered = _filteredStreams();
    if (filtered.isEmpty) return;

    setState(() {
      _isCheckingAlive = true;
      _aliveChecked = 0;
      _aliveTotal = filtered.length;
      _cancelAlive = false;
    });

    final entries = filtered
        .map((s) => MapEntry(s.streamId, IptvClient.streamUrl(p, s)))
        .toList();

    final aliveSet = Set<String>.from(_aliveStreamIds);

    await IptvAliveChecker.launchCheck(
      streams: entries,
      isCancelled: () => _cancelAlive,
      onResult: (id, alive) async {
        if (alive) {
          aliveSet.add(id);
          if (mounted) setState(() => _aliveStreamIds = aliveSet);
        }
      },
      onProgress: (prog) async {
        if (mounted) {
          setState(() {
            _aliveChecked = prog.checked;
            _aliveTotal = prog.total;
          });
        }
      },
      onDone: () async {
        if (mounted) {
          setState(() => _isCheckingAlive = false);
          final key = IptvAliveStore.portalKey(p);
          await IptvAliveStore.save(
            key,
            AliveSnapshot(
              checkedAt: DateTime.now().millisecondsSinceEpoch,
              aliveIds: aliveSet,
            ),
          );
        }
      },
    );
  }

  List<IptvCategory> _filteredCategories() {
    final q = _catSearchQuery.trim().toLowerCase();
    final region = _regionFilter;
    return _categories.where((c) {
      if (region != null &&
          c.id.isNotEmpty &&
          c.id != favoritesCategoryId) {
        final prefix = regionPrefixOf(c.name);
        if (prefix != null && prefix != region) return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q);
    }).toList();
  }

  /// Distinct region prefixes across the portal's own categories, sorted.
  /// Empty when the portal files everything under plain names -- the
  /// dropdown then has nothing to offer and stays out of the header.
  List<String> get _regions {
    final regions = <String>{};
    for (final c in _categories) {
      if (c.id.isEmpty || c.id == favoritesCategoryId) continue;
      final prefix = regionPrefixOf(c.name);
      if (prefix != null) regions.add(prefix);
    }
    return regions.toList()..sort();
  }

  String _categoryNameOf(String categoryId) {
    for (final c in _categories) {
      if (c.id == categoryId) return c.name;
    }
    return '';
  }

  bool _passesRegion(IptvStream s) {
    final region = _regionFilter;
    if (region == null) return true;
    final prefix = regionPrefixOf(_categoryNameOf(s.categoryId));
    return prefix == null || prefix == region;
  }

  List<IptvStream> _filteredStreams() {
    return _allStreams.where((s) {
      if (!_passesRegion(s)) return false;
      if (_selectedCategoryId == favoritesCategoryId) {
        if (!_favoriteStreamIds.contains(s.streamId)) return false;
      } else if (_selectedCategoryId.isNotEmpty) {
        if (s.categoryId != _selectedCategoryId) return false;
      }
      if (_searchQuery.trim().isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  int _countForCategory(String catId) {
    final streams =
        _regionFilter == null ? _allStreams : _allStreams.where(_passesRegion);
    if (catId == favoritesCategoryId) {
      return streams.where((s) => _favoriteStreamIds.contains(s.streamId)).length;
    }
    if (catId.isEmpty) return streams.length;
    return streams.where((s) => s.categoryId == catId).length;
  }

  void _playStream(IptvStream stream) {
    final currentList = _filteredStreams();
    final clickedIndex = currentList.indexWhere((s) => s.streamId == stream.streamId);
    final initialIndex = clickedIndex >= 0 ? clickedIndex : 0;

    final currentCat = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => IptvCategory(id: '', name: context.l10n.iptvLiveChannels),
    );

    if (widget.portal != null) {
      final p = widget.portal!;
      final hits = currentList.map((s) => ChannelHit(
        portal: p,
        stream: s,
        streamUrl: IptvClient.streamUrl(p.portal, s),
      )).toList();

      final ch = HardcodedChannel(
        id: stream.streamId,
        name: stream.name,
        short: 'LIVE',
        category: currentCat.name,
        keywords: [stream.name],
        gradient: [AppColors.accent, const Color(0xFF00D2EF)],
      );

      pushPage(
        context,
        IptvPlayerPage(
          channel: ch,
          hits: hits.isNotEmpty
              ? hits
              : [
                  ChannelHit(
                    portal: p,
                    stream: stream,
                    streamUrl: IptvClient.streamUrl(p.portal, stream),
                  ),
                ],
          initialHitIndex: initialIndex,
          isLive: true,
          categoryTitle: currentCat.name,
        ),
      );
    } else if (widget.m3uPlaylist != null) {
      final hits = currentList.map((s) => ChannelHit(
        portal: VerifiedPortal(
          portal: IptvPortal(url: s.streamId, username: '', password: '', source: 'M3U'),
          name: widget.m3uPlaylist!.name,
          expiry: '',
          maxConnections: '1',
          activeConnections: '0',
        ),
        stream: s,
        streamUrl: s.streamId,
      )).toList();

      final ch = HardcodedChannel(
        id: stream.streamId,
        name: stream.name,
        short: 'LIVE',
        category: currentCat.name,
        keywords: [stream.name],
        gradient: [AppColors.accent, const Color(0xFF00D2EF)],
      );

      pushPage(
        context,
        IptvPlayerPage(
          channel: ch,
          hits: hits.isNotEmpty
              ? hits
              : [
                  ChannelHit(
                    portal: VerifiedPortal(
                      portal: IptvPortal(url: stream.streamId, username: '', password: '', source: 'M3U'),
                      name: widget.m3uPlaylist!.name,
                      expiry: '',
                      maxConnections: '1',
                      activeConnections: '0',
                    ),
                    stream: stream,
                    streamUrl: stream.streamId,
                  ),
                ],
          initialHitIndex: initialIndex,
          isLive: true,
          categoryTitle: currentCat.name,
        ),
      );
    }
  }  void _showMobileCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cats = _filteredCategories();
            return Container(
              height: MediaQuery.sizeOf(context).height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.bar,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.raised, width: 1.2)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.inkFaint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.folder_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.iptvSelectCategory,
                          style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          context.l10n.iptvCategoriesTotal(_categories.length),
                          style: TextStyle(color: AppColors.inkDisabled, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClampedTextScale(
                      // A search pill is a fixed height by design, and a 13px
                      // field wants ~47px at 3x. The input caps; the box keeps
                      // the shape the rest of the toolbar is built around (#69).
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.raised),
                        ),
                        child: TextField(
                          controller: _catSearchCtrl,
                          style: TextStyle(color: AppColors.ink, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: context.l10n.iptvFilterCategories,
                            hintStyle: TextStyle(color: AppColors.inkAlpha(0.35), fontSize: 12.5),
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSubtle, size: 18),
                            suffixIcon: _catSearchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: context.l10n.commonClose,
                                    icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: 16),
                                    onPressed: () {
                                      _catSearchCtrl.clear();
                                      setState(() => _catSearchQuery = '');
                                      setSheetState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) {
                            setState(() => _catSearchQuery = v);
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: AppColors.edge, height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: cats.length,
                      itemExtent: 50.0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemBuilder: (ctx, i) {
                        final cat = cats[i];
                        final isSelected = _selectedCategoryId == cat.id;
                        final count = _countForCategory(cat.id);
                        return _CategoryListRow(
                          category: cat,
                          count: count,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() => _selectedCategoryId = cat.id);
                            _contentScrollController.jumpTo(0);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The region pill. Absent unless the portal actually files shelves by
  /// region -- a dropdown with one option is a control that does nothing.
  Widget _regionDropdown() {
    final regions = _regions;
    if (regions.isEmpty) return const SizedBox.shrink();
    return FilterDropdown<String?>(
      label: _regionFilter ?? context.l10n.iptvAllRegions,
      icon: Icons.language_rounded,
      items: [
        PopupMenuItem(value: '', child: Text(context.l10n.iptvAllRegions)),
        for (final r in regions) PopupMenuItem(value: r, child: Text(r)),
      ],
      onSelected: (v) => setState(() {
        _regionFilter = (v == null || v.isEmpty) ? null : v;
        _selectedCategoryId = '';
        if (_contentScrollController.hasClients) {
          _contentScrollController.jumpTo(0);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final title = widget.portal?.name.isNotEmpty == true
        ? widget.portal!.name
        : (widget.m3uPlaylist?.name ?? context.l10n.iptvPortalFallback);

    final isDesktop = _isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP APPLICATION HEADER ──
            if (isDesktop)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bar,
                  border: Border(
                    bottom: BorderSide(color: AppColors.edge, width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 22),
                      tooltip: context.l10n.playerBack,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),

                    // Portal Emblem & Title
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.primaryColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.settings_input_antenna_rounded, color: palette.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (widget.portal != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  context.l10n.iptvExpiryLong(widget.portal!.expiry),
                                  style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 10),
                                Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.inkAlpha(0.30), shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Text(
                                  context.l10n.iptvConnectionsLong(widget.portal!.activeConnections, widget.portal!.maxConnections),
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // The region pill, when the portal files shelves by
                    // region. Next to search, where filters live.
                    if (_regions.isNotEmpty) ...[
                      _regionDropdown(),
                      const SizedBox(width: 12),
                    ],

                    // Search Bar
                    ClampedTextScale(
                      // A search pill is a fixed height by design, and a 13px
                      // field wants ~47px at 3x. The input caps; the box keeps
                      // the shape the rest of the toolbar is built around (#69).
                      child: SizedBox(
                        width: 240,
                        height: 40,
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(color: AppColors.ink, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: context.l10n.iptvSearchChannels,
                            hintStyle: TextStyle(color: AppColors.inkAlpha(0.4), fontSize: 12.5),
                            prefixIcon: Icon(Icons.search_rounded, color: palette.primaryColor, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: context.l10n.commonClose,
                                    icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.raised,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.raised),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: palette.primaryColor, width: 1.4),
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ),

                    // Alive Sniffer Action
                    if (widget.portal != null) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCheckingAlive ? const Color(0xFFB91C1C) : palette.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isCheckingAlive
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                              )
                            : const Icon(Icons.speed_rounded, size: 16, color: AppColors.onAccent),
                        label: Text(
                          _isCheckingAlive ? context.l10n.iptvStopChecking(_aliveChecked, _aliveTotal) : context.l10n.iptvCheckHealth,
                          style: const TextStyle(color: AppColors.onAccent, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isCheckingAlive ? () => setState(() => _cancelAlive = true) : _startAliveCheck,
                      ),
                    ],

                    const SizedBox(width: 8),

                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: AppColors.inkMuted, size: 20),
                      tooltip: context.l10n.iptvCustomizeLayoutTooltip,
                      onPressed: () => _showBrowserCustomizer(context),
                    ),
                  ],
                ),
              )
            else
              // ── MOBILE RESPONSIVE HEADER ──
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.bar,
                  border: Border(
                    bottom: BorderSide(color: AppColors.edge, width: 1.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Bar: Back, Portal Title, Health button
                    Row(
                      children: [
                        IconButton(
                          tooltip: context.l10n.commonBack,
                          icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.primaryColor.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.settings_input_antenna_rounded, color: palette.primaryColor, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.portal != null)
                                Text(
                                  context.l10n.iptvConnAndExpiry(widget.portal!.activeConnections, widget.portal!.maxConnections, widget.portal!.expiry),
                                  style: TextStyle(color: AppColors.inkSubtle, fontSize: 10.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (widget.portal != null)
                          IconButton(
                            tooltip: context.l10n.iptvCheckHealth,
                            icon: _isCheckingAlive
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                  )
                                : const Icon(Icons.speed_rounded, color: Color(0xFF00D2EF), size: 20),
                            onPressed: _isCheckingAlive ? () => setState(() => _cancelAlive = true) : _startAliveCheck,
                          ),
                        IconButton(
                          icon: Icon(Icons.tune_rounded, color: AppColors.inkMuted, size: 20),
                          tooltip: context.l10n.iptvCustomize,
                          onPressed: () => _showBrowserCustomizer(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Controls Bar: the portal's channel category picker.
                    // No Live/Movies/Series switcher: those are the app's
                    // own sections, and repeating them here made a source
                    // browser look like a second media hub.
                    Row(
                      children: [
                        // Mobile Category Chip
                        InkWell(
                          onTap: () => _showMobileCategorySheet(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.raised,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_rounded, color: AppColors.accent, size: 15),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.32),
                                  child: Text(
                                    _selectedCategoryName(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.ink, fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent, size: 18),
                              ],
                            ),
                          ),
                        ),

                        // The region pill shares the row on mobile, icon-only
                        // like every other header pill at this width.
                        if (_regions.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _regionDropdown(),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Search Input
                    ClampedTextScale(
                      // A search pill is a fixed height by design, and a 13px
                      // field wants ~47px at 3x. The input caps; the box keeps
                      // the shape the rest of the toolbar is built around (#69).
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.raised),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(color: AppColors.ink, fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: context.l10n.iptvSearchInCategory,
                            hintStyle: TextStyle(color: AppColors.inkAlpha(0.35), fontSize: 12),
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: context.l10n.commonClose,
                                    icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── MAIN CONTENT (SPLIT VIEW ON DESKTOP, FULL-WIDTH ON MOBILE) ──
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 15)))
                      : isDesktop
                          ? Row(
                              children: [
                                // ── LEFT CATEGORIES PANEL ──
                                SizedBox(
                                  width: IptvSettings.sidebarWidth.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.canvas,
                                      border: Border(
                                        right: BorderSide(color: AppColors.edge, width: 1.2),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Categories Search Filter
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                          child: ClampedTextScale(
                                            // A search pill is a fixed height by design, and a 13px
                                            // field wants ~47px at 3x. The input caps; the box keeps
                                            // the shape the rest of the toolbar is built around (#69).
                                            child: Container(
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: AppColors.raised,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.raised),
                                              ),
                                              child: TextField(
                                                controller: _catSearchCtrl,
                                                style: TextStyle(color: AppColors.ink, fontSize: 12.5),
                                                decoration: InputDecoration(
                                                  hintText: context.l10n.iptvFilterCategories,
                                                  hintStyle: TextStyle(color: AppColors.inkAlpha(0.35), fontSize: 12),
                                                  prefixIcon: Icon(Icons.filter_list_rounded, color: AppColors.inkSubtle, size: 18),
                                                  suffixIcon: _catSearchQuery.isNotEmpty
                                                      ? IconButton(
                                                          tooltip: context.l10n.commonClose,
                                                          icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: 16),
                                                          onPressed: () {
                                                            _catSearchCtrl.clear();
                                                            setState(() => _catSearchQuery = '');
                                                          },
                                                        )
                                                      : null,
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                ),
                                                onChanged: (v) => setState(() => _catSearchQuery = v),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Category List with Desktop Vertical Scroll Arrows
                                        Expanded(
                                          child: ListView.builder(
                                                  controller: _categoryScrollController,
                                                  itemExtent: 46.0,
                                                  cacheExtent: 300.0,
                                                  addAutomaticKeepAlives: false,
                                                  addRepaintBoundaries: true,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  itemCount: _filteredCategories().length,
                                                  itemBuilder: (context, index) {
                                                    final cat = _filteredCategories()[index];
                                                    final isSelected = _selectedCategoryId == cat.id;
                                                    final count = _countForCategory(cat.id);

                                                    return _CategoryListRow(
                                                      category: cat,
                                                      count: count,
                                                      isSelected: isSelected,
                                                      onTap: () {
                                                        setState(() => _selectedCategoryId = cat.id);
                                                        _contentScrollController.jumpTo(0);
                                                      },
                                                    );
                                                  },
                                                ),

                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ── RIGHT CONTENT PANEL ──
                                Expanded(
                                  child: _buildMainContent(),
                                ),
                              ],
                            )
                          : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final streams = _filteredStreams();
    if (streams.isEmpty) {
      if (_selectedCategoryId == favoritesCategoryId) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.inkAlpha(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.push_pin_outlined, color: AppColors.inkSubtle, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.iptvNothingPinned,
                style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.iptvPinHint,
                style: TextStyle(color: AppColors.inkSubtle, fontSize: 13.5),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_off_rounded, color: AppColors.inkFaint, size: 48),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? context.l10n.iptvNoStreamsMatching(_searchQuery)
                  : context.l10n.iptvNoStreamsInCategory,
              style: TextStyle(color: AppColors.inkSubtle, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final isDesktop = _isDesktop(context);

    {
      // Live channels only -- the Movies & Series branch is gone (see the
      // class doc): a portal browser is a source browser, not a media hub.
      final layout = IptvSettings.browserLayout.value;

      if (layout == PortalBrowserLayout.grid) {
        final screenW = MediaQuery.sizeOf(context).width;
        int gridCols = IptvSettings.browserGridColumns.value;
        if (!isDesktop) {
          gridCols = screenW > 600 ? 3 : 2;
        }

        return GridView.builder(
          controller: _contentScrollController,
          cacheExtent: 400.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.fromLTRB(isDesktop ? 20 : 10, 12, isDesktop ? 20 : 10, 30),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridCols,
            childAspectRatio: 1.25,
            crossAxisSpacing: isDesktop ? 14 : 10,
            mainAxisSpacing: isDesktop ? 14 : 10,
          ),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            final isAlive = _aliveStreamIds.contains(stream.streamId);
            final isFav = _favoriteStreamIds.contains(stream.streamId);

            return _LiveChannelGridCard(
              key: ValueKey(stream.streamId),
              index: index + 1,
              stream: stream,
              portal: widget.portal,
              isAlive: isAlive,
              isFavorite: isFav,
              onToggleFavorite: () => _toggleFavoriteStream(stream.streamId),
              onTap: () => _playStream(stream),
            );
          },
        );
      } else if (layout == PortalBrowserLayout.compactList) {
        return ListView.builder(
          controller: _contentScrollController,
          itemExtent: 52.0,
          cacheExtent: 400.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.fromLTRB(isDesktop ? 20 : 10, 12, isDesktop ? 20 : 10, 30),
          physics: const BouncingScrollPhysics(),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            final isAlive = _aliveStreamIds.contains(stream.streamId);
            final isFav = _favoriteStreamIds.contains(stream.streamId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LiveChannelCompactListRow(
                key: ValueKey(stream.streamId),
                index: index + 1,
                stream: stream,
                portal: widget.portal,
                isAlive: isAlive,
                isFavorite: isFav,
                onToggleFavorite: () => _toggleFavoriteStream(stream.streamId),
                onTap: () => _playStream(stream),
              ),
            );
          },
        );
      } else {
        // Detailed List view
        return ListView.builder(
          controller: _contentScrollController,
          itemExtent: 78.0,
          cacheExtent: 400.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.fromLTRB(isDesktop ? 20 : 10, 12, isDesktop ? 20 : 10, 30),
          physics: const BouncingScrollPhysics(),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            final isAlive = _aliveStreamIds.contains(stream.streamId);
            final isFav = _favoriteStreamIds.contains(stream.streamId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LiveChannelListRow(
                key: ValueKey(stream.streamId),
                index: index + 1,
                stream: stream,
                portal: widget.portal,
                isAlive: isAlive,
                isFavorite: isFav,
                onToggleFavorite: () => _toggleFavoriteStream(stream.streamId),
                onTap: () => _playStream(stream),
              ),
            );
          },
        );
      }
    }
  }
}

class _CategoryListRow extends StatefulWidget {
  final IptvCategory category;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryListRow({
    required this.category,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryListRow> createState() => _CategoryListRowState();
}

class _CategoryListRowState extends State<_CategoryListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final isFavCategory = widget.category.id == _IptvPortalBrowserPageState.favoritesCategoryId;
    final showCount = IptvSettings.showCategoryCount.value;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? (isFavCategory ? AppColors.inkAlpha(0.15) : palette.primaryColor.withValues(alpha: 0.15))
                  : (_hovered ? AppColors.raised : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? (isFavCategory ? AppColors.inkAlpha(0.6) : palette.primaryColor.withValues(alpha: 0.6))
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? (isFavCategory ? AppColors.ink : palette.primaryColor)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                if (isFavCategory) ...[
                  Icon(Icons.push_pin_rounded, color: AppColors.inkMuted, size: 16),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    widget.category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isSelected
                          ? (isFavCategory ? const Color(0xFFFFD54F) : AppColors.ink)
                          : (_hovered ? AppColors.ink : (isFavCategory ? AppColors.ink : AppColors.inkMuted)),
                      fontSize: 12.5,
                      fontWeight: widget.isSelected ? FontWeight.w800 : (isFavCategory ? FontWeight.w700 : FontWeight.w600),
                    ),
                  ),
                ),
                if (showCount) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? (isFavCategory ? AppColors.inkAlpha(0.3) : palette.primaryColor.withValues(alpha: 0.3))
                          : (isFavCategory ? AppColors.inkAlpha(0.12) : AppColors.inkAlpha(0.06)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        color: isFavCategory
                            ? AppColors.ink
                            : (widget.isSelected ? palette.primaryColor : AppColors.inkDisabled),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChannelListRow extends StatefulWidget {
  final int index;
  final IptvStream stream;
  final VerifiedPortal? portal;
  final bool isAlive;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _LiveChannelListRow({
    super.key,
    required this.index,
    required this.stream,
    this.portal,
    required this.isAlive,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  State<_LiveChannelListRow> createState() => _LiveChannelListRowState();
}

class _LiveChannelListRowState extends State<_LiveChannelListRow> {
  bool _hovered = false;
  List<EpgEntry>? _cachedEpg;

  @override
  void initState() {
    super.initState();
    _cachedEpg = _IptvPortalBrowserPageState._sharedEpgCache[widget.stream.streamId];
  }

  void _loadEpg() async {
    if (!IptvSettings.showEpgSnippet.value) return;
    if (_cachedEpg != null || widget.portal == null || widget.stream.streamId.isEmpty) return;
    try {
      final entries = await IptvClient.shortEpg(widget.portal!.portal, widget.stream.streamId, limit: 2);
      if (mounted && entries.isNotEmpty) {
        _IptvPortalBrowserPageState._sharedEpgCache[widget.stream.streamId] = entries;
        setState(() => _cachedEpg = entries);
      }
    } catch (_) {
      // The now/next program is decoration on the channel card. Without it
      // the card still plays the channel.
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final s = widget.stream;
    final indexFormatted = widget.index.toString().padLeft(3, '0');
    final currentEpg = _cachedEpg?.isNotEmpty == true ? _cachedEpg!.first : null;
    final nextEpg = _cachedEpg != null && _cachedEpg!.length > 1 ? _cachedEpg![1] : null;
    final screenW = MediaQuery.sizeOf(context).width;
    final isVerySmall = screenW < 440;
    final showLogo = IptvSettings.showStreamLogos.value;
    final showEpg = IptvSettings.showEpgSnippet.value;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          _loadEpg();
        },
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 14, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.raised : AppColors.bar,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? palette.primaryColor.withValues(alpha: 0.7) : AppColors.edge,
                width: _hovered ? 1.4 : 1.0,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: palette.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Index
                if (!isVerySmall) ...[
                  SizedBox(
                    width: 30,
                    child: Text(
                      indexFormatted,
                      style: TextStyle(
                        color: AppColors.inkFaint,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // ── CHANNEL LOGO BAY ──
                if (showLogo) ...[
                  Container(
                    width: isVerySmall ? 52 : 64,
                    height: isVerySmall ? 40 : 46,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.edgeStrong),
                    ),
                    child: s.icon.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CachedNetworkImage(
                              imageUrl: s.icon,
                              fit: BoxFit.contain,
                              memCacheWidth: 128,
                              errorWidget: (_, _, _) => Icon(Icons.live_tv_rounded, color: AppColors.inkDisabled, size: 20),
                            ),
                          )
                        : Icon(Icons.live_tv_rounded, color: AppColors.inkDisabled, size: 20),
                  ),
                  SizedBox(width: isVerySmall ? 8 : 12),
                ],

                // Channel Title & EPG Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.isAlive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fiber_manual_record_rounded, color: Colors.greenAccent, size: 7),
                                  const SizedBox(width: 3),
                                  Text(
                                    context.l10n.iptvLive.toUpperCase(),
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (showEpg) ...[
                        const SizedBox(height: 2),
                        if (currentEpg != null) ...[
                          Text(
                            '${context.l10n.iptvNowPlaying(currentEpg.title)}${nextEpg != null ? "  |  ${context.l10n.iptvNextPlaying(nextEpg.title)}" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.inkAlpha(0.65), fontSize: 11),
                          ),
                        ] else ...[
                          Text(
                            context.l10n.iptvLiveFeed,
                            style: TextStyle(color: AppColors.inkAlpha(0.3), fontSize: 11),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Format Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.raised),
                  ),
                  child: Text(
                    s.containerExt.toUpperCase(),
                    style: TextStyle(color: AppColors.inkAlpha(0.60), fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ),

                const SizedBox(width: 6),

                // Favorite Button
                IconButton(
                  icon: Icon(
                    widget.isFavorite
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: widget.isFavorite ? AppColors.ink : AppColors.inkDisabled,
                    size: 21,
                  ),
                  // A pin, not a favorite: it keeps one provider's stream
                  // at hand while browsing this portal. Liking lives on the
                  // channel tile and survives the portal (roadmap #45), and
                  // the bookmark metaphor is already Watchlist's.
                  tooltip: widget.isFavorite
                      ? 'Unpin'
                      : 'Pin in this portal',
                  onPressed: widget.onToggleFavorite,
                ),

                const SizedBox(width: 4),

                // Play Icon Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hovered ? palette.primaryColor : AppColors.inkAlpha(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.ink,
                    size: 20,
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

class _LiveChannelGridCard extends StatefulWidget {
  final int index;
  final IptvStream stream;
  final VerifiedPortal? portal;
  final bool isAlive;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _LiveChannelGridCard({
    super.key,
    required this.index,
    required this.stream,
    this.portal,
    required this.isAlive,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  State<_LiveChannelGridCard> createState() => _LiveChannelGridCardState();
}

class _LiveChannelGridCardState extends State<_LiveChannelGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final s = widget.stream;
    final showLogo = IptvSettings.showStreamLogos.value;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.raised : AppColors.bar,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered ? palette.primaryColor.withValues(alpha: 0.8) : AppColors.edge,
                width: _hovered ? 1.5 : 1.0,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: palette.primaryColor.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: logo/index + live badge + star
                Row(
                  children: [
                    if (showLogo && s.icon.isNotEmpty)
                      Container(
                        width: 44,
                        height: 32,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.edgeStrong),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: s.icon,
                            fit: BoxFit.contain,
                            memCacheWidth: 100,
                            errorWidget: (_, _, _) => Icon(Icons.live_tv_rounded, color: AppColors.inkDisabled, size: 16),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inkAlpha(0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${widget.index}',
                          style: TextStyle(color: AppColors.inkSubtle, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),

                    const Spacer(),

                    if (widget.isAlive)
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(context.l10n.iptvLive.toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),

                    Tooltip(
                      message: widget.isFavorite
                          ? context.l10n.iptvRemoveFavorite
                          : context.l10n.iptvAddFavorite,
                      child: GestureDetector(
                        onTap: widget.onToggleFavorite,
                        child: Icon(
                          widget.isFavorite
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: widget.isFavorite
                              ? AppColors.ink
                              : AppColors.inkAlpha(0.30),
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Channel Title
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                // Bottom row: format tag + Play Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.raised),
                      ),
                      child: Text(
                        s.containerExt.toUpperCase(),
                        style: TextStyle(color: AppColors.inkAlpha(0.60), fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _hovered ? palette.primaryColor : AppColors.inkAlpha(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.ink,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChannelCompactListRow extends StatefulWidget {
  final int index;
  final IptvStream stream;
  final VerifiedPortal? portal;
  final bool isAlive;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _LiveChannelCompactListRow({
    super.key,
    required this.index,
    required this.stream,
    this.portal,
    required this.isAlive,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  State<_LiveChannelCompactListRow> createState() => _LiveChannelCompactListRowState();
}

class _LiveChannelCompactListRowState extends State<_LiveChannelCompactListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    final s = widget.stream;
    final showLogo = IptvSettings.showStreamLogos.value;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.raised : AppColors.bar,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hovered ? palette.primaryColor.withValues(alpha: 0.7) : AppColors.edge,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    widget.index.toString().padLeft(3, '0'),
                    style: TextStyle(color: AppColors.inkFaint, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
                if (showLogo && s.icon.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 32,
                    height: 24,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: s.icon,
                        fit: BoxFit.contain,
                        memCacheWidth: 64,
                        errorWidget: (_, _, _) => Icon(Icons.live_tv_rounded, color: AppColors.inkFaint, size: 14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isAlive) ...[
                  Container(
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(context.l10n.iptvLive.toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
                Tooltip(
                  message: widget.isFavorite
                      ? context.l10n.iptvRemoveFavorite
                      : context.l10n.iptvAddFavorite,
                  child: GestureDetector(
                    onTap: widget.onToggleFavorite,
                    child: Icon(
                      widget.isFavorite
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: widget.isFavorite
                          ? AppColors.ink
                          : AppColors.inkAlpha(0.30),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_arrow_rounded,
                  color: _hovered ? palette.primaryColor : AppColors.inkDisabled,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
