import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/services/output_parser.dart';

void main() {
  group('OutputParser', () {
    late OutputParser parser;

    setUp(() {
      parser = OutputParser();
    });

    group('parse', () {
      test('should parse valid output with single result', () {
        const output = '''
Query: תורה
Total Results: 1
Elapsed Time: 123ms

Rank: 1
Book: בראשית
Reference: א:א
Category: תנ״ך
Snippet: בראשית **ברא** אלהים
Score: 95.5
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.errorMessage, null);
        expect(result.metadata, isNotNull);
        expect(result.metadata!.query, 'תורה');
        expect(result.metadata!.totalResults, 1);
        expect(result.metadata!.elapsedMilliseconds, 123);
        expect(result.results.length, 1);

        final searchResult = result.results[0];
        expect(searchResult.rank, 1);
        expect(searchResult.bookTitle, 'בראשית');
        expect(searchResult.reference, 'א:א');
        expect(searchResult.category, 'תנ״ך');
        expect(searchResult.snippet, 'בראשית **ברא** אלהים');
        expect(searchResult.score, 95.5);
      });

      test('should parse valid output with multiple results', () {
        const output = '''
Query: משה
Total Results: 3
Elapsed Time: 456ms

Rank: 1
Book: שמות
Reference: ב:י
Category: תנ״ך
Snippet: ותקרא שמו **משה**
Score: 98.0

Rank: 2
Book: במדבר
Reference: יב:ג
Category: תנ״ך
Snippet: והאיש **משה** עניו מאד
Score: 92.5

Rank: 3
Book: דברים
Reference: לד:י
Category: תנ״ך
Snippet: ולא קם נביא עוד כ**משה**
Score: 88.3
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.metadata!.query, 'משה');
        expect(result.metadata!.totalResults, 3);
        expect(result.metadata!.elapsedMilliseconds, 456);
        expect(result.results.length, 3);

        expect(result.results[0].rank, 1);
        expect(result.results[0].bookTitle, 'שמות');
        expect(result.results[1].rank, 2);
        expect(result.results[1].bookTitle, 'במדבר');
        expect(result.results[2].rank, 3);
        expect(result.results[2].bookTitle, 'דברים');
      });

      test('should handle empty output', () {
        const output = '';

        final result = parser.parse(output);

        expect(result.isValid, false);
        expect(result.errorMessage, contains('פלט ריק'));
        expect(result.results, isEmpty);
      });

      test('should handle whitespace-only output', () {
        const output = '   \n  \t  \n  ';

        final result = parser.parse(output);

        expect(result.isValid, false);
        expect(result.errorMessage, contains('פלט ריק'));
      });

      test('should handle missing metadata fields', () {
        const output = '''
Query: test
Total Results: 1

Rank: 1
Book: Test Book
Reference: 1:1
Category: Test
Snippet: test snippet
Score: 50.0
''';

        final result = parser.parse(output);

        expect(result.isValid, false);
        expect(result.errorMessage, contains('metadata'));
      });

      test('should handle malformed metadata values', () {
        const output = '''
Query: test
Total Results: not_a_number
Elapsed Time: 123ms

Rank: 1
Book: Test Book
Reference: 1:1
Category: Test
Snippet: test snippet
Score: 50.0
''';

        final result = parser.parse(output);

        expect(result.isValid, false);
        expect(result.errorMessage, isNotNull);
      });

      test('should parse elapsed time without ms suffix', () {
        const output = '''
Query: test
Total Results: 1
Elapsed Time: 123

Rank: 1
Book: Test Book
Reference: 1:1
Category: Test
Snippet: test snippet
Score: 50.0
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.metadata!.elapsedMilliseconds, 123);
      });

      test('should handle incomplete result (missing fields)', () {
        const output = '''
Query: test
Total Results: 1
Elapsed Time: 123ms

Rank: 1
Book: Test Book
Reference: 1:1
''';

        final result = parser.parse(output);

        // Should parse metadata successfully but have no results
        expect(result.isValid, true);
        expect(result.metadata, isNotNull);
        expect(result.results, isEmpty);
      });

      test('should handle result with decimal score', () {
        const output = '''
Query: test
Total Results: 1
Elapsed Time: 100ms

Rank: 1
Book: Test Book
Reference: 1:1
Category: Test
Snippet: test snippet
Score: 87.654321
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.results[0].score, 87.654321);
      });

      test('should handle result with integer score', () {
        const output = '''
Query: test
Total Results: 1
Elapsed Time: 100ms

Rank: 1
Book: Test Book
Reference: 1:1
Category: Test
Snippet: test snippet
Score: 100
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.results[0].score, 100.0);
      });

      test('should handle Hebrew text in all fields', () {
        const output = '''
Query: חכמה
Total Results: 1
Elapsed Time: 200ms

Rank: 1
Book: משלי
Reference: א:ב
Category: כתובים
Snippet: לדעת **חכמה** ומוסר
Score: 95.0
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.metadata!.query, 'חכמה');
        expect(result.results[0].bookTitle, 'משלי');
        expect(result.results[0].reference, 'א:ב');
        expect(result.results[0].category, 'כתובים');
        expect(result.results[0].snippet, contains('חכמה'));
      });

      test('should handle mixed Hebrew and English text', () {
        const output = '''
Query: test חיפוש
Total Results: 1
Elapsed Time: 150ms

Rank: 1
Book: Mixed Book שם
Reference: 1:1
Category: Test קטגוריה
Snippet: English **Hebrew** mixed
Score: 75.0
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.metadata!.query, 'test חיפוש');
        expect(result.results[0].bookTitle, 'Mixed Book שם');
      });

      test('should handle zero results', () {
        const output = '''
Query: nonexistent
Total Results: 0
Elapsed Time: 50ms
''';

        final result = parser.parse(output);

        expect(result.isValid, true);
        expect(result.metadata!.totalResults, 0);
        expect(result.results, isEmpty);
      });
    });

    group('extractHighlights', () {
      test('should extract single ** highlight', () {
        const snippet = 'text **highlighted** more';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 1);
        expect(highlights[0].text, 'highlighted');
        expect(highlights[0].start, 5);
        expect(highlights[0].end, 20);
      });

      test('should extract multiple ** highlights', () {
        const snippet = '**first** text **second** more **third**';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 3);
        expect(highlights[0].text, 'first');
        expect(highlights[1].text, 'second');
        expect(highlights[2].text, 'third');
      });

      test('should extract single <<>> highlight', () {
        const snippet = 'text <<highlighted>> more';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 1);
        expect(highlights[0].text, 'highlighted');
        expect(highlights[0].start, 5);
        expect(highlights[0].end, 20);
      });

      test('should extract multiple <<>> highlights', () {
        const snippet = '<<first>> text <<second>> more <<third>>';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 3);
        expect(highlights[0].text, 'first');
        expect(highlights[1].text, 'second');
        expect(highlights[2].text, 'third');
      });

      test('should extract mixed ** and <<>> highlights', () {
        const snippet = '**star** text <<angle>> more';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 2);
        expect(highlights[0].text, 'star');
        expect(highlights[1].text, 'angle');
      });

      test('should handle Hebrew highlighted text', () {
        const snippet = 'בראשית **ברא** אלהים';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 1);
        expect(highlights[0].text, 'ברא');
      });

      test('should handle snippet with no highlights', () {
        const snippet = 'plain text without highlights';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights, isEmpty);
      });

      test('should handle empty snippet', () {
        const snippet = '';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights, isEmpty);
      });

      test('should handle adjacent highlights', () {
        const snippet = '**first****second**';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 2);
        expect(highlights[0].text, 'first');
        expect(highlights[1].text, 'second');
      });

      test('should handle highlights with spaces', () {
        const snippet = '**multiple words highlighted**';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 1);
        expect(highlights[0].text, 'multiple words highlighted');
      });

      test('should handle highlights with special characters', () {
        const snippet = '**text-with-dashes** and **text.with.dots**';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 2);
        expect(highlights[0].text, 'text-with-dashes');
        expect(highlights[1].text, 'text.with.dots');
      });

      test('should sort highlights by start position', () {
        const snippet = 'c <<third>> a **first** b <<second>>';

        final highlights = parser.extractHighlights(snippet);

        expect(highlights.length, 3);
        // Should be sorted by start position
        expect(highlights[0].start, lessThan(highlights[1].start));
        expect(highlights[1].start, lessThan(highlights[2].start));
      });

      test('should handle nested-looking markers (not actually nested)', () {
        const snippet = '**outer <<inner>>**';

        final highlights = parser.extractHighlights(snippet);

        // Both patterns should match independently
        expect(highlights.length, 2);
      });

      test('should handle incomplete markers', () {
        const snippet = '**incomplete text without closing';

        final highlights = parser.extractHighlights(snippet);

        // Should not match incomplete markers
        expect(highlights, isEmpty);
      });

      test('should handle single marker', () {
        const snippet = 'text ** more text';

        final highlights = parser.extractHighlights(snippet);

        // Should not match single markers
        expect(highlights, isEmpty);
      });
    });
  });
}
