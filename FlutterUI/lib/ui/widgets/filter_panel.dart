import 'package:flutter/material.dart';

/// A panel widget that provides filtering options for search results.
///
/// Displays text fields for category and book filters with RTL support
/// for Hebrew text. Includes a clear filters button that resets both fields.
/// Integrates with SearchState for filter management.
///
/// **Validates: Requirements 4.1, 4.2, 4.4, 8.2, 8.3**
class FilterPanel extends StatefulWidget {
  /// Callback invoked when filters are updated.
  ///
  /// Parameters:
  /// - category: The category filter value (null if empty)
  /// - book: The book filter value (null if empty)
  final void Function({String? category, String? book}) onFiltersChanged;

  /// Callback invoked when the clear filters button is pressed.
  final VoidCallback onClearFilters;

  /// Initial category filter value.
  final String? initialCategory;

  /// Initial book filter value.
  final String? initialBook;

  const FilterPanel({
    super.key,
    required this.onFiltersChanged,
    required this.onClearFilters,
    this.initialCategory,
    this.initialBook,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late TextEditingController _categoryController;
  late TextEditingController _bookController;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.initialCategory);
    _bookController = TextEditingController(text: widget.initialBook);

    // Listen to changes and notify parent
    _categoryController.addListener(_onFilterChanged);
    _bookController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _bookController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    widget.onFiltersChanged(
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      book: _bookController.text.trim().isEmpty
          ? null
          : _bookController.text.trim(),
    );
  }

  void _clearFilters() {
    _categoryController.clear();
    _bookController.clear();
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'סינון תוצאות',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Clear filters button
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('נקה סינון'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category filter field
              TextField(
                controller: _categoryController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'קטגוריה',
                  hintText: 'לדוגמה: תנ״ך, משנה, תלמוד',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Book filter field
              TextField(
                controller: _bookController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'ספר',
                  hintText: 'לדוגמה: בראשית, שמות',
                  prefixIcon: const Icon(Icons.book_outlined),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
