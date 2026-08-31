import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/movie/movie_section.dart';
import '../../models/stream/stream_model.dart';
import '../../services/addon/addon_manager.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../utils/search_scope.dart';
import '../../widgets/movie/movie_slider_section.dart';
import '../../widgets/search/magnet_files_view.dart';
import '../player/player_screen.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  Timer? _debounce;
  bool _isLoading = false;
  List<MovieSection> _results = [];
  String _lastQuery = '';

  bool _isMagnetMode = false;
  String _magnetQuery = '';

  static bool _isMagnetLink(String text) {
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith('magnet:')) return true;
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(trimmed)) return true;
    if (RegExp(r'^[a-zA-Z2-7]{32}$').hasMatch(trimmed)) return true;
    return false;
  }

  static bool _isStreamLink(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    return true;
  }

  void _playDirectStream(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    String title = 'Direct Stream';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty) {
        title = Uri.decodeComponent(last);
      }
    }

    Navigator.push(
      context,
      CinematicSlideRoute(
        page: PlayerScreen(
          source: StreamSource(
            name: 'Direct Stream',
            title: title,
            url: trimmed,
            addonName: 'Direct Stream',
          ),
          title: title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results.clear();
        _isLoading = false;
        _lastQuery = '';
        _isMagnetMode = false;
        _magnetQuery = '';
      });
      return;
    }

    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
      });
      return;
    } else if (_isMagnetMode) {
      setState(() {
        _isMagnetMode = false;
        _magnetQuery = '';
      });
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (trimmed != _lastQuery) {
        _performSearch(trimmed);
      }
    });
  }

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (_isStreamLink(trimmed)) {
      _playDirectStream(trimmed);
      return;
    }

    if (_isMagnetLink(trimmed)) {
      setState(() {
        _isMagnetMode = true;
        _magnetQuery = trimmed;
        _isLoading = false;
        _results.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastQuery = trimmed;
      _isMagnetMode = false;
    });

    try {
      final results = await AddonManager.instance.searchAll(
        trimmed,
        contentType: SearchScope.contentType,
      );
      if (!mounted) return;
      
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _results = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: EdgeInsets.only(top: topPadding, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF080A0F).withValues(alpha: 0.90),
                    const Color(0xFF080A0F).withValues(alpha: 0.60),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            hintText: SearchScope.label != null
                                ? 'Search ${SearchScope.label}...'
                                : 'Search movies and shows, paste magnet or stream link',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    color: Colors.white60,
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: Colors.white54,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_isMagnetMode && _magnetQuery.isNotEmpty)
            MagnetFilesView(
              key: ValueKey(_magnetQuery),
              magnet: _magnetQuery,
            )
          else if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            )
          else if (_lastQuery.isNotEmpty && _results.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_lastQuery"',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (_results.isNotEmpty)
            ListView.builder(
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(
                top: topPadding + kToolbarHeight + 40,
                bottom: 40 + MediaQuery.paddingOf(context).bottom,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return MovieSliderSection(section: _results[index]);
              },
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.manage_search_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    SearchScope.label != null
                        ? 'Search ${SearchScope.label}'
                        : 'Search across all addons',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
