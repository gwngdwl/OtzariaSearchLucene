import 'highlight_span.dart';

/// Represents a single search result from the Otzaria search engine.
///
/// Contains all information about a search result including the book title,
/// reference, category, snippet with highlights, and relevance score.
class SearchResult {
  /// The rank/position of this result in the search results (1-indexed).
  final int rank;

  /// The title of the book where this result was found.
  final String bookTitle;

  /// The specific reference/location within the book (e.g., chapter:verse).
  final String reference;

  /// The category of the book (e.g., תנ״ך, משנה, תלמוד).
  final String category;

  /// A text snippet showing the context of the search match.
  final String snippet;

  /// The relevance score of this result (higher is more relevant).
  final double score;

  /// List of highlighted spans within the snippet showing matched terms.
  final List<HighlightSpan> highlights;

  const SearchResult({
    required this.rank,
    required this.bookTitle,
    required this.reference,
    required this.category,
    required this.snippet,
    required this.score,
    required this.highlights,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          bookTitle == other.bookTitle &&
          reference == other.reference &&
          category == other.category &&
          snippet == other.snippet &&
          score == other.score &&
          _listEquals(highlights, other.highlights);

  @override
  int get hashCode => Object.hash(
    rank,
    bookTitle,
    reference,
    category,
    snippet,
    score,
    Object.hashAll(highlights),
  );

  @override
  String toString() =>
      'SearchResult(rank: $rank, bookTitle: $bookTitle, '
      'reference: $reference, category: $category, score: $score)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
