import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../models/movie/movie_section.dart';
import '../../services/addon/addon_manager.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/movie/movie_card.dart';
import '../../services/app_breakpoints.dart';

class DiscoverPage extends StatefulWidget {
  final String query;
  final bool isGenre;
  
  const DiscoverPage({
    super.key,
    required this.query,
    required this.isGenre,
  });

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool _isLoading = true;
  String? _error;
  List<MovieSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final manager = AddonManager.instance;
      List<MovieSection> sections;
      
      if (widget.isGenre) {
        sections = await manager.fetchByGenre(widget.query);
      } else {
        sections = await manager.searchAll(widget.query);
      }

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = AppBreakpoints.of(context) == ScreenTier.desktop;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        children: [
          // ── Main Content Grid ──
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            )
          else if (_error != null)
            ErrorView(
              error: _error,
              onRetry: _fetchData,
            )
          else if (_sections.isEmpty)
            Center(
              child: Text(
                'No results found for "${widget.query}"',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          else
            _buildSectionsList(topPadding + kToolbarHeight + 20),

          // ── Glass App Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: kToolbarHeight + topPadding,
                  padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C16).withValues(alpha: 0.6),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isGenre ? 'Genre: ${widget.query}' : 'Search: ${widget.query}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 22 : 20,
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

  Widget _buildSectionsList(double topPadding) {
    // Let's aggregate all movies across sections into a single responsive grid
    final allMoviesMap = <String, Movie>{};
    for (var section in _sections) {
      for (var movie in section.movies) {
        if (!allMoviesMap.containsKey(movie.id)) {
          allMoviesMap[movie.id] = movie;
        }
      }
    }
    final allMovies = allMoviesMap.values.toList();

    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        sizing.sidePadding,
        topPadding,
        sizing.sidePadding,
        40 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ((MediaQuery.sizeOf(context).width - sizing.sidePadding * 2 + sizing.spacing) / (sizing.cardWidth + sizing.spacing)).floor().clamp(2, 10),
        childAspectRatio: 1 / 1.48,
        crossAxisSpacing: sizing.spacing,
        mainAxisSpacing: sizing.spacing,
      ),
      itemCount: allMovies.length,
      itemBuilder: (context, index) {
        return MovieCard(
          movie: allMovies[index],
        );
      },
    );
  }
}
