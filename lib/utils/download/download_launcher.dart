import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/download/download_task_model.dart';
import '../../models/movie/movie_detail.dart';
import '../../models/movie/video.dart';
import '../../models/stream/stream_model.dart';
import '../../services/download/download_service.dart';
import 'download_path_helper.dart';

/// Starts downloading [source] as [episode] of [detail] (or as the movie, when
/// [episode] is null), and says what happened in a snack bar.
///
/// Shared by the sources list's per-row download button and the video
/// player's own one, so a download started from either checks for a duplicate,
/// asks a phone where to save, and reports the same way. Two hand-written
/// copies would have drifted the first time one of them learned a new case.
Future<void> startSourceDownload(
  BuildContext context, {
  required MovieDetail detail,
  Video? episode,
  required StreamSource source,
}) async {
  final season = episode?.season;
  final episodeNumber = episode?.episode;
  final messenger = ScaffoldMessenger.of(context);

  final existing = DownloadService.instance.tasksNotifier.value.where((t) {
    return t.mediaId == detail.id &&
        t.season == season &&
        t.episode == episodeNumber;
  }).firstOrNull;

  if (existing != null) {
    if (existing.status == DownloadStatus.downloading) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Download already in progress in background.')),
      );
      return;
    } else if (existing.status == DownloadStatus.completed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This media is already downloaded.')),
      );
      return;
    }
  }

  try {
    String? customDir;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      customDir = await DownloadPathHelper.pickDownloadsDirectory();
      if (customDir == null) {
        // User canceled folder selection.
        return;
      }
    }

    await DownloadService.instance.startDownload(
      title: detail.name,
      mediaId: detail.id,
      type: detail.type,
      season: season,
      episode: episodeNumber,
      episodeTitle: episode?.title,
      posterUrl: detail.poster,
      backdropUrl: detail.background,
      year: detail.year,
      source: source,
      customDownloadDir: customDir,
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Download started in background. Track progress in Downloads tab.'),
        duration: Duration(seconds: 3),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Download failed to start: $e')),
    );
  }
}
