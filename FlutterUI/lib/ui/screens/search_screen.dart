import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/search_metadata.dart';
import '../../models/search_result.dart';
import '../state/search_state.dart';
import '../widgets/filter_panel.dart';
import '../widgets/search_result_card.dart';

/// SearchScreen is the main screen containing the search interface.
///
/// This screen provides:
/// - Search text field with RTL and Hebrew support
/// - Search button and Enter key handling
/// - Result limit dropdown (10, 25, 50, 100) with default 50
/// - Filter panel integration for category and book filters
/// - Query validation before search
/// - Loading indicator during search operations
/// - Metadata display (total results, search time)
/// - Scrollable results list using ListView.builder
/// - Empty state message when no results are found
/// - Error message display for failed searches
/// - Integration with SearchState via Provider
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.3, 5.3, 5.4, 5.5, 6.3, 8.1, 8.2, 8.3**
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _wildcardPreferenceKey = 'search_wildcard_enabled';

  final TextEditingController _searchController = TextEditingController();
  int _resultLimit = 50; // Default result limit
  String? _categoryFilter;
  String? _bookFilter;
  bool _wildcardEnabled = false;
  bool _isSearchAreaCollapsed = false; // Track if search area is collapsed

  @override
  void initState() {
    super.initState();
    _loadWildcardPreference();
    // Check for configuration errors on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConfigurationErrors();
    });
  }

  Future<void> _loadWildcardPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final wildcardEnabled =
        preferences.getBool(_wildcardPreferenceKey) ?? false;
    if (!mounted) {
      return;
    }

    setState(() {
      _wildcardEnabled = wildcardEnabled;
    });
  }

  Future<void> _setWildcardEnabled(bool enabled) async {
    setState(() {
      _wildcardEnabled = enabled;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_wildcardPreferenceKey, enabled);
  }

  /// Checks for critical configuration errors and displays an AlertDialog if found.
  ///
  /// This method is called after the screen is built to check if there are
  /// any configuration issues that prevent the search functionality from working.
  ///
  /// **Validates: Requirements 6.1, 6.2, 7.4, 7.5**
  Future<void> _checkConfigurationErrors() async {
    final searchState = context.read<SearchState>();

    // Try to validate configuration
    try {
      await searchState.validateConfiguration();
    } catch (e) {
      // Show critical error dialog for configuration issues
      if (mounted) {
        _showCriticalErrorDialog(e.toString());
      }
    }
  }

  /// Shows an AlertDialog for critical configuration errors.
  ///
  /// This is used for errors that prevent the application from functioning,
  /// such as missing search engine executable or index directory.
  ///
  /// **Validates: Requirements 6.1, 6.2**
  void _showCriticalErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must acknowledge the error
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('שגיאה קריטית בהגדרות'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'לא ניתן להפעיל את מנוע החיפוש עקב בעיות בהגדרות:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(errorMessage, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                const Text(
                  'נא לבדוק:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• שקובץ החיפוש קיים בנתיב הנכון'),
                const Text('• שתיקיית האינדקס קיימת ונגישה'),
                const Text('• שמשתני הסביבה מוגדרים נכון (אם רלוונטי)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('סגור'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Retry validation
                await _checkConfigurationErrors();
              },
              child: const Text('נסה שוב'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Validates the search query.
  ///
  /// Returns true if the query is valid (non-empty after trimming),
  /// false otherwise. Shows an error message for invalid queries.
  ///
  /// **Validates: Requirement 6.3** - Empty query validation
  bool _validateQuery() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      // Show error message for empty query
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נא להזין שאילתת חיפוש'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  /// Triggers a search operation using the current query, filters, and result limit.
  ///
  /// This method:
  /// 1. Validates the query (must not be empty)
  /// 2. Calls SearchState.performSearch with query, limit, and filters
  /// 3. Shows appropriate error messages for transient errors
  ///
  /// **Validates: Requirements 3.2, 3.3, 4.3, 6.3, 6.4, 6.5**
  Future<void> _performSearch() async {
    // Validate query before search
    if (!_validateQuery()) {
      return;
    }

    final query = _searchController.text.trim();

    // Perform search using SearchState with filters
    final searchState = context.read<SearchState>();
    await searchState.performSearch(
      query: query,
      limit: _resultLimit,
      category: _categoryFilter,
      book: _bookFilter,
      wildcard: _wildcardEnabled,
    );

    // Show SnackBar for transient errors after search completes
    if (mounted && searchState.currentResponse != null) {
      final response = searchState.currentResponse!;
      if (!response.isSuccess && response.errorMessage != null) {
        _showErrorSnackBar(response.errorMessage!);
      }
    }
  }

  /// Shows a SnackBar with an error message for transient errors.
  ///
  /// This is used for errors that don't prevent the user from trying again,
  /// such as process execution failures or parsing errors.
  ///
  /// **Validates: Requirements 6.4, 6.5**
  void _showErrorSnackBar(String errorMessage) {
    // Determine error type and customize message if needed
    String displayMessage = errorMessage;
    IconData icon = Icons.error_outline;

    // Categorize error types for better user experience
    if (errorMessage.contains('קובץ החיפוש לא נמצא') ||
        errorMessage.contains('תיקיית האינדקס לא נמצאה')) {
      // Configuration errors - these are critical
      icon = Icons.settings_outlined;
    } else if (errorMessage.contains('שגיאה בפענוח התוצאות')) {
      // Parsing errors
      icon = Icons.warning_outlined;
    } else if (errorMessage.contains('שגיאה בהפעלת מנוע החיפוש')) {
      // Process execution errors
      icon = Icons.build_outlined;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(displayMessage, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'סגור',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Gets an appropriate icon for the error type.
  ///
  /// Returns different icons based on the error message content
  /// to provide better visual feedback to the user.
  ///
  /// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
  IconData _getErrorIcon(String errorMessage) {
    if (errorMessage.contains('קובץ החיפוש לא נמצא')) {
      return Icons.search_off; // File not found
    } else if (errorMessage.contains('תיקיית האינדקס לא נמצאה')) {
      return Icons.folder_off; // Index directory not found
    } else if (errorMessage.contains('נא להזין שאילתת חיפוש')) {
      return Icons.edit_off; // Empty query
    } else if (errorMessage.contains('שגיאה בפענוח התוצאות')) {
      return Icons.warning_amber; // Parsing error
    } else if (errorMessage.contains('שגיאה בהפעלת מנוע החיפוש')) {
      return Icons.build_circle; // Process execution error
    } else {
      return Icons.error_outline; // Generic error
    }
  }

  /// Gets an appropriate title for the error type.
  ///
  /// Returns different titles based on the error message content
  /// to provide better context to the user.
  ///
  /// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**
  String _getErrorTitle(String errorMessage) {
    if (errorMessage.contains('קובץ החיפוש לא נמצא')) {
      return 'קובץ החיפוש לא נמצא';
    } else if (errorMessage.contains('תיקיית האינדקס לא נמצאה')) {
      return 'תיקיית האינדקס לא נמצאה';
    } else if (errorMessage.contains('נא להזין שאילתת חיפוש')) {
      return 'שאילתה ריקה';
    } else if (errorMessage.contains('שגיאה בפענוח התוצאות')) {
      return 'שגיאה בפענוח התוצאות';
    } else if (errorMessage.contains('שגיאה בהפעלת מנוע החיפוש')) {
      return 'שגיאה בהפעלת מנוע החיפוש';
    } else {
      return 'שגיאה';
    }
  }

  /// Handles filter changes from FilterPanel.
  ///
  /// Updates the local filter state when the user modifies filters.
  ///
  /// **Validates: Requirement 4.3** - Filter integration
  void _onFiltersChanged({String? category, String? book}) {
    setState(() {
      _categoryFilter = category;
      _bookFilter = book;
    });
  }

  /// Handles clear filters action from FilterPanel.
  ///
  /// Clears the local filter state.
  ///
  /// **Validates: Requirement 4.4** - Clear filters functionality
  void _onClearFilters() {
    setState(() {
      _categoryFilter = null;
      _bookFilter = null;
    });
  }

  /// Builds the metadata section showing total results and search time.
  ///
  /// **Validates: Requirement 5.4** - Metadata display
  Widget _buildMetadataSection(SearchMetadata metadata) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.search, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'נמצאו ${metadata.totalResults} תוצאות',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.timer, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${metadata.elapsedMilliseconds}ms',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the scrollable list of search results using ListView.builder.
  ///
  /// **Validates: Requirement 5.3** - Scrollable results list
  Widget _buildResultsList(List<SearchResult> results) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return SearchResultCard(result: results[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חיפוש אוצריא'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Toggle button to collapse/expand search area
          IconButton(
            icon: Icon(
              _isSearchAreaCollapsed ? Icons.expand_more : Icons.expand_less,
            ),
            tooltip: _isSearchAreaCollapsed
                ? 'הרחב אזור חיפוש'
                : 'כווץ אזור חיפוש',
            onPressed: () {
              setState(() {
                _isSearchAreaCollapsed = !_isSearchAreaCollapsed;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsible search area
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isSearchAreaCollapsed ? 0 : null,
              child: _isSearchAreaCollapsed
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search text field with RTL support
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: TextField(
                            controller: _searchController,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              labelText: 'חיפוש',
                              hintText: 'הזן טקסט לחיפוש...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) =>
                                _performSearch(), // Trigger search on Enter
                          ),
                        ),
                        const SizedBox(height: 16),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: SwitchListTile(
                            key: const Key('wildcard_toggle'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Wildcard (*, ?)'),
                            subtitle: const Text(
                              'הפעלת חיפוש עם תווי כלליים',
                            ),
                            value: _wildcardEnabled,
                            onChanged: (value) {
                              _setWildcardEnabled(value);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Result limit dropdown and search button row
                        Row(
                          children: [
                            // Result limit dropdown
                            Expanded(
                              child: Row(
                                children: [
                                  const Text('מספר תוצאות: '),
                                  const SizedBox(width: 8),
                                  DropdownButton<int>(
                                    value: _resultLimit,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 10,
                                        child: Text('10'),
                                      ),
                                      DropdownMenuItem(
                                        value: 25,
                                        child: Text('25'),
                                      ),
                                      DropdownMenuItem(
                                        value: 50,
                                        child: Text('50'),
                                      ),
                                      DropdownMenuItem(
                                        value: 100,
                                        child: Text('100'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _resultLimit = value;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Search button
                            ElevatedButton.icon(
                              onPressed: _performSearch,
                              icon: const Icon(Icons.search),
                              label: const Text('חפש'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Filter panel integration
                        FilterPanel(
                          onFiltersChanged: _onFiltersChanged,
                          onClearFilters: _onClearFilters,
                          initialCategory: _categoryFilter,
                          initialBook: _bookFilter,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),

            // Results area with metadata and results list
            Expanded(
              child: Consumer<SearchState>(
                builder: (context, searchState, child) {
                  // Show loading indicator during search
                  if (searchState.isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'מחפש...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Show initial state when no search has been performed
                  if (searchState.currentResponse == null) {
                    return const Center(
                      child: Text(
                        'הזן שאילתת חיפוש כדי להתחיל',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  final response = searchState.currentResponse!;

                  // Show error message if search failed
                  if (!response.isSuccess) {
                    return Center(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getErrorIcon(response.errorMessage ?? ''),
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _getErrorTitle(response.errorMessage ?? ''),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  response.errorMessage ?? 'שגיאה לא ידועה',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _performSearch,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('נסה שוב'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Show "no results" message when search returned empty
                  if (response.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'לא נמצאו תוצאות עבור "${response.metadata.query}"',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'נסה מילות חיפוש אחרות או הסר פילטרים',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Display results with metadata
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Metadata section
                      _buildMetadataSection(response.metadata),
                      const SizedBox(height: 8),

                      // Results list
                      Expanded(child: _buildResultsList(response.results)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
