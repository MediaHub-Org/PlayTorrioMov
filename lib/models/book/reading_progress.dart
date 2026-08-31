class ReadingProgress {
  final String md5;
  final String title;
  final String author;
  final String coverUrl;
  final String filePath;
  final String fileType;
  final int chapterIndex;
  final double scrollOffset;
  final double progressPercent;
  final int totalChapters;
  final DateTime lastReadAt;
  final int totalPages;
  final int currentPage;

  const ReadingProgress({
    required this.md5,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.filePath,
    required this.fileType,
    this.chapterIndex = 0,
    this.scrollOffset = 0.0,
    this.progressPercent = 0.0,
    this.totalChapters = 1,
    this.totalPages = 1,
    this.currentPage = 1,
    required this.lastReadAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      md5: json['md5']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      filePath: json['filePath']?.toString() ?? '',
      fileType: json['fileType']?.toString().toLowerCase() ?? 'epub',
      chapterIndex: json['chapterIndex'] is int ? json['chapterIndex'] as int : int.tryParse('${json['chapterIndex']}') ?? 0,
      scrollOffset: (json['scrollOffset'] is num) ? (json['scrollOffset'] as num).toDouble() : 0.0,
      progressPercent: (json['progressPercent'] is num) ? (json['progressPercent'] as num).toDouble() : 0.0,
      totalChapters: json['totalChapters'] is int ? json['totalChapters'] as int : int.tryParse('${json['totalChapters']}') ?? 1,
      totalPages: json['totalPages'] is int ? json['totalPages'] as int : int.tryParse('${json['totalPages']}') ?? 1,
      currentPage: json['currentPage'] is int ? json['currentPage'] as int : int.tryParse('${json['currentPage']}') ?? 1,
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'md5': md5,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'filePath': filePath,
      'fileType': fileType,
      'chapterIndex': chapterIndex,
      'scrollOffset': scrollOffset,
      'progressPercent': progressPercent,
      'totalChapters': totalChapters,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'lastReadAt': lastReadAt.toIso8601String(),
    };
  }

  ReadingProgress copyWith({
    String? md5,
    String? title,
    String? author,
    String? coverUrl,
    String? filePath,
    String? fileType,
    int? chapterIndex,
    double? scrollOffset,
    double? progressPercent,
    int? totalChapters,
    int? totalPages,
    int? currentPage,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      md5: md5 ?? this.md5,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      progressPercent: progressPercent ?? this.progressPercent,
      totalChapters: totalChapters ?? this.totalChapters,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
