import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/podcast/podcast_service.dart';
import 'podcast_details_page.dart';

/// Podcasts section in the Listen hub: search via the iTunes Search API
/// (free, no key), then read episodes straight from each show's own RSS
/// feed -- the standard way podcast audio is sourced.
class PodcastsPage extends StatefulWidget {
  const PodcastsPage({super.key});

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage> {
  final PodcastService _service = PodcastService();
  final TextEditingController _searchController = TextEditingController();

  List<PodcastResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600 ? 2 : (width < 900 ? 3 : (width < 1200 ? 4 : 5));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Podcasts',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: 'Search podcasts...',
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
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF))),
          )
        else if (_hasSearched && _results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No podcasts found.', style: TextStyle(color: Colors.white54))),
          )
        else if (!_hasSearched)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.podcasts_rounded, color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text('Search for a podcast to get started', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PodcastCard(podcast: _results[index]),
                childCount: _results.length,
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _PodcastCard extends StatelessWidget {
  final PodcastResult podcast;

  const _PodcastCard({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PodcastDetailsPage(podcast: podcast)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: podcast.artworkUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: podcast.artworkUrl, fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: Colors.white10,
                      child: const Icon(Icons.podcasts_rounded, color: Colors.white24, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            podcast.name,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            podcast.artistName,
            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
