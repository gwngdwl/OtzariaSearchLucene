import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/services/search_service.dart';
import 'package:flutter_ui/services/process_executor.dart';
import 'package:flutter_ui/services/output_parser.dart';
import 'package:flutter_ui/services/configuration_manager.dart';
import 'package:flutter_ui/models/parsed_output.dart';
import 'package:flutter_ui/models/search_metadata.dart';
import 'package:flutter_ui/models/search_result.dart';

/// Mock ProcessExecutor for testing
class MockProcessExecutor extends ProcessExecutor {
  ProcessResult? mockResult;
  List<String>? capturedArguments;
  bool shouldThrowException = false;

  @override
  Future<ProcessResult> execute({
    required String executablePath,
    required List<String> arguments,
  }) async {
    capturedArguments = arguments;
    if (shouldThrowException) {
      throw Exception('Mock exception');
    }
    return mockResult ?? ProcessResult(stdout: '', stderr: '', exitCode: 0);
  }
}

/// Mock OutputParser for testing
class MockOutputParser extends OutputParser {
  ParsedOutput? mockOutput;

  @override
  ParsedOutput parse(String rawOutput) {
    return mockOutput ??
        ParsedOutput.success(
          metadata: SearchMetadata(
            query: 'test',
            totalResults: 0,
            elapsedMilliseconds: 0,
          ),
          results: [],
        );
  }
}

/// Mock ConfigurationManager for testing
class MockConfigurationManager extends ConfigurationManager {
  bool mockValidationResult = true;
  Map<String, dynamic>? mockValidationDetails;
  String mockSearchEnginePath = 'publish/OtzariaSearch.exe';
  String mockIndexPath = './search_index';

  @override
  String get searchEnginePath => mockSearchEnginePath;

  @override
  String get indexPath => mockIndexPath;

  @override
  Future<bool> validatePaths() async {
    return mockValidationResult;
  }

  @override
  Future<Map<String, dynamic>> getValidationDetails() async {
    return mockValidationDetails ??
        {
          'searchEngineValid': mockValidationResult,
          'indexValid': mockValidationResult,
          'searchEnginePath': mockSearchEnginePath,
          'indexPath': mockIndexPath,
          'errors': mockValidationResult
              ? []
              : ['קובץ החיפוש לא נמצא', 'תיקיית האינדקס לא נמצאה'],
          'isValid': mockValidationResult,
        };
  }
}

void main() {
  group('SearchService', () {
    late MockProcessExecutor mockExecutor;
    late MockOutputParser mockParser;
    late MockConfigurationManager mockConfig;
    late SearchService searchService;

    setUp(() {
      mockExecutor = MockProcessExecutor();
      mockParser = MockOutputParser();
      mockConfig = MockConfigurationManager();
      searchService = SearchService(
        executor: mockExecutor,
        parser: mockParser,
        config: mockConfig,
      );
    });

    group('search', () {
      test('should return error for empty query', () async {
        final response = await searchService.search(query: '');

        expect(response.isSuccess, false);
        expect(response.errorMessage, 'נא להזין שאילתת חיפוש');
        expect(response.results, isEmpty);
      });

      test('should return error for whitespace-only query', () async {
        final response = await searchService.search(query: '   ');

        expect(response.isSuccess, false);
        expect(response.errorMessage, 'נא להזין שאילתת חיפוש');
        expect(response.results, isEmpty);
      });

      test('should execute search with correct parameters', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'Query: test\nTotal Results: 0\nElapsed Time: 10ms\n',
          stderr: '',
          exitCode: 0,
        );

        await searchService.search(
          query: 'test query',
          limit: 25,
          category: 'תנ״ך',
          book: 'בראשית',
          wildcard: true,
        );

        expect(mockExecutor.capturedArguments, isNotNull);
        expect(mockExecutor.capturedArguments, contains('search'));
        expect(mockExecutor.capturedArguments, contains('test query'));
        expect(mockExecutor.capturedArguments, contains('--index'));
        expect(mockExecutor.capturedArguments, contains('./search_index'));
        expect(mockExecutor.capturedArguments, contains('--limit'));
        expect(mockExecutor.capturedArguments, contains('25'));
        expect(mockExecutor.capturedArguments, contains('--category'));
        expect(mockExecutor.capturedArguments, contains('תנ״ך'));
        expect(mockExecutor.capturedArguments, contains('--book'));
        expect(mockExecutor.capturedArguments, contains('בראשית'));
        expect(mockExecutor.capturedArguments, contains('--wildcard'));
      });

      test('should return error when process execution fails', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: '',
          stderr: 'Process failed',
          exitCode: 1,
        );

        final response = await searchService.search(query: 'test');

        expect(response.isSuccess, false);
        expect(response.errorMessage, 'Process failed');
        expect(response.results, isEmpty);
      });

      test(
        'should return generic error when process fails with empty stderr',
        () async {
          mockExecutor.mockResult = ProcessResult(
            stdout: '',
            stderr: '',
            exitCode: 1,
          );

          final response = await searchService.search(query: 'test');

          expect(response.isSuccess, false);
          expect(response.errorMessage, contains('שגיאה בהפעלת מנוע החיפוש'));
          expect(response.errorMessage, contains('קוד שגיאה: 1'));
          expect(response.results, isEmpty);
        },
      );

      test('should return error when parsing fails', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'invalid output',
          stderr: '',
          exitCode: 0,
        );

        mockParser.mockOutput = ParsedOutput.error('שגיאה בפענוח');

        final response = await searchService.search(query: 'test');

        expect(response.isSuccess, false);
        expect(response.errorMessage, 'שגיאה בפענוח');
        expect(response.results, isEmpty);
      });

      test('should return successful response with results', () async {
        final mockResults = [
          SearchResult(
            rank: 1,
            bookTitle: 'בראשית',
            reference: 'א:א',
            category: 'תנ״ך',
            snippet: 'בראשית ברא אלהים',
            score: 95.5,
            highlights: [],
          ),
        ];

        mockExecutor.mockResult = ProcessResult(
          stdout: 'valid output',
          stderr: '',
          exitCode: 0,
        );

        mockParser.mockOutput = ParsedOutput.success(
          metadata: SearchMetadata(
            query: 'test',
            totalResults: 1,
            elapsedMilliseconds: 50,
          ),
          results: mockResults,
        );

        final response = await searchService.search(query: 'test');

        expect(response.isSuccess, true);
        expect(response.errorMessage, isNull);
        expect(response.results, hasLength(1));
        expect(response.results.first.bookTitle, 'בראשית');
        expect(response.metadata.totalResults, 1);
        expect(response.metadata.elapsedMilliseconds, 50);
      });

      test('should handle unexpected exceptions', () async {
        // Make executor throw an exception
        mockExecutor.shouldThrowException = true;

        final response = await searchService.search(query: 'test');

        expect(response.isSuccess, false);
        expect(response.errorMessage, contains('שגיאה לא צפויה'));
        expect(response.results, isEmpty);
      });

      test('should use default limit when not specified', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'Query: test\nTotal Results: 0\nElapsed Time: 10ms\n',
          stderr: '',
          exitCode: 0,
        );

        await searchService.search(query: 'test');

        expect(mockExecutor.capturedArguments, contains('--limit'));
        expect(mockExecutor.capturedArguments, contains('50'));
      });

      test('should not include category when not provided', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'Query: test\nTotal Results: 0\nElapsed Time: 10ms\n',
          stderr: '',
          exitCode: 0,
        );

        await searchService.search(query: 'test');

        expect(mockExecutor.capturedArguments, isNot(contains('--category')));
      });

      test('should not include book when not provided', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'Query: test\nTotal Results: 0\nElapsed Time: 10ms\n',
          stderr: '',
          exitCode: 0,
        );

        await searchService.search(query: 'test');

        expect(mockExecutor.capturedArguments, isNot(contains('--book')));
      });

      test('should not include wildcard when not enabled', () async {
        mockExecutor.mockResult = ProcessResult(
          stdout: 'Query: test\nTotal Results: 0\nElapsed Time: 10ms\n',
          stderr: '',
          exitCode: 0,
        );

        await searchService.search(query: 'test');

        expect(mockExecutor.capturedArguments, isNot(contains('--wildcard')));
      });
    });

    group('validateConfiguration', () {
      test('should complete successfully when paths are valid', () async {
        mockConfig.mockValidationResult = true;

        await expectLater(searchService.validateConfiguration(), completes);
      });

      test('should throw exception when paths are invalid', () async {
        mockConfig.mockValidationResult = false;
        mockConfig.mockValidationDetails = {
          'searchEngineValid': false,
          'indexValid': false,
          'searchEnginePath': 'publish/OtzariaSearch.exe',
          'indexPath': './search_index',
          'errors': [
            'קובץ החיפוש לא נמצא בנתיב: publish/OtzariaSearch.exe',
            'תיקיית האינדקס לא נמצאה: ./search_index',
          ],
          'isValid': false,
        };

        await expectLater(
          searchService.validateConfiguration(),
          throwsA(isA<Exception>()),
        );
      });

      test('should include error messages in exception', () async {
        mockConfig.mockValidationResult = false;
        mockConfig.mockValidationDetails = {
          'errors': ['קובץ החיפוש לא נמצא', 'תיקיית האינדקס לא נמצאה'],
          'isValid': false,
        };

        try {
          await searchService.validateConfiguration();
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e.toString(), contains('קובץ החיפוש לא נמצא'));
          expect(e.toString(), contains('תיקיית האינדקס לא נמצאה'));
        }
      });
    });

    group('getSearchEnginePath', () {
      test('should return configured search engine path', () {
        mockConfig.mockSearchEnginePath = 'custom/path/search.exe';

        final path = searchService.getSearchEnginePath();

        expect(path, 'custom/path/search.exe');
      });
    });

    group('getIndexPath', () {
      test('should return configured index path', () {
        mockConfig.mockIndexPath = 'custom/index/path';

        final path = searchService.getIndexPath();

        expect(path, 'custom/index/path');
      });
    });
  });
}
