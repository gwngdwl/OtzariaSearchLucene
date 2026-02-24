import 'search_result.dart';
import 'search_metadata.dart';

/// Represents the response from a search operation.
///
/// Contains the list of search results, metadata about the search,
/// and an optional error message if the search failed.
class SearchResponse {
  /// The list of search results.
  final List<SearchResult> results;

  /// Metadata about the search operation.
  final SearchMetadata metadata;

  /// Optional error message if the search failed.
  final String? errorMessage;

  const SearchResponse({
    required this.results,
    required this.metadata,
    this.errorMessage,
  });

  /// Returns true if the search was successful (no error message).
  bool get isSuccess => errorMessage == null;

  /// Returns true if the search returned no results.
  bool get isEmpty => results.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResponse &&
          runtimeType == other.runtimeType &&
          _listEquals(results, other.results) &&
          metadata == other.metadata &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(results), metadata, errorMessage);

  @override
  String toString() =>
      'SearchResponse(results: ${results.length}, '
      'isSuccess: $isSuccess, isEmpty: $isEmpty)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
