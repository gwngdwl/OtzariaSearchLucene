import 'dart:convert';
import '../models/highlight_span.dart';
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
        final rawSnippet = map['snippet'] as String? ?? '';
        final parsed = _parseMarkTags(rawSnippet);
        return SearchResult(
          rank: map['rank'] as int? ?? 0,
          bookTitle: map['bookTitle'] as String? ?? '',
          reference: map['heRef'] as String? ?? '',
          category: map['categoryPath'] as String? ?? '',
          snippet: parsed.plainText,
          score: (map['score'] as num?)?.toDouble() ?? 0.0,
          highlights: parsed.highlights,
        );
      }).toList();

      return ParsedOutput.success(metadata: metadata, results: results);
    } on FormatException catch (e) {
      return ParsedOutput.error('שגיאה בפענוח JSON: ${e.message}');
    } catch (e) {
      return ParsedOutput.error('שגיאה בפענוח הפלט: ${e.toString()}');
    }
  }

  /// Parses `<mark>...</mark>` tags from a snippet string.
  ///
  /// Returns a record with the plain text (tags stripped) and a list of
  /// [HighlightSpan] objects indicating the highlighted ranges.
  static ({String plainText, List<HighlightSpan> highlights}) _parseMarkTags(
    String snippet,
  ) {
    final markPattern = RegExp(r'<mark>(.*?)</mark>', caseSensitive: false);
    final highlights = <HighlightSpan>[];
    final buffer = StringBuffer();
    int lastEnd = 0;

    for (final match in markPattern.allMatches(snippet)) {
      // Append text before this match
      buffer.write(snippet.substring(lastEnd, match.start));
      final highlightStart = buffer.length;
      final highlightText = match.group(1) ?? '';
      buffer.write(highlightText);
      highlights.add(
        HighlightSpan(
          start: highlightStart,
          end: highlightStart + highlightText.length,
          text: highlightText,
        ),
      );
      lastEnd = match.end;
    }

    // Append remaining text after last match
    buffer.write(snippet.substring(lastEnd));

    return (plainText: buffer.toString(), highlights: highlights);
  }
}
