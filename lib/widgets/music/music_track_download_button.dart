import 'package:flutter/material.dart';

import '../../models/music/music_track.dart';
import '../../services/music/music_download_service.dart';

/// Download-state icon button for a [MusicTrack]: queue for download, show
/// progress while downloading, or a "downloaded" badge once complete.
/// Shared between track list rows and the now-playing player so both use
/// identical download logic/state reads instead of duplicating it.
class MusicTrackDownloadButton extends StatelessWidget {
  final MusicTrack track;
  final double iconSize;
  final Color idleColor;

  const MusicTrackDownloadButton({
    super.key,
    required this.track,
    this.iconSize = 18,
    this.idleColor = Colors.white38,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = MusicDownloadService.instance.isDownloaded(track.id);
    final task = MusicDownloadService.instance.getTask(track.id);
    final isDownloading = task != null &&
        (task.status == MusicDownloadStatus.extracting || task.status == MusicDownloadStatus.downloading);
    final isQueued = task != null && task.status == MusicDownloadStatus.queued;

    if (isDownloaded) {
      return Tooltip(
        message: 'Downloaded (Offline)',
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.download_done_rounded,
            color: const Color(0xFF00E5FF),
            size: iconSize,
          ),
        ),
      );
    }

    if (isDownloading) {
      return Tooltip(
        message: 'Downloading ${(task.progress * 100).toInt()}%',
        child: SizedBox(
          width: iconSize + 10,
          height: iconSize + 10,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: CircularProgressIndicator(
              value: task.progress > 0.05 ? task.progress : null,
              strokeWidth: 2.2,
              color: const Color(0xFF00E5FF),
            ),
          ),
        ),
      );
    }

    if (isQueued) {
      return Tooltip(
        message: 'Queued for download',
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.hourglass_top_rounded,
            color: Colors.amberAccent,
            size: iconSize,
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.download_rounded, color: idleColor, size: iconSize),
      tooltip: 'Download Track',
      onPressed: () {
        MusicDownloadService.instance.queueTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.title}" to download queue'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
