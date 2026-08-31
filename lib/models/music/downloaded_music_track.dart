import 'music_track.dart';

class DownloadedMusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String coverUrl;
  final int durationSeconds;
  final bool explicit;
  final String localAudioPath;
  final String localCoverPath;
  final String format; // 'flac', 'm4a', 'mp3'
  final String quality; // 'FLAC Hi-Res', 'YouTube HQ'
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final int? trackNumber;

  const DownloadedMusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId = '',
    required this.album,
    this.albumId = '',
    required this.coverUrl,
    required this.durationSeconds,
    this.explicit = false,
    required this.localAudioPath,
    required this.localCoverPath,
    required this.format,
    required this.quality,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.trackNumber,
  });

  MusicTrack toMusicTrack() {
    return MusicTrack(
      id: id,
      title: title,
      artist: artist,
      artistId: artistId,
      album: album,
      albumId: albumId,
      coverUrl: coverUrl,
      durationSeconds: durationSeconds,
      explicit: explicit,
      trackNumber: trackNumber,
    );
  }

  factory DownloadedMusicTrack.fromJson(Map<String, dynamic> json) {
    return DownloadedMusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      artistId: json['artistId']?.toString() ?? '',
      album: json['album']?.toString() ?? 'Single',
      albumId: json['albumId']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      explicit: json['explicit'] == true,
      localAudioPath: json['localAudioPath']?.toString() ?? '',
      localCoverPath: json['localCoverPath']?.toString() ?? '',
      format: json['format']?.toString() ?? 'm4a',
      quality: json['quality']?.toString() ?? 'HQ Audio',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artistId': artistId,
        'album': album,
        'albumId': albumId,
        'coverUrl': coverUrl,
        'durationSeconds': durationSeconds,
        'explicit': explicit,
        'localAudioPath': localAudioPath,
        'localCoverPath': localCoverPath,
        'format': format,
        'quality': quality,
        'fileSizeBytes': fileSizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
        if (trackNumber != null) 'trackNumber': trackNumber,
      };
}
