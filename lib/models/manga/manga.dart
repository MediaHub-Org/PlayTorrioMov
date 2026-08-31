class Manga {
  final String id;
  final String title;
  final String coverSmall;
  final String coverNormal;
  final String type;
  final String status;
  final String year;
  final String author;
  final List<String> tags;
  final String synopsis;
  final String url;

  Manga({
    required this.id,
    required this.title,
    required this.coverSmall,
    required this.coverNormal,
    this.type = '',
    this.status = '',
    this.year = '',
    this.author = '',
    this.tags = const [],
    this.synopsis = '',
    this.url = '',
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverSmall: json['cover_small'] ?? '',
      coverNormal: json['cover_normal'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      year: json['year'] ?? '',
      author: json['author'] ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      synopsis: json['synopsis'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_small': coverSmall,
      'cover_normal': coverNormal,
      'type': type,
      'status': status,
      'year': year,
      'author': author,
      'tags': tags,
      'synopsis': synopsis,
      'url': url,
    };
  }
}
