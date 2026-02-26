import '../models/search_response.dart';
import '../models/search_metadata.dart';
import 'process_executor.dart';
import 'output_parser.dart';
import 'configuration_manager.dart';

/// Orchestrates the search workflow by coordinating ProcessExecutor,
/// OutputParser, and ConfigurationManager.
///
/// This service provides the main search interface for the application,
/// handling configuration validation, process execution, output parsing,
/// and high-level error handling with Hebrew error messages.
class SearchService {
  final ProcessExecutor _executor;
  final OutputParser _parser;
  final ConfigurationManager _config;

  /// Creates a SearchService with the required dependencies.
  ///
  /// Parameters:
  /// - [executor]: The ProcessExecutor for running the search engine
  /// - [parser]: The OutputParser for parsing search output
  /// - [config]: The ConfigurationManager for accessing configuration
  SearchService({
    required ProcessExecutor executor,
    required OutputParser parser,
    required ConfigurationManager config,
  }) : _executor = executor,
       _parser = parser,
       _config = config;

  /// Performs a search operation with the given parameters.
  ///
  /// Coordinates the entire search workflow:
  /// 1. Validates the search query
  /// 2. Builds command arguments
  /// 3. Executes the search process
  /// 4. Parses the output
  /// 5. Handles errors at each stage
  ///
  /// Parameters:
  /// - [query]: The search query text (required, must not be empty)
  /// - [limit]: Maximum number of results to return (default: 50)
  /// - [category]: Optional category filter
  /// - [book]: Optional book filter
  /// - [wildcard]: Enables wildcard query syntax (* and ?)
  ///
  /// Returns a [SearchResponse] containing results and metadata, or an error message.
  Future<SearchResponse> search({
    required String query,
    int limit = 50,
    String? category,
    String? book,
    bool wildcard = false,
  }) async {
    // Validate query
    if (query.trim().isEmpty) {
      return SearchResponse(
        results: const [],
        metadata: SearchMetadata(
          query: query,
          totalResults: 0,
          elapsedMilliseconds: 0,
        ),
        errorMessage: 'נא להזין שאילתת חיפוש',
      );
    }

    try {
      // Get configured paths
      final searchEnginePath = getSearchEnginePath();
      final indexPath = getIndexPath();

      // Build command arguments
      final arguments = _executor.buildSearchArguments(
        query: query,
        indexPath: indexPath,
        limit: limit,
        category: category,
        book: book,
        wildcard: wildcard,
      );

      // Execute the search process
      final processResult = await _executor.execute(
        executablePath: searchEnginePath,
        arguments: arguments,
      );

      // Handle process execution errors
      if (!processResult.isSuccess) {
        final errorMsg = processResult.stderr.isNotEmpty
            ? processResult.stderr
            : 'שגיאה בהפעלת מנוע החיפוש (קוד שגיאה: ${processResult.exitCode})';

        return SearchResponse(
          results: const [],
          metadata: SearchMetadata(
            query: query,
            totalResults: 0,
            elapsedMilliseconds: 0,
          ),
          errorMessage: errorMsg,
        );
      }

      // Parse the output
      final parsedOutput = _parser.parse(processResult.stdout);

      // Handle parsing errors
      if (!parsedOutput.isValid) {
        return SearchResponse(
          results: const [],
          metadata: SearchMetadata(
            query: query,
            totalResults: 0,
            elapsedMilliseconds: 0,
          ),
          errorMessage: parsedOutput.errorMessage ?? 'שגיאה בפענוח התוצאות',
        );
      }

      // Return successful response
      return SearchResponse(
        results: parsedOutput.results,
        metadata: parsedOutput.metadata!,
        errorMessage: null,
      );
    } catch (e) {
      // Handle unexpected errors
      return SearchResponse(
        results: const [],
        metadata: SearchMetadata(
          query: query,
          totalResults: 0,
          elapsedMilliseconds: 0,
        ),
        errorMessage: 'שגיאה לא צפויה: ${e.toString()}',
      );
    }
  }

  /// Validates that the configuration paths exist and are accessible.
  ///
  /// This method should be called during application startup to ensure
  /// the search engine and index are available before allowing searches.
  ///
  /// Returns a Future that completes when validation is done.
  ///
  /// Throws an exception with a Hebrew error message if validation fails.
  Future<void> validateConfiguration() async {
    final isValid = await _config.validatePaths();

    if (!isValid) {
      // Get detailed validation results for specific error messages
      final details = await _config.getValidationDetails();
      final errors = details['errors'] as List<String>;

      if (errors.isNotEmpty) {
        throw Exception(errors.join('\n'));
      } else {
        throw Exception('שגיאה בבדיקת הגדרות המערכת');
      }
    }
  }

  /// Gets the configured search engine executable path.
  ///
  /// Returns the path from configuration, with platform-specific naming
  /// (adds .exe extension on Windows).
  String getSearchEnginePath() {
    return _config.searchEnginePath;
  }

  /// Gets the configured search index directory path.
  ///
  /// Returns the path to the search index directory from configuration.
  String getIndexPath() {
    return _config.indexPath;
  }
}
