import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/models/parsed_output.dart';
import 'package:flutter_ui/models/search_metadata.dart';
import 'package:flutter_ui/models/search_result.dart';

void main() {
  group('ParsedOutput', () {
    test('should create successful ParsedOutput with factory', () {
      final metadata = SearchMetadata(
        query: 'test',
        totalResults: 5,
        elapsedMilliseconds: 100,
      );
      final results = [
        SearchResult(
          rank: 1,
          bookTitle: 'Book',
          reference: '1:1',
          category: 'Category',
          snippet: 'snippet',
          score: 90.0,
          highlights: [],
        ),
      ];

      final output = ParsedOutput.success(metadata: metadata, results: results);

      expect(output.isValid, true);
      expect(output.errorMessage, null);
      expect(output.metadata, metadata);
      expect(output.results, results);
    });

    test('should create error ParsedOutput with factory', () {
      const errorMsg = 'שגיאה בפענוח';

      final output = ParsedOutput.error(errorMsg);

      expect(output.isValid, false);
      expect(output.errorMessage, errorMsg);
      expect(output.metadata, null);
      expect(output.results, isEmpty);
    });

    test('should support equality comparison', () {
      final metadata = SearchMetadata(
        query: 'test',
        totalResults: 1,
        elapsedMilliseconds: 50,
      );
      final results = [
        SearchResult(
          rank: 1,
          bookTitle: 'Book',
          reference: '1:1',
          category: 'Cat',
          snippet: 'text',
          score: 80.0,
          highlights: [],
        ),
      ];

      final output1 = ParsedOutput.success(
        metadata: metadata,
        results: results,
      );
      final output2 = ParsedOutput.success(
        metadata: metadata,
        results: results,
      );

      expect(output1, equals(output2));
    });

    test('should have consistent hashCode for equal objects', () {
      final metadata = SearchMetadata(
        query: 'test',
        totalResults: 1,
        elapsedMilliseconds: 50,
      );
      final results = [
        SearchResult(
          rank: 1,
          bookTitle: 'Book',
          reference: '1:1',
          category: 'Cat',
          snippet: 'text',
          score: 80.0,
          highlights: [],
        ),
      ];

      final output1 = ParsedOutput.success(
        metadata: metadata,
        results: results,
      );
      final output2 = ParsedOutput.success(
        metadata: metadata,
        results: results,
      );

      expect(output1.hashCode, equals(output2.hashCode));
    });

    test('should have meaningful toString', () {
      final output = ParsedOutput.error('test error');

      final str = output.toString();

      expect(str, contains('ParsedOutput'));
      expect(str, contains('isValid: false'));
      expect(str, contains('test error'));
    });

    test('should handle empty results list', () {
      final metadata = SearchMetadata(
        query: 'test',
        totalResults: 0,
        elapsedMilliseconds: 25,
      );

      final output = ParsedOutput.success(metadata: metadata, results: []);

      expect(output.isValid, true);
      expect(output.results, isEmpty);
    });

    test('should distinguish between different error messages', () {
      final output1 = ParsedOutput.error('error 1');
      final output2 = ParsedOutput.error('error 2');

      expect(output1, isNot(equals(output2)));
    });

    test('should distinguish between success and error outputs', () {
      final metadata = SearchMetadata(
        query: 'test',
        totalResults: 0,
        elapsedMilliseconds: 10,
      );
      final successOutput = ParsedOutput.success(
        metadata: metadata,
        results: [],
      );
      final errorOutput = ParsedOutput.error('error');

      expect(successOutput, isNot(equals(errorOutput)));
    });
  });
}
