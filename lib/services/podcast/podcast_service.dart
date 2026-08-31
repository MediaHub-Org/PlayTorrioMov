import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

/// A podcast search result from the iTunes Search API (free, no key needed).
class PodcastResult {
  final String id;
  final String name;
  final String artistName;
  final String artworkUrl;
  final String feedUrl;

  const PodcastResult({
    required this.id,
    required this.name,
    required this.artistName,
    required this.artworkUrl,
    required this.feedUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'feedUrl': feedUrl,
      };

  factory PodcastResult.fromJson(Map<String, dynamic> json) => PodcastResult(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        artistName: json['artistName']?.toString() ?? '',
        artworkUrl: json['artworkUrl']?.toString() ?? '',
        feedUrl: json['feedUrl']?.toString() ?? '',
      );
}

/// A single episode parsed out of a podcast's RSS feed.
class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final String pubDate;
  final String duration;

  const PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.pubDate,
    required this.duration,
  });
}

/// Podcasts via the iTunes Search API for discovery, then reads each
/// podcast's own RSS feed directly for episodes -- the standard way every
/// podcast app sources episode audio, no proprietary catalog needed.
class PodcastService {
  static const _searchBase = 'https://itunes.apple.com/search';
  static final _client = http.Client();

  Future<List<PodcastResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(_searchBase).replace(queryParameters: {
        'term': query,
        'media': 'podcast',
        'entity': 'podcast',
        'limit': '25',
      });
      final response = await _client.get(url);
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>? ?? [];
      return results
          .map((e) => e as Map<String, dynamic>)
          .where((e) => (e['feedUrl'] as String?)?.isNotEmpty == true)
          .map((e) => PodcastResult(
                id: '${e['collectionId']}',
                name: e['collectionName'] as String? ?? '',
                artistName: e['artistName'] as String? ?? '',
                artworkUrl: e['artworkUrl600'] as String? ?? e['artworkUrl100'] as String? ?? '',
                feedUrl: e['feedUrl'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PodcastEpisode>> fetchEpisodes(String feedUrl) async {
    try {
      final response = await _client.get(Uri.parse(feedUrl));
      if (response.statusCode != 200) return [];

      final document = XmlDocument.parse(response.body);
      final episodes = <PodcastEpisode>[];
      for (final item in document.findAllElements('item')) {
        final enclosure = item.findElements('enclosure').firstOrNull;
        final audioUrl = enclosure?.getAttribute('url') ?? '';
        if (audioUrl.isEmpty) continue;

        episodes.add(PodcastEpisode(
          title: item.findElements('title').firstOrNull?.innerText.trim() ?? 'Untitled episode',
          description: item.findElements('description').firstOrNull?.innerText.trim() ?? '',
          audioUrl: audioUrl,
          pubDate: item.findElements('pubDate').firstOrNull?.innerText.trim() ?? '',
          duration: item
                  .findElements('duration', namespaceUri: 'http://www.itunes.com/dtds/podcast-1.0.dtd')
                  .firstOrNull
                  ?.innerText
                  .trim() ??
              '',
        ));
      }
      return episodes;
    } catch (_) {
      return [];
    }
  }
}
