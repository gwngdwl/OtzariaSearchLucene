import 'dart:convert';
import '../models/parsed_output.dart';
import '../models/search_metadata.dart';
import '../models/search_result.dart';

/// Service for parsing JSON output from OtzariaSearch.exe.
///
/// The C# search engine outputs a structured JSON response via BridgeService.
/// This parser deserializes that JSON into [ParsedOutput] containing metadata
/// and search results. Handles invalid output gracefully by returning error
/// information.
///
/// Expected JSON format:
/// ```json
/// {
///   "status": "success",
///   "query": "search query",
///   "totalHits": 12345,
///   "elapsedMs": 129,
///   "results": [
///     {
///       "rank": 1,
///       "lineId": 123,
///       "bookId": 456,
///       "bookTitle": "ספר",
///       "categoryPath": "תנ״ך/תורה",
///       "heRef": "בראשית א:א",
///       "lineIndex": 0,
///       "snippet": "...snippet...",
///       "score": 1.2345
///     }
///   ]
/// }
/// ```
class OutputParser {
  /// Parses JSON output from OtzariaSearch.exe.
  ///
  /// Returns [ParsedOutput] with [isValid]=true on success, or [isValid]=false
  /// with an error message if parsing fails.
  ParsedOutput parse(String rawOutput) {
    try {
      if (rawOutput.trim().isEmpty) {
        return ParsedOutput.error('פלט ריק - לא התקבלו נתונים מהחיפוש');
      }

      final json = jsonDecode(rawOutput) as Map<String, dynamic>;

      // Check for error status from the bridge
      final status = json['status'] as String?;
      if (status == 'error') {
        final message = json['message'] as String? ?? 'שגיאה לא ידועה';
        return ParsedOutput.error(message);
      }

      // Extract metadata
      final query = json['query'] as String? ?? '';
      final totalHits = json['totalHits'] as int? ?? 0;
      final elapsedMs = json['elapsedMs'] as int? ?? 0;

      final metadata = SearchMetadata(
        query: query,
        totalResults: totalHits,
        elapsedMilliseconds: elapsedMs,
      );

      // Extract results
      final resultsList = json['results'] as List<dynamic>? ?? [];
      final results = resultsList.map((item) {
        final map = item as Map<String, dynamic>;
        return SearchResult(
          rank: map['rank'] as int? ?? 0,
          bookTitle: map['bookTitle'] as String? ?? '',
          reference: map['heRef'] as String? ?? '',
          category: map['categoryPath'] as String? ?? '',
          snippet: map['snippet'] as String? ?? '',
          score: (map['score'] as num?)?.toDouble() ?? 0.0,
          highlights:
              const [], // highlights can be computed client-side if needed
        );
      }).toList();

      return ParsedOutput.success(metadata: metadata, results: results);
    } on FormatException catch (e) {
      return ParsedOutput.error('שגיאה בפענוח JSON: ${e.message}');
    } catch (e) {
      return ParsedOutput.error('שגיאה בפענוח הפלט: ${e.toString()}');
    }
  }
}
