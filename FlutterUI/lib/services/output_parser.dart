import '../models/highlight_span.dart';
import '../models/parsed_output.dart';
import '../models/search_metadata.dart';
import '../models/search_result.dart';

/// Service for parsing textual output from OtzariaSearch.exe.
///
/// Parses the structured text output into [ParsedOutput] containing metadata
/// and search results. Handles invalid output gracefully by returning error
/// information.
class OutputParser {
  /// Parses raw textual output from OtzariaSearch.exe.
  ///
  /// Expected format:
  /// ```
  /// Query: <search query>
  /// Total Results: <number>
  /// Elapsed Time: <milliseconds>ms
  ///
  /// Rank: <number>
  /// Book: <book title>
  /// Reference: <reference>
  /// Category: <category>
  /// Snippet: <text with **highlighted** terms>
  /// Score: <score>
  ///
  /// [Repeat for each result]
  /// ```
  ///
  /// Returns [ParsedOutput] with [isValid]=true on success, or [isValid]=false
  /// with an error message if parsing fails.
  ParsedOutput parse(String rawOutput) {
    try {
      if (rawOutput.trim().isEmpty) {
        return ParsedOutput.error('פלט ריק - לא התקבלו נתונים מהחיפוש');
      }

      // Split output into lines for processing
      final lines = rawOutput.split('\n').map((line) => line.trim()).toList();

      // Extract metadata
      final metadata = _extractMetadata(lines);
      if (metadata == null) {
        return ParsedOutput.error('שגיאה בחילוץ metadata - פורמט לא תקין');
      }

      // Extract results
      final results = _extractResults(lines);

      return ParsedOutput.success(metadata: metadata, results: results);
    } catch (e) {
      return ParsedOutput.error('שגיאה בפענוח הפלט: ${e.toString()}');
    }
  }

  /// Extracts metadata (query, total results, elapsed time) from output lines.
  SearchMetadata? _extractMetadata(List<String> lines) {
    String? query;
    int? totalResults;
    int? elapsedMilliseconds;

    for (final line in lines) {
      // Format: Searching: "query"
      if (line.startsWith('Searching:')) {
        final match = RegExp(r'Searching:\s*"(.+?)"').firstMatch(line);
        if (match != null) {
          query = match.group(1);
        }
      }
      // Format: 163,742 results found (129ms)
      else if (line.contains('results found')) {
        final match = RegExp(
          r'([\d,]+)\s+results found\s*\((\d+)ms\)',
        ).firstMatch(line);
        if (match != null) {
          // Remove commas from number
          final resultsStr = match.group(1)!.replaceAll(',', '');
          totalResults = int.tryParse(resultsStr);
          elapsedMilliseconds = int.tryParse(match.group(2)!);
        }
      }
      // Legacy format support
      else if (line.startsWith('Query:')) {
        query = line.substring('Query:'.length).trim();
      } else if (line.startsWith('Total Results:')) {
        final value = line.substring('Total Results:'.length).trim();
        totalResults = int.tryParse(value);
      } else if (line.startsWith('Elapsed Time:')) {
        final value = line.substring('Elapsed Time:'.length).trim();
        final numericValue = value.replaceAll('ms', '').trim();
        elapsedMilliseconds = int.tryParse(numericValue);
      }

      // Stop searching after we've found all metadata
      if (query != null &&
          totalResults != null &&
          elapsedMilliseconds != null) {
        break;
      }
    }

    // Validate that all required metadata was found
    if (query == null || totalResults == null || elapsedMilliseconds == null) {
      return null;
    }

    return SearchMetadata(
      query: query,
      totalResults: totalResults,
      elapsedMilliseconds: elapsedMilliseconds,
    );
  }

  /// Extracts search results from output lines.
  List<SearchResult> _extractResults(List<String> lines) {
    final results = <SearchResult>[];

    // New format: Parse results from the formatted output
    // Format:
    // [1] Book Title | Reference
    //     [Category]
    //     Snippet
    //     Score: X.XXXX

    int? currentRank;
    String? currentBook;
    String? currentReference;
    String? currentCategory;
    String? currentSnippet;
    double? currentScore;

    int lineIndex = 0;

    while (lineIndex < lines.length) {
      final line = lines[lineIndex];

      // Check for result header: [1] Book Title | Reference
      final headerMatch = RegExp(
        r'^\[(\d+)\]\s+(.+?)(?:\s*\|\s*(.+))?$',
      ).firstMatch(line);
      if (headerMatch != null) {
        // Save previous result if complete
        if (currentRank != null && currentBook != null) {
          results.add(
            _createSearchResult(
              currentRank,
              currentBook,
              currentReference ?? '',
              currentCategory ?? '',
              currentSnippet ?? '',
              currentScore ?? 0.0,
            ),
          );
        }

        // Start new result
        currentRank = int.tryParse(headerMatch.group(1)!);
        final titleAndRef = headerMatch.group(2)!.trim();
        currentReference = headerMatch.group(3)?.trim();

        // If no pipe separator, the whole thing is the book title
        if (currentReference == null) {
          currentBook = titleAndRef;
          currentReference = '';
        } else {
          currentBook = titleAndRef;
        }

        currentCategory = null;
        currentSnippet = null;
        currentScore = null;

        lineIndex++;
        continue;
      }

      // Check for category: [Category]
      final categoryMatch = RegExp(r'^\[(.+)\]$').firstMatch(line);
      if (categoryMatch != null && currentRank != null) {
        currentCategory = categoryMatch.group(1);
        lineIndex++;
        continue;
      }

      // Check for score: Score: X.XXXX
      final scoreMatch = RegExp(r'^Score:\s*([\d.]+)').firstMatch(line);
      if (scoreMatch != null && currentRank != null) {
        currentScore = double.tryParse(scoreMatch.group(1)!);
        lineIndex++;
        continue;
      }

      // Check for separator lines (dashes)
      if (line.contains('─') || line.trim().isEmpty) {
        lineIndex++;
        continue;
      }

      // Check for "... and X more results" line
      if (line.contains('and') && line.contains('more results')) {
        lineIndex++;
        continue;
      }

      // Check for "Showing top X results" line
      if (line.contains('Showing top')) {
        lineIndex++;
        continue;
      }

      // Otherwise, treat as snippet if we're in a result
      if (currentRank != null &&
          !line.startsWith('Searching:') &&
          !line.contains('results found')) {
        if (currentSnippet == null) {
          currentSnippet = line;
        } else {
          currentSnippet += ' $line';
        }
      }

      lineIndex++;
    }

    // Add the last result if complete
    if (currentRank != null && currentBook != null) {
      results.add(
        _createSearchResult(
          currentRank,
          currentBook,
          currentReference ?? '',
          currentCategory ?? '',
          currentSnippet ?? '',
          currentScore ?? 0.0,
        ),
      );
    }

    // Legacy format support
    if (results.isEmpty) {
      return _extractResultsLegacyFormat(lines);
    }

    return results;
  }

  /// Extracts search results using the legacy format.
  List<SearchResult> _extractResultsLegacyFormat(List<String> lines) {
    final results = <SearchResult>[];
    int? currentRank;
    String? currentBook;
    String? currentReference;
    String? currentCategory;
    String? currentSnippet;
    double? currentScore;

    for (final line in lines) {
      if (line.startsWith('Rank:')) {
        // If we have a complete result, add it before starting a new one
        if (currentRank != null &&
            currentBook != null &&
            currentReference != null &&
            currentCategory != null &&
            currentSnippet != null &&
            currentScore != null) {
          results.add(
            _createSearchResult(
              currentRank,
              currentBook,
              currentReference,
              currentCategory,
              currentSnippet,
              currentScore,
            ),
          );
        }

        // Start new result
        final value = line.substring('Rank:'.length).trim();
        currentRank = int.tryParse(value);
        currentBook = null;
        currentReference = null;
        currentCategory = null;
        currentSnippet = null;
        currentScore = null;
      } else if (line.startsWith('Book:')) {
        currentBook = line.substring('Book:'.length).trim();
      } else if (line.startsWith('Reference:')) {
        currentReference = line.substring('Reference:'.length).trim();
      } else if (line.startsWith('Category:')) {
        currentCategory = line.substring('Category:'.length).trim();
      } else if (line.startsWith('Snippet:')) {
        currentSnippet = line.substring('Snippet:'.length).trim();
      } else if (line.startsWith('Score:')) {
        final value = line.substring('Score:'.length).trim();
        currentScore = double.tryParse(value);
      }
    }

    // Add the last result if complete
    if (currentRank != null &&
        currentBook != null &&
        currentReference != null &&
        currentCategory != null &&
        currentSnippet != null &&
        currentScore != null) {
      results.add(
        _createSearchResult(
          currentRank,
          currentBook,
          currentReference,
          currentCategory,
          currentSnippet,
          currentScore,
        ),
      );
    }

    return results;
  }

  /// Creates a SearchResult with extracted highlights from the snippet.
  SearchResult _createSearchResult(
    int rank,
    String bookTitle,
    String reference,
    String category,
    String snippet,
    double score,
  ) {
    final highlights = extractHighlights(snippet);

    return SearchResult(
      rank: rank,
      bookTitle: bookTitle,
      reference: reference,
      category: category,
      snippet: snippet,
      score: score,
      highlights: highlights,
    );
  }

  /// Extracts highlighted terms from a snippet.
  ///
  /// Identifies terms marked with ** or `<<>>` markers and returns their
  /// positions as [HighlightSpan] objects.
  ///
  /// Examples:
  /// - "text **highlighted** more" -> HighlightSpan for "highlighted"
  /// - "text `<<highlighted>>` more" -> HighlightSpan for "highlighted"
  List<HighlightSpan> extractHighlights(String snippet) {
    final highlights = <HighlightSpan>[];

    // Pattern 1: **text** markers
    final starPattern = RegExp(r'\*\*(.+?)\*\*');
    final starMatches = starPattern.allMatches(snippet);

    for (final match in starMatches) {
      final highlightedText = match.group(1)!;
      // Calculate position in the original snippet (before marker removal)
      final start = match.start;
      final end = match.end;

      highlights.add(
        HighlightSpan(start: start, end: end, text: highlightedText),
      );
    }

    // Pattern 2: <<text>> markers
    final anglePattern = RegExp(r'<<(.+?)>>');
    final angleMatches = anglePattern.allMatches(snippet);

    for (final match in angleMatches) {
      final highlightedText = match.group(1)!;
      final start = match.start;
      final end = match.end;

      highlights.add(
        HighlightSpan(start: start, end: end, text: highlightedText),
      );
    }

    // Sort highlights by start position
    highlights.sort((a, b) => a.start.compareTo(b.start));

    return highlights;
  }
}
