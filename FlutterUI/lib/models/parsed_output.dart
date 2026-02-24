import 'search_metadata.dart';
import 'search_result.dart';

/// Represents the result of parsing textual output from OtzariaSearch.exe.
///
/// Contains the parsed metadata, search results, and validation status.
/// If parsing fails, [isValid] will be false and [errorMessage] will contain
/// details about the parsing error.
class ParsedOutput {
  /// Metadata extracted from the search output (query, total results, elapsed time).
  final SearchMetadata? metadata;

  /// List of search results parsed from the output.
  final List<SearchResult> results;

  /// Error message if parsing failed, null if parsing was successful.
  final String? errorMessage;

  /// Whether the output was successfully parsed.
  final bool isValid;

  const ParsedOutput({
    this.metadata,
    required this.results,
    this.errorMessage,
    required this.isValid,
  });

  /// Creates a successful ParsedOutput with metadata and results.
  factory ParsedOutput.success({
    required SearchMetadata metadata,
    required List<SearchResult> results,
  }) {
    return ParsedOutput(
      metadata: metadata,
      results: results,
      errorMessage: null,
      isValid: true,
    );
  }

  /// Creates a failed ParsedOutput with an error message.
  factory ParsedOutput.error(String errorMessage) {
    return ParsedOutput(
      metadata: null,
      results: const [],
      errorMessage: errorMessage,
      isValid: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedOutput &&
          runtimeType == other.runtimeType &&
          metadata == other.metadata &&
          _listEquals(results, other.results) &&
          errorMessage == other.errorMessage &&
          isValid == other.isValid;

  @override
  int get hashCode =>
      Object.hash(metadata, Object.hashAll(results), errorMessage, isValid);

  @override
  String toString() =>
      'ParsedOutput(isValid: $isValid, metadata: $metadata, '
      'resultCount: ${results.length}, errorMessage: $errorMessage)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
