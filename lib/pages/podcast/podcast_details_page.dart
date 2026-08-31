import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/podcast/podcast_library_service.dart';
import '../../services/podcast/podcast_player_controller.dart';
import '../../services/podcast/podcast_service.dart';
import '../../widgets/common/like_button.dart';

/// Episode list for one podcast, fetched live from its RSS feed.
class PodcastDetailsPage extends StatefulWidget {
  final PodcastResult podcast;

  const PodcastDetailsPage({super.key, required this.podcast});

  @override
  State<PodcastDetailsPage> createState() => _PodcastDetailsPageState();
}

class _PodcastDetailsPageState extends State<PodcastDetailsPage> {
  final PodcastService _service = PodcastService();
  final PodcastPlayerController _player = PodcastPlayerController.instance;

  List<PodcastEpisode> _episodes = [];
  bool _loading = true;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _load();
    _player.addListener(_onPlayerChanged);
    PodcastLibraryService.instance.init();
    _isLiked = PodcastLibraryService.instance.isLiked(widget.podcast.id);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    await PodcastLibraryService.instance.toggleLike(widget.podcast);
    if (mounted) {
      setState(() => _isLiked = PodcastLibraryService.instance.isLiked(widget.podcast.id));
    }
  }

  Future<void> _load() async {
    final episodes = await _service.fetchEpisodes(widget.podcast.feedUrl);
    if (mounted) {
      setState(() {
        _episodes = episodes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080A0F),
        title: Text(widget.podcast.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          LikeButton(
            isLiked: _isLiked,
            onTap: _toggleLike,
            style: LikeButtonStyle.icon,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF)))
          : _episodes.isEmpty
              ? const Center(
                  child: Text('No episodes found in this feed.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    final isCurrent = _player.episode?.audioUrl == episode.audioUrl;
                    return _EpisodeRow(
                      episode: episode,
                      artworkUrl: widget.podcast.artworkUrl,
                      isCurrent: isCurrent,
                      isPlaying: isCurrent && _player.isPlaying,
                      isLoading: isCurrent && _player.isLoading,
                      onTap: () {
                        if (isCurrent) {
                          _player.togglePlayPause();
                        } else {
                          _player.play(widget.podcast, episode);
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final PodcastEpisode episode;
  final String artworkUrl;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  const _EpisodeRow({
    required this.episode,
    required this.artworkUrl,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent ? const Color(0xFF7C5CFF).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: artworkUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: artworkUrl, width: 52, height: 52, fit: BoxFit.cover)
                    : Container(width: 52, height: 52, color: Colors.white10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      style: TextStyle(
                        color: isCurrent ? const Color(0xFF7C5CFF) : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.duration.isNotEmpty || episode.pubDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [episode.duration, episode.pubDate].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFF)),
                    )
                  : Icon(
                      isCurrent && isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: const Color(0xFF7C5CFF),
                      size: 30,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
