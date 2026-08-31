class BookResult {
  final int id;
  final String title;
  final String author;
  final String md5;
  final String link;
  final String bookImage;
  final String bookFiletype;
  final String bookLang;
  final String bookSize;
  final String bookLength;
  final String description;
  final String publisher;
  final String year;
  final String series;
  final String isbn;
  final String cid;
  final String externalCoverUrl;
  final String otherTitles;

  const BookResult({
    this.id = 0,
    required this.title,
    required this.author,
    required this.md5,
    required this.link,
    required this.bookImage,
    required this.bookFiletype,
    this.bookLang = '',
    this.bookSize = '',
    this.bookLength = '',
    this.description = '',
    this.publisher = '',
    this.year = '',
    this.series = '',
    this.isbn = '',
    this.cid = '',
    this.externalCoverUrl = '',
    this.otherTitles = '',
  });

  factory BookResult.fromJson(Map<String, dynamic> json) {
    return BookResult(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString().trim(),
      author: (json['author'] ?? '').toString().trim(),
      md5: (json['md5'] ?? '').toString().trim(),
      link: (json['link'] ?? '').toString().trim(),
      bookImage: (json['book_image'] ?? '').toString().trim(),
      bookFiletype: (json['book_filetype'] ?? 'epub').toString().trim().toLowerCase(),
      bookLang: (json['book_lang'] ?? '').toString().trim(),
      bookSize: (json['book_size'] ?? '').toString().trim(),
      bookLength: (json['book_length'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      publisher: (json['publisher'] ?? '').toString().trim(),
      year: (json['year'] ?? '').toString().trim(),
      series: (json['series'] ?? '').toString().trim(),
      isbn: (json['isbn'] ?? '').toString().trim(),
      cid: (json['cid'] ?? '').toString().trim(),
      externalCoverUrl: (json['external_cover_url'] ?? '').toString().trim(),
      otherTitles: (json['other_titles'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'md5': md5,
      'link': link,
      'book_image': bookImage,
      'book_filetype': bookFiletype,
      'book_lang': bookLang,
      'book_size': bookSize,
      'book_length': bookLength,
      'description': description,
      'publisher': publisher,
      'year': year,
      'series': series,
      'isbn': isbn,
      'cid': cid,
      'external_cover_url': externalCoverUrl,
      'other_titles': otherTitles,
    };
  }

  bool get isEpub => bookFiletype == 'epub';
  bool get isPdf => bookFiletype == 'pdf';
  bool get isFb2 => bookFiletype == 'fb2' || bookFiletype == 'fb2.zip';
  bool get isMobi => bookFiletype == 'mobi';
  bool get isAzw3 => bookFiletype == 'azw3' || bookFiletype == 'azw' || bookFiletype == 'kf8';
  bool get isTxt => bookFiletype == 'txt';
  bool get isComic => bookFiletype == 'cbz' || bookFiletype == 'cbr';
  bool get isLit => bookFiletype == 'lit';
  bool get isLrf => bookFiletype == 'lrf';
  bool get isSupportedReaderFormat => !isLit && !isLrf;

  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (otherTitles.isNotEmpty) return otherTitles;
    return 'Untitled Book';
  }

  String get displayAuthor {
    if (author.isEmpty) return 'Unknown Author';
    // Clean up separated authors (e.g. "Rowling, J. K.; Watson, Emma" -> "J. K. Rowling, Emma Watson")
    return author.replaceAll(';', ', ').trim();
  }

  String get coverUrl {
    if (bookImage.isNotEmpty) return bookImage;
    if (externalCoverUrl.isNotEmpty) return externalCoverUrl;
    if (md5.isNotEmpty) {
      return 'https://api.bookracy.com/cover/$md5/thumbnail.jpg?title=${Uri.encodeComponent(title)}&author=${Uri.encodeComponent(author)}';
    }
    return '';
  }

  String get downloadUrl {
    if (link.isNotEmpty) return link;
    if (md5.isNotEmpty) {
      final ext = bookFiletype.isNotEmpty ? bookFiletype : 'epub';
      return 'https://api.bookracy.com/download/$md5/${Uri.encodeComponent(title)}.$ext?author=${Uri.encodeComponent(author)}';
    }
    return '';
  }
}
