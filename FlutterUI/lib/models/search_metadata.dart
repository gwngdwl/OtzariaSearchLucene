/// Metadata about a search operation.
///
/// Contains information about the search query, total number of results found,
/// and the time taken to execute the search.
class SearchMetadata {
  /// The original search query text.
  final String query;

  /// The total number of results found for this query.
  final int totalResults;

  /// The time taken to execute the search in milliseconds.
  final int elapsedMilliseconds;

  const SearchMetadata({
    required this.query,
    required this.totalResults,
    required this.elapsedMilliseconds,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchMetadata &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          totalResults == other.totalResults &&
          elapsedMilliseconds == other.elapsedMilliseconds;

  @override
  int get hashCode => Object.hash(query, totalResults, elapsedMilliseconds);

  @override
  String toString() =>
      'SearchMetadata(query: $query, totalResults: $totalResults, '
      'elapsedMilliseconds: $elapsedMilliseconds)';
}
