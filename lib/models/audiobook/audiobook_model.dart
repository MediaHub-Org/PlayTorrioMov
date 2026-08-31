class Audiobook {
  final String uuid;
  final String audioBookId;
  final String dynamicSlugId;
  final String title;
  final String? author;
  final String coverImage;
  final String source;
  final String pageUrl;
  final List<String> categories;

  Audiobook({
    required this.uuid,
    required this.audioBookId,
    required this.dynamicSlugId,
    required this.title,
    this.author,
    required String coverImage,
    required this.source,
    required this.pageUrl,
    this.categories = const [],
  }) : coverImage = coverImage.trim();

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'audioBookId': audioBookId,
        'dynamicSlugId': dynamicSlugId,
        'title': title,
        'author': author,
        'coverImage': coverImage,
        'source': source,
        'pageUrl': pageUrl,
        'categories': categories,
      };

  factory Audiobook.fromJson(Map<String, dynamic> json) => Audiobook(
        uuid: (json['uuid'] ?? '').toString(),
        audioBookId: (json['audioBookId'] ?? '').toString(),
        dynamicSlugId: (json['dynamicSlugId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        author: json['author'] as String?,
        coverImage: (json['coverImage'] ?? '').toString().trim(),
        source: (json['source'] ?? '').toString(),
        pageUrl: (json['pageUrl'] ?? '').toString(),
        categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class AudiobookChapter {
  final String title;
  final String url;
  final Map<String, String>? httpHeaders;
  final bool isTorrent;
  final int? torrentFileIndex;

  AudiobookChapter({
    required this.title,
    required this.url,
    this.httpHeaders,
    this.isTorrent = false,
    this.torrentFileIndex,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'httpHeaders': httpHeaders,
        'isTorrent': isTorrent,
        'torrentFileIndex': torrentFileIndex,
      };

  factory AudiobookChapter.fromJson(Map<String, dynamic> json) => AudiobookChapter(
        title: json['title'] ?? '',
        url: json['url'] ?? '',
        httpHeaders: (json['httpHeaders'] as Map?)?.cast<String, String>(),
        isTorrent: json['isTorrent'] ?? false,
        torrentFileIndex: json['torrentFileIndex'],
      );
}
