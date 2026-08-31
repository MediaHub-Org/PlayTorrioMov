class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  final String coverUrl;
  final int durationSeconds;
  final bool explicit;
  final String? previewUrl;
  final int? trackNumber;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId = '',
    required this.album,
    this.albumId = '',
    required this.coverUrl,
    required this.durationSeconds,
    this.explicit = false,
    this.previewUrl,
    this.trackNumber,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final albumData = json['album'] is Map<String, dynamic>
        ? json['album'] as Map<String, dynamic>
        : {};
    final artistData = json['artist'] is Map<String, dynamic>
        ? json['artist'] as Map<String, dynamic>
        : {};

    String cover = albumData['cover_xl']?.toString() ??
        albumData['cover_big']?.toString() ??
        albumData['cover_medium']?.toString() ??
        albumData['cover_small']?.toString() ??
        json['cover_xl']?.toString() ??
        json['cover_big']?.toString() ??
        json['cover_medium']?.toString() ??
        json['cover_small']?.toString() ??
        json['cover']?.toString() ??
        json['coverUrl']?.toString() ??
        '';

    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    final explicitVal = json['explicit_lyrics'] ?? json['explicit'];

    return MusicTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          json['title_short']?.toString() ??
          'Unknown Track',
      artist: artistData['name']?.toString() ??
          json['artist']?.toString() ??
          'Unknown Artist',
      artistId: artistData['id']?.toString() ??
          json['artistId']?.toString() ??
          '',
      album: albumData['title']?.toString() ??
          json['album']?.toString() ??
          'Single',
      albumId: albumData['id']?.toString() ??
          json['albumId']?.toString() ??
          '',
      coverUrl: cover,
      durationSeconds: int.tryParse(
            json['duration']?.toString() ??
                json['durationSeconds']?.toString() ??
                '',
          ) ??
          0,
      explicit: explicitVal == true || explicitVal == 1,
      previewUrl: json['preview']?.toString() ?? json['previewUrl']?.toString(),
      trackNumber: int.tryParse(
        json['track_position']?.toString() ??
            json['trackNumber']?.toString() ??
            '',
      ),
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
        if (previewUrl != null) 'previewUrl': previewUrl,
        if (trackNumber != null) 'trackNumber': trackNumber,
      };

  String get formattedDuration {
    if (durationSeconds <= 0) return '--:--';
    final mins = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? artistId,
    String? album,
    String? albumId,
    String? coverUrl,
    int? durationSeconds,
    bool? explicit,
    String? previewUrl,
    int? trackNumber,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      explicit: explicit ?? this.explicit,
      previewUrl: previewUrl ?? this.previewUrl,
      trackNumber: trackNumber ?? this.trackNumber,
    );
  }
}

class MusicArtist {
  final String id;
  final String name;
  final String pictureUrl;
  final int fanCount;
  final int albumCount;

  const MusicArtist({
    required this.id,
    required this.name,
    required this.pictureUrl,
    this.fanCount = 0,
    this.albumCount = 0,
  });

  factory MusicArtist.fromJson(Map<String, dynamic> json) {
    String pic = json['picture_xl']?.toString() ??
        json['picture_big']?.toString() ??
        json['picture_medium']?.toString() ??
        json['picture_small']?.toString() ??
        json['picture']?.toString() ??
        json['pictureUrl']?.toString() ??
        '';
    if (pic.startsWith('http://')) {
      pic = pic.replaceFirst('http://', 'https://');
    }
    return MusicArtist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artist',
      pictureUrl: pic,
      fanCount: int.tryParse(
            json['nb_fan']?.toString() ??
                json['nbFan']?.toString() ??
                json['fanCount']?.toString() ??
                '',
          ) ??
          0,
      albumCount: int.tryParse(
            json['nb_album']?.toString() ??
                json['nbAlbum']?.toString() ??
                json['albumCount']?.toString() ??
                '',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pictureUrl': pictureUrl,
        'fanCount': fanCount,
        'albumCount': albumCount,
      };
}

class MusicAlbum {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String coverUrl;
  final String releaseDate;
  final int trackCount;
  final List<MusicTrack> tracks;

  const MusicAlbum({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId = '',
    required this.coverUrl,
    this.releaseDate = '',
    this.trackCount = 0,
    this.tracks = const [],
  });

  factory MusicAlbum.fromJson(Map<String, dynamic> json) {
    final artistData = json['artist'] is Map<String, dynamic>
        ? json['artist'] as Map<String, dynamic>
        : {};
    String cover = json['cover_xl']?.toString() ??
        json['cover_big']?.toString() ??
        json['cover_medium']?.toString() ??
        json['cover_small']?.toString() ??
        json['cover']?.toString() ??
        json['coverUrl']?.toString() ??
        '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    List<MusicTrack> parsedTracks = [];
    final tracksObj = json['tracks'];
    if (tracksObj is Map<String, dynamic> && tracksObj['data'] is List) {
      parsedTracks = (tracksObj['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((t) => MusicTrack.fromJson(t))
          .toList();
    } else if (tracksObj is List) {
      parsedTracks = tracksObj
          .whereType<Map<String, dynamic>>()
          .map((t) => MusicTrack.fromJson(t))
          .toList();
    }

    return MusicAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Album',
      artistName: artistData['name']?.toString() ??
          json['artistName']?.toString() ??
          'Unknown Artist',
      artistId: artistData['id']?.toString() ??
          json['artistId']?.toString() ??
          '',
      coverUrl: cover,
      releaseDate: json['release_date']?.toString() ??
          json['releaseDate']?.toString() ??
          '',
      trackCount: int.tryParse(
            json['nb_tracks']?.toString() ??
                json['nbTracks']?.toString() ??
                json['trackCount']?.toString() ??
                '',
          ) ??
          parsedTracks.length,
      tracks: parsedTracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artistName': artistName,
        'artistId': artistId,
        'coverUrl': coverUrl,
        'releaseDate': releaseDate,
        'trackCount': trackCount,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

class MusicPlaylist {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final int trackCount;
  final String creatorName;
  final List<MusicTrack> tracks;

  const MusicPlaylist({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.trackCount,
    this.creatorName = '',
    this.tracks = const [],
  });

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) {
    final creatorData = json['creator'] is Map<String, dynamic>
        ? json['creator'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : {});

    String cover = json['picture_xl']?.toString() ??
        json['picture_big']?.toString() ??
        json['picture_medium']?.toString() ??
        json['picture_small']?.toString() ??
        json['picture']?.toString() ??
        json['coverUrl']?.toString() ??
        '';
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    List<MusicTrack> parsedTracks = [];
    final tracksObj = json['tracks'];
    if (tracksObj is Map<String, dynamic> && tracksObj['data'] is List) {
      parsedTracks = (tracksObj['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((t) => MusicTrack.fromJson(t))
          .toList();
    } else if (tracksObj is List) {
      parsedTracks = tracksObj
          .whereType<Map<String, dynamic>>()
          .map((t) => MusicTrack.fromJson(t))
          .toList();
    }

    return MusicPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Playlist',
      description: json['description']?.toString() ?? '',
      coverUrl: cover,
      trackCount: int.tryParse(
            json['nb_tracks']?.toString() ??
                json['nbTracks']?.toString() ??
                json['trackCount']?.toString() ??
                '',
          ) ??
          parsedTracks.length,
      creatorName: creatorData['name']?.toString() ??
          json['creatorName']?.toString() ??
          'Deezer',
      tracks: parsedTracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'coverUrl': coverUrl,
        'trackCount': trackCount,
        'creatorName': creatorName,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

class MusicGenre {
  final String id;
  final String name;
  final String pictureUrl;

  const MusicGenre({
    required this.id,
    required this.name,
    required this.pictureUrl,
  });

  factory MusicGenre.fromJson(Map<String, dynamic> json) {
    String pic = json['picture_xl']?.toString() ??
        json['picture_big']?.toString() ??
        json['picture_medium']?.toString() ??
        json['picture_small']?.toString() ??
        json['picture']?.toString() ??
        '';
    if (pic.startsWith('http://')) {
      pic = pic.replaceFirst('http://', 'https://');
    }
    return MusicGenre(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Genre',
      pictureUrl: pic,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pictureUrl': pictureUrl,
      };
}

class SyncedLyricLine {
  final Duration timestamp;
  final String text;

  const SyncedLyricLine({
    required this.timestamp,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        'text': text,
      };

  factory SyncedLyricLine.fromJson(Map<String, dynamic> json) =>
      SyncedLyricLine(
        timestamp: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
        text: json['text'] as String? ?? '',
      );
}

class LyricsData {
  final String trackId;
  final bool isSynced;
  final String plainLyrics;
  final List<SyncedLyricLine> syncedLines;

  const LyricsData({
    required this.trackId,
    required this.isSynced,
    required this.plainLyrics,
    required this.syncedLines,
  });

  static LyricsData empty() => const LyricsData(
        trackId: '',
        isSynced: false,
        plainLyrics: '',
        syncedLines: [],
      );

  int activeLineIndex(Duration position) {
    if (!isSynced || syncedLines.isEmpty) return -1;
    for (int i = syncedLines.length - 1; i >= 0; i--) {
      if (position >= syncedLines[i].timestamp) {
        return i;
      }
    }
    return -1;
  }
}

class MusicSearchData {
  final List<MusicTrack> tracks;
  final List<MusicArtist> artists;
  final List<MusicAlbum> albums;
  final List<MusicPlaylist> playlists;

  const MusicSearchData({
    required this.tracks,
    required this.artists,
    required this.albums,
    this.playlists = const [],
  });

  static const MusicSearchData empty = MusicSearchData(
    tracks: [],
    artists: [],
    albums: [],
    playlists: [],
  );
}

class MusicArtistDetails {
  final MusicArtist artist;
  final List<MusicTrack> topTracks;
  final List<MusicAlbum> albums;
  final List<MusicArtist> relatedArtists;

  const MusicArtistDetails({
    required this.artist,
    required this.topTracks,
    required this.albums,
    required this.relatedArtists,
  });
}

class MusicAlbumDetails {
  final MusicAlbum album;
  final List<MusicTrack> tracks;

  const MusicAlbumDetails({
    required this.album,
    required this.tracks,
  });
}

class MusicPlaylistDetails {
  final MusicPlaylist playlist;
  final List<MusicTrack> tracks;

  const MusicPlaylistDetails({
    required this.playlist,
    required this.tracks,
  });
}

class UserPlaylist {
  final String id;
  final String title;
  final String createdAt;
  final List<MusicTrack> tracks;

  UserPlaylist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.tracks,
  });

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'My Playlist',
      createdAt: json['createdAt']?.toString() ?? '',
      tracks: (json['tracks'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((t) => MusicTrack.fromJson(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}
