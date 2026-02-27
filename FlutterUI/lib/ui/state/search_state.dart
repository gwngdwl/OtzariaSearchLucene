import 'package:flutter/foundation.dart';
import '../../models/search_request.dart';
import '../../models/search_response.dart';
import '../../services/search_service.dart';

/// Manages the state of the search interface using ChangeNotifier.
///
/// This class provides state management for the search functionality,
/// maintaining the current search request, response, and loading state.
/// It notifies listeners whenever the state changes to trigger UI updates.
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.6, 4.3, 4.4, 4.5**
class SearchState extends ChangeNotifier {
  final SearchService _searchService;

  SearchRequest? _currentRequest;
  SearchResponse? _currentResponse;
  bool _isLoading = false;

  /// Creates a SearchState with the required SearchService dependency.
  SearchState({required SearchService searchService})
    : _searchService = searchService;

  /// Gets the current search request, or null if no search has been performed.
  SearchRequest? get currentRequest => _currentRequest;

  /// Gets the current search response, or null if no search has been performed.
  SearchResponse? get currentResponse => _currentResponse;

  /// Returns true if a search operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Performs a search operation with the given parameters.
  ///
  /// This method:
  /// 1. Sets loading state to true and notifies listeners
  /// 2. Creates a SearchRequest with the provided parameters
  /// 3. Calls SearchService to perform the search
  /// 4. Updates the current request and response
  /// 5. Sets loading state to false and notifies listeners
  ///
  /// Parameters:
  /// - [query]: The search query text (required)
  /// - [limit]: Maximum number of results (default: 100000)
  /// - [category]: Optional category filter
  /// - [book]: Optional book filter
  /// - [wildcard]: Enables wildcard query syntax (* and ?)
  ///
  /// The method ensures notifyListeners is called for all state changes
  /// to keep the UI synchronized.
  Future<void> performSearch({
    required String query,
    int limit = 100000,
    String? category,
    String? book,
    bool wildcard = false,
  }) async {
    // Set loading state and notify listeners
    _isLoading = true;
    notifyListeners();

    try {
      // Create search request
      _currentRequest = SearchRequest(
        query: query,
        limit: limit,
        category: category,
        book: book,
        wildcard: wildcard,
      );

      // Perform search
      _currentResponse = await _searchService.search(
        query: query,
        limit: limit,
        category: category,
        book: book,
        wildcard: wildcard,
      );
    } finally {
      // Always clear loading state, even if an error occurs
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears all filters (category and book) while retaining the search query.
  ///
  /// This method updates the current request to remove filters and
  /// notifies listeners to update the UI. The search query remains unchanged.
  ///
  /// **Validates: Requirement 4.4** - Clear filters functionality
  /// **Validates: Requirement 4.5** - Query retention on filter change
  void clearFilters() {
    if (_currentRequest != null) {
      _currentRequest = SearchRequest(
        query: _currentRequest!.query,
        limit: _currentRequest!.limit,
        category: null,
        book: null,
        wildcard: _currentRequest!.wildcard,
      );
      notifyListeners();
    }
  }

  /// Updates the filters (category and/or book) while retaining the search query.
  ///
  /// This method updates the current request with new filter values and
  /// notifies listeners to update the UI. The search query remains unchanged.
  ///
  /// Parameters:
  /// - [category]: New category filter value (null to clear)
  /// - [book]: New book filter value (null to clear)
  ///
  /// **Validates: Requirement 4.3** - Filter inclusion in search
  /// **Validates: Requirement 4.5** - Query retention on filter change
  void updateFilters({String? category, String? book}) {
    if (_currentRequest != null) {
      _currentRequest = SearchRequest(
        query: _currentRequest!.query,
        limit: _currentRequest!.limit,
        category: category,
        book: book,
        wildcard: _currentRequest!.wildcard,
      );
      notifyListeners();
    }
  }

  /// Validates the application configuration.
  ///
  /// This method checks that the search engine executable and index directory
  /// exist and are accessible. It should be called during application startup
  /// or when the user wants to verify the configuration.
  ///
  /// Throws an exception with a Hebrew error message if validation fails.
  ///
  /// **Validates: Requirements 6.1, 6.2, 7.4, 7.5**
  Future<void> validateConfiguration() async {
    await _searchService.validateConfiguration();
  }
}
