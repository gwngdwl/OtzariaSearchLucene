/// Represents a search request with query and optional filters.
///
/// Contains the search query, result limit, and optional category and book filters.
class SearchRequest {
  /// The search query text.
  final String query;

  /// The maximum number of results to return (default: 50).
  final int limit;

  /// Optional category filter (e.g., תנ״ך, משנה).
  final String? category;

  /// Optional book filter to search within a specific book.
  final String? book;

  /// Whether wildcard query syntax is enabled for this request.
  final bool wildcard;

  const SearchRequest({
    required this.query,
    this.limit = 50,
    this.category,
    this.book,
    this.wildcard = false,
  });

  /// Returns true if any filters (category or book) are applied.
  bool get hasFilters => category != null || book != null;

  /// Returns true if the search request is valid (non-empty query).
  bool get isValid => query.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchRequest &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          limit == other.limit &&
          category == other.category &&
          book == other.book &&
          wildcard == other.wildcard;

  @override
  int get hashCode => Object.hash(query, limit, category, book, wildcard);

  @override
  String toString() =>
      'SearchRequest(query: $query, limit: $limit, '
      'category: $category, book: $book, wildcard: $wildcard)';
}
