import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as hp;

/// Ported from PlayTorrioV2's `lib/api/books_service.dart`. Scrapes
/// libgen.li (a live LibGen mirror) for epub-only search results, then
/// resolves an edition id through to a real download URL.
class BookResult {
  final String title;
  final String series;
  final String author;
  final String publisher;
  final String year;
  final String language;
  final String pages;
  final String size;
  final String format;
  final String isbn;
  final String editionId;
  final String editionUrl;
  final String fileId;

  const BookResult({
    required this.title,
    required this.series,
    required this.author,
    required this.publisher,
    required this.year,
    required this.language,
    required this.pages,
    required this.size,
    required this.format,
    required this.isbn,
    required this.editionId,
    required this.editionUrl,
    required this.fileId,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'series': series,
        'author': author,
        'publisher': publisher,
        'year': year,
        'language': language,
        'pages': pages,
        'size': size,
        'format': format,
        'isbn': isbn,
        'editionId': editionId,
        'editionUrl': editionUrl,
        'fileId': fileId,
      };

  factory BookResult.fromJson(Map<String, dynamic> json) => BookResult(
        title: json['title'] ?? '',
        series: json['series'] ?? '',
        author: json['author'] ?? '',
        publisher: json['publisher'] ?? '',
        year: json['year'] ?? '',
        language: json['language'] ?? '',
        pages: json['pages'] ?? '',
        size: json['size'] ?? '',
        format: json['format'] ?? '',
        isbn: json['isbn'] ?? '',
        editionId: json['editionId'] ?? '',
        editionUrl: json['editionUrl'] ?? '',
        fileId: json['fileId'] ?? '',
      );
}

class BookEditionDetails {
  final String editionId;
  final String md5;
  final String adsUrl;

  const BookEditionDetails({
    required this.editionId,
    required this.md5,
    required this.adsUrl,
  });
}

class BooksService {
  static const String _base = 'https://libgen.li';

  static final _client = http.Client();

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  /// Searches libgen.li and returns only epub results (mirrors the site's
  /// own format filter -- other formats need different reader handling).
  Future<List<BookResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse('$_base/index.php?req=${Uri.encodeComponent(query)}&curtab=f');
      final response = await _client.get(url, headers: _headers);
      if (response.statusCode != 200) return [];
      return _parseResults(response.body);
    } catch (_) {
      return [];
    }
  }

  /// The site's own "recently added" feed, same fiction/epub tab as
  /// [search] (`curtab=f`) so the browse grid and search results parse
  /// identically -- gives the Books section something to show before a
  /// user types a query, matching every other Read-hub section.
  Future<List<BookResult>> browseRecent() async {
    try {
      final url = Uri.parse('$_base/index.php?req=mode:last&curtab=f');
      final response = await _client.get(url, headers: _headers);
      if (response.statusCode != 200) return [];
      return _parseResults(response.body);
    } catch (_) {
      return [];
    }
  }

  List<BookResult> _parseResults(String html) {
    final document = hp.parse(html);
    final results = <BookResult>[];
    final rows = document.querySelectorAll('table tbody tr, table tr');

    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.length < 8) continue;

      final firstTd = tds[0];
      final titleLink = firstTd.querySelector('a[href*="edition.php"]');
      if (titleLink == null) continue;

      final title = titleLink.text.trim();
      if (title.isEmpty) continue;

      final editionHref = titleLink.attributes['href'] ?? '';
      final editionId = RegExp(r'id=(\d+)').firstMatch(editionHref)?.group(1);
      if (editionId == null || editionId.isEmpty) continue;

      final series = firstTd.querySelector('b')?.text.trim() ?? '';
      final isbn = firstTd.querySelector('font[color="green"]')?.text.trim() ?? '';
      final fileId = firstTd.querySelector('.badge-secondary')?.text.trim() ?? '';

      final author = tds[1].text.trim();
      final publisher = tds[2].text.trim();
      final year = tds[3].text.trim();
      final language = tds[4].text.trim();
      final pages = tds[5].text.trim();

      final sizeTd = tds[6];
      final size = sizeTd.querySelector('a')?.text.trim().isNotEmpty == true
          ? sizeTd.querySelector('a')!.text.trim()
          : sizeTd.text.trim();

      final format = tds[7].text.trim();
      if (format.toLowerCase() != 'epub') continue;

      results.add(BookResult(
        title: title,
        series: series,
        author: author,
        publisher: publisher,
        year: year,
        language: language,
        pages: pages,
        size: size,
        format: format,
        isbn: isbn,
        editionId: editionId,
        editionUrl: '$_base/edition.php?id=$editionId',
        fileId: fileId,
      ));
    }
    return results;
  }

  /// editionId → md5, by scraping the edition page's `ads.php?md5=` link.
  Future<BookEditionDetails?> _getEditionDetails(String editionId) async {
    try {
      final url = Uri.parse('$_base/edition.php?id=$editionId');
      final response = await _client.get(url, headers: _headers);
      if (response.statusCode != 200) return null;

      final document = hp.parse(response.body);
      final adsLink = document.querySelector('a[href^="ads.php?md5="]')?.attributes['href'];
      final md5 = RegExp(r'md5=([a-f0-9]+)').firstMatch(adsLink ?? '')?.group(1);
      if (md5 == null || md5.isEmpty) return null;

      return BookEditionDetails(editionId: editionId, md5: md5, adsUrl: '$_base/ads.php?md5=$md5');
    } catch (_) {
      return null;
    }
  }

  /// md5 → real `get.php` download URL, by scraping the ads page.
  Future<String?> _getDownloadUrl(String md5) async {
    try {
      final adsUrl = Uri.parse('$_base/ads.php?md5=$md5');
      final response = await _client.get(adsUrl, headers: _headers);
      if (response.statusCode != 200) return null;

      final document = hp.parse(response.body);
      final getLink = document.querySelector('table#main a[href^="get.php"]')?.attributes['href'];
      if (getLink == null || getLink.isEmpty) return null;

      return '$_base/$getLink';
    } catch (_) {
      return null;
    }
  }

  /// editionId → md5 → download URL, in one call.
  Future<String?> resolveDownloadUrl(String editionId) async {
    final details = await _getEditionDetails(editionId);
    if (details == null) return null;
    return _getDownloadUrl(details.md5);
  }
}
