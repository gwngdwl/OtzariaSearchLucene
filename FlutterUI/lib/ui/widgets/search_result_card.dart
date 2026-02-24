import 'package:flutter/material.dart';
import '../../models/search_result.dart';
import '../../models/highlight_span.dart';

/// A card widget that displays a single search result.
///
/// Shows all fields of a SearchResult including rank, book title, reference,
/// category, snippet with highlighted terms, and score. Supports RTL layout
/// for Hebrew text and provides clear visual separation between results.
class SearchResultCard extends StatelessWidget {
  /// The search result to display.
  final SearchResult result;

  const SearchResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank and Score row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${result.rank}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ציון: ${result.score.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Book title
              Text(
                result.bookTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              // Reference and Category
              Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.reference,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.category,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Snippet with highlights
              _buildSnippetWithHighlights(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the snippet text with highlighted terms using RichText and TextSpan.
  Widget _buildSnippetWithHighlights(BuildContext context) {
    if (result.highlights.isEmpty) {
      // No highlights, display plain text
      return Text(
        result.snippet,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    // Build TextSpans with highlights
    final List<TextSpan> spans = [];
    int currentPosition = 0;

    // Sort highlights by start position to process them in order
    final sortedHighlights = List<HighlightSpan>.from(result.highlights)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final highlight in sortedHighlights) {
      // Add text before the highlight
      if (currentPosition < highlight.start) {
        spans.add(
          TextSpan(
            text: result.snippet.substring(currentPosition, highlight.start),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }

      // Add highlighted text
      spans.add(
        TextSpan(
          text: highlight.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.yellow[200],
            color: Colors.black87,
          ),
        ),
      );

      currentPosition = highlight.end;
    }

    // Add remaining text after the last highlight
    if (currentPosition < result.snippet.length) {
      spans.add(
        TextSpan(
          text: result.snippet.substring(currentPosition),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
    );
  }
}
