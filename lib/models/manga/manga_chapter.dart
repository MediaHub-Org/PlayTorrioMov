class MangaChapter {
  final String id;
  final double number;
  final String name;
  final String url;
  final String rawName;

  MangaChapter({
    required this.id,
    required this.number,
    this.name = '',
    this.url = '',
    this.rawName = '',
  });

  factory MangaChapter.fromRaw(String id, String rawName, String url) {
    var cleanRaw = rawName.replaceAll(RegExp(r'Last Read', caseSensitive: false), '').trim();

    // Match numbers like 1, 1.5, 100, 0.5
    final numberMatch = RegExp(r'(?:chapter|ch\.?|\b)\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(cleanRaw) ??
        RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleanRaw);

    final double number = numberMatch != null ? (double.tryParse(numberMatch.group(1)!) ?? 0.0) : 0.0;

    String title = '';
    final separatorMatch = RegExp(r'[:\-–]\s*(.+)').firstMatch(cleanRaw);
    if (separatorMatch != null) {
      title = separatorMatch.group(1)!.trim();
    } else {
      title = cleanRaw;
    }

    if (title.isEmpty || title.toLowerCase() == 'last read') {
      title = number > 0 ? 'Chapter $number' : cleanRaw;
    }

    return MangaChapter(
      id: id,
      number: number,
      name: title,
      url: url,
      rawName: cleanRaw,
    );
  }

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id']?.toString() ?? '',
      number: (json['number'] is String
              ? double.tryParse(json['number']) ?? 0
              : json['number'] ?? 0)
          .toDouble(),
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      rawName: json['raw_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'url': url,
      'raw_name': rawName,
    };
  }
}
