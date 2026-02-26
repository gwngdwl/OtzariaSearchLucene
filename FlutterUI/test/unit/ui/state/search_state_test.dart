import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/ui/state/search_state.dart';
import 'package:flutter_ui/services/search_service.dart';
import 'package:flutter_ui/models/search_response.dart';
import 'package:flutter_ui/models/search_metadata.dart';
import 'package:flutter_ui/models/search_result.dart';

/// Mock SearchService for testing
class MockSearchService implements SearchService {
  SearchResponse? _mockResponse;
  int _searchCallCount = 0;
  Map<String, dynamic>? _lastSearchParams;

  void setMockResponse(SearchResponse response) {
    _mockResponse = response;
  }

  int get searchCallCount => _searchCallCount;
  Map<String, dynamic>? get lastSearchParams => _lastSearchParams;

  @override
  Future<SearchResponse> search({
    required String query,
    int limit = 50,
    String? category,
    String? book,
    bool wildcard = false,
  }) async {
    _searchCallCount++;
    _lastSearchParams = {
      'query': query,
      'limit': limit,
      'category': category,
      'book': book,
      'wildcard': wildcard,
    };

    // Simulate async delay
    await Future.delayed(const Duration(milliseconds: 10));

    return _mockResponse ??
        SearchResponse(
          results: const [],
          metadata: SearchMetadata(
            query: query,
            totalResults: 0,
            elapsedMilliseconds: 10,
          ),
          errorMessage: null,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SearchState', () {
    late MockSearchService mockService;
    late SearchState searchState;

    setUp(() {
      mockService = MockSearchService();
      searchState = SearchState(searchService: mockService);
    });

    test('initial state should be empty', () {
      expect(searchState.currentRequest, isNull);
      expect(searchState.currentResponse, isNull);
      expect(searchState.isLoading, isFalse);
    });

    test('performSearch should update loading state correctly', () async {
      // Track loading state changes
      final loadingStates = <bool>[];
      searchState.addListener(() {
        loadingStates.add(searchState.isLoading);
      });

      // Perform search
      final searchFuture = searchState.performSearch(query: 'test');

      // Wait a bit to ensure loading state is set
      await Future.delayed(const Duration(milliseconds: 5));
      expect(searchState.isLoading, isTrue);

      // Wait for search to complete
      await searchFuture;
      expect(searchState.isLoading, isFalse);

      // Verify loading state transitions: true -> false
      expect(loadingStates, [true, false]);
    });

    test('performSearch should update currentRequest', () async {
      await searchState.performSearch(
        query: 'תורה',
        limit: 25,
        category: 'תנ״ך',
        book: 'בראשית',
        wildcard: true,
      );

      expect(searchState.currentRequest, isNotNull);
      expect(searchState.currentRequest!.query, 'תורה');
      expect(searchState.currentRequest!.limit, 25);
      expect(searchState.currentRequest!.category, 'תנ״ך');
      expect(searchState.currentRequest!.book, 'בראשית');
      expect(searchState.currentRequest!.wildcard, isTrue);
    });

    test('performSearch should update currentResponse', () async {
      final mockResponse = SearchResponse(
        results: [
          SearchResult(
            rank: 1,
            bookTitle: 'בראשית',
            reference: 'א:א',
            category: 'תנ״ך',
            snippet: 'בראשית ברא אלהים',
            score: 95.5,
            highlights: const [],
          ),
        ],
        metadata: SearchMetadata(
          query: 'בראשית',
          totalResults: 1,
          elapsedMilliseconds: 50,
        ),
        errorMessage: null,
      );

      mockService.setMockResponse(mockResponse);

      await searchState.performSearch(query: 'בראשית');

      expect(searchState.currentResponse, isNotNull);
      expect(searchState.currentResponse!.results.length, 1);
      expect(searchState.currentResponse!.metadata.query, 'בראשית');
      expect(searchState.currentResponse!.isSuccess, isTrue);
    });

    test(
      'performSearch should call SearchService with correct parameters',
      () async {
        await searchState.performSearch(
          query: 'משה',
          limit: 100,
          category: 'תורה',
          book: 'שמות',
          wildcard: true,
        );

        expect(mockService.searchCallCount, 1);
        expect(mockService.lastSearchParams!['query'], 'משה');
        expect(mockService.lastSearchParams!['limit'], 100);
        expect(mockService.lastSearchParams!['category'], 'תורה');
        expect(mockService.lastSearchParams!['book'], 'שמות');
        expect(mockService.lastSearchParams!['wildcard'], isTrue);
      },
    );

    test('performSearch should notify listeners on state changes', () async {
      int notificationCount = 0;
      searchState.addListener(() {
        notificationCount++;
      });

      await searchState.performSearch(query: 'test');

      // Should notify twice: once when loading starts, once when it ends
      expect(notificationCount, 2);
    });

    test('clearFilters should remove filters but keep query', () async {
      await searchState.performSearch(
        query: 'דוד',
        limit: 50,
        category: 'נביאים',
        book: 'שמואל',
        wildcard: true,
      );

      searchState.clearFilters();

      expect(searchState.currentRequest, isNotNull);
      expect(searchState.currentRequest!.query, 'דוד');
      expect(searchState.currentRequest!.limit, 50);
      expect(searchState.currentRequest!.category, isNull);
      expect(searchState.currentRequest!.book, isNull);
      expect(searchState.currentRequest!.wildcard, isTrue);
    });

    test('clearFilters should notify listeners', () async {
      await searchState.performSearch(query: 'test', category: 'cat');

      int notificationCount = 0;
      searchState.addListener(() {
        notificationCount++;
      });

      searchState.clearFilters();

      expect(notificationCount, 1);
    });

    test('clearFilters should do nothing if no current request', () {
      // Should not throw
      searchState.clearFilters();
      expect(searchState.currentRequest, isNull);
    });

    test('updateFilters should update filters but keep query', () async {
      await searchState.performSearch(
        query: 'שלמה',
        limit: 50,
        category: 'תנ״ך',
        book: 'מלכים',
        wildcard: true,
      );

      searchState.updateFilters(category: 'כתובים', book: 'משלי');

      expect(searchState.currentRequest, isNotNull);
      expect(searchState.currentRequest!.query, 'שלמה');
      expect(searchState.currentRequest!.limit, 50);
      expect(searchState.currentRequest!.category, 'כתובים');
      expect(searchState.currentRequest!.book, 'משלי');
      expect(searchState.currentRequest!.wildcard, isTrue);
    });

    test('updateFilters should allow clearing individual filters', () async {
      await searchState.performSearch(
        query: 'אברהם',
        category: 'תנ״ך',
        book: 'בראשית',
      );

      searchState.updateFilters(category: null, book: 'שמות');

      expect(searchState.currentRequest!.query, 'אברהם');
      expect(searchState.currentRequest!.category, isNull);
      expect(searchState.currentRequest!.book, 'שמות');
    });

    test('updateFilters should notify listeners', () async {
      await searchState.performSearch(query: 'test');

      int notificationCount = 0;
      searchState.addListener(() {
        notificationCount++;
      });

      searchState.updateFilters(category: 'new category');

      expect(notificationCount, 1);
    });

    test('updateFilters should do nothing if no current request', () {
      // Should not throw
      searchState.updateFilters(category: 'test');
      expect(searchState.currentRequest, isNull);
    });

    test('performSearch should handle errors gracefully', () async {
      final errorResponse = SearchResponse(
        results: const [],
        metadata: SearchMetadata(
          query: 'error',
          totalResults: 0,
          elapsedMilliseconds: 0,
        ),
        errorMessage: 'שגיאה בחיפוש',
      );

      mockService.setMockResponse(errorResponse);

      await searchState.performSearch(query: 'error');

      expect(searchState.isLoading, isFalse);
      expect(searchState.currentResponse, isNotNull);
      expect(searchState.currentResponse!.errorMessage, 'שגיאה בחיפוש');
      expect(searchState.currentResponse!.isSuccess, isFalse);
    });

    test(
      'multiple performSearch calls should update state correctly',
      () async {
        // First search
        await searchState.performSearch(query: 'first');
        expect(searchState.currentRequest!.query, 'first');

        // Second search
        await searchState.performSearch(query: 'second', limit: 100);
        expect(searchState.currentRequest!.query, 'second');
        expect(searchState.currentRequest!.limit, 100);

        // Third search with filters
        await searchState.performSearch(
          query: 'third',
          category: 'cat',
          book: 'book',
        );
        expect(searchState.currentRequest!.query, 'third');
        expect(searchState.currentRequest!.category, 'cat');
        expect(searchState.currentRequest!.book, 'book');
      },
    );

    test(
      'loading state should be false even if search throws exception',
      () async {
        // Create a service that throws
        final throwingService = _ThrowingSearchService();
        final state = SearchState(searchService: throwingService);

        try {
          await state.performSearch(query: 'test');
        } catch (e) {
          // Expected to throw
        }

        // Loading should still be false
        expect(state.isLoading, isFalse);
      },
    );
  });
}

/// Mock service that throws exceptions for testing error handling
class _ThrowingSearchService implements SearchService {
  @override
  Future<SearchResponse> search({
    required String query,
    int limit = 50,
    String? category,
    String? book,
    bool wildcard = false,
  }) async {
    throw Exception('Test exception');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
