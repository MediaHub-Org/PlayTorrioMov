/// Advanced relevance scoring utility for search results.
class RelevanceScorer {
  /// Calculate a numeric relevance score for a [title] given a search [query].
  /// Higher score means higher relevance.
  static double score({required String title, required String query}) {
    final cleanTitle = _normalize(title);
    final cleanQuery = _normalize(query);

    if (cleanTitle.isEmpty || cleanQuery.isEmpty) return 0.0;

    final strippedTitle = _stripArticles(cleanTitle);
    final strippedQuery = _stripArticles(cleanQuery);

    // 1. Exact Match (with or without leading "the/a/an")
    if (cleanTitle == cleanQuery || strippedTitle == strippedQuery) {
      return 10000.0;
    }

    double totalScore = 0.0;

    // 2. Direct Substring Match of FULL QUERY (e.g. "vampire diaries" inside title)
    if (cleanTitle.contains(cleanQuery) || strippedTitle.contains(strippedQuery)) {
      totalScore += 5000.0;
    }

    // 3. Prefix Match of FULL QUERY
    if (cleanTitle.startsWith(cleanQuery) || strippedTitle.startsWith(strippedQuery)) {
      totalScore += 3000.0;
    }

    // 4. Word Token Matching
    final queryTokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final titleTokens = cleanTitle.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    if (queryTokens.isNotEmpty) {
      int matchedCount = 0;

      for (int i = 0; i < queryTokens.length; i++) {
        final qToken = queryTokens[i];
        if (titleTokens.contains(qToken)) {
          matchedCount++;
        } else {
          // Substring token match
          final isPartialMatch = titleTokens.any((t) => t.contains(qToken) || qToken.contains(t));
          if (isPartialMatch) {
            matchedCount++;
          }
        }
      }

      final tokenMatchRatio = matchedCount / queryTokens.length;

      // CRITICAL: If multi-word query and NOT all query tokens matched, severely cap score
      if (queryTokens.length > 1 && tokenMatchRatio < 1.0) {
        totalScore = (totalScore + (tokenMatchRatio * 200.0)) * 0.1;
      } else {
        totalScore += tokenMatchRatio * 1000.0;
        if (tokenMatchRatio == 1.0) {
          totalScore += 2000.0; // Huge bonus when ALL search terms exist in title
        }
      }
    }

    return totalScore;
  }

  static String _stripArticles(String s) {
    return s.replaceAll(RegExp(r'^(?:the|a|an)\s+', caseSensitive: false), '').trim();
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
