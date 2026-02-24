/// Represents a highlighted span of text within a search result snippet.
///
/// Contains the start and end positions of the highlight, as well as the
/// highlighted text itself.
class HighlightSpan {
  /// The starting position of the highlight in the snippet (0-indexed).
  final int start;

  /// The ending position of the highlight in the snippet (exclusive).
  final int end;

  /// The text content that is highlighted.
  final String text;

  const HighlightSpan({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightSpan &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          text == other.text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'HighlightSpan(start: $start, end: $end, text: $text)';
}
