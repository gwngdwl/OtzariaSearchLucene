import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/ui/widgets/filter_panel.dart';

void main() {
  group('FilterPanel Widget Tests', () {
    testWidgets('displays all required elements', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {},
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Assert - Check all required elements exist
      expect(find.text('סינון תוצאות'), findsOneWidget);
      expect(find.text('נקה סינון'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('קטגוריה'), findsOneWidget);
      expect(find.text('ספר'), findsOneWidget);
    });

    testWidgets('supports RTL text direction', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {},
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Assert - Check RTL directionality
      final directionality = tester.widget<Directionality>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(Directionality),
        ),
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });

    testWidgets('calls onFiltersChanged when category is entered', (
      tester,
    ) async {
      // Arrange
      String? capturedCategory;
      String? capturedBook;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {
                capturedCategory = category;
                capturedBook = book;
              },
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Act - Enter text in category field
      final categoryField = find.byType(TextField).first;
      await tester.enterText(categoryField, 'תנ״ך');
      await tester.pump();

      // Assert
      expect(capturedCategory, 'תנ״ך');
      expect(capturedBook, null);
    });

    testWidgets('calls onFiltersChanged when book is entered', (tester) async {
      // Arrange
      String? capturedCategory;
      String? capturedBook;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {
                capturedCategory = category;
                capturedBook = book;
              },
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Act - Enter text in book field
      final bookField = find.byType(TextField).last;
      await tester.enterText(bookField, 'בראשית');
      await tester.pump();

      // Assert
      expect(capturedCategory, null);
      expect(capturedBook, 'בראשית');
    });

    testWidgets('calls onClearFilters when clear button is pressed', (
      tester,
    ) async {
      // Arrange
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {},
              onClearFilters: () {
                clearCalled = true;
              },
            ),
          ),
        ),
      );

      // Act - Tap the clear button
      await tester.tap(find.text('נקה סינון'));
      await tester.pump();

      // Assert
      expect(clearCalled, true);
    });

    testWidgets('clears text fields when clear button is pressed', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {},
              onClearFilters: () {},
              initialCategory: 'תנ״ך',
              initialBook: 'בראשית',
            ),
          ),
        ),
      );

      // Verify initial values
      expect(find.text('תנ״ך'), findsOneWidget);
      expect(find.text('בראשית'), findsOneWidget);

      // Act - Tap the clear button
      await tester.tap(find.text('נקה סינון'));
      await tester.pump();

      // Assert - Text fields should be empty
      final categoryField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      final bookField = tester.widget<TextField>(find.byType(TextField).last);

      expect(categoryField.controller?.text, isEmpty);
      expect(bookField.controller?.text, isEmpty);
    });

    testWidgets('initializes with provided initial values', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {},
              onClearFilters: () {},
              initialCategory: 'משנה',
              initialBook: 'אבות',
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('משנה'), findsOneWidget);
      expect(find.text('אבות'), findsOneWidget);
    });

    testWidgets('handles Hebrew text input correctly', (tester) async {
      // Arrange
      String? capturedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {
                capturedCategory = category;
              },
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Act - Enter Hebrew text with special characters
      final categoryField = find.byType(TextField).first;
      await tester.enterText(categoryField, 'תנ״ך ומדרשים');
      await tester.pump();

      // Assert
      expect(capturedCategory, 'תנ״ך ומדרשים');
    });

    testWidgets('trims whitespace from filter values', (tester) async {
      // Arrange
      String? capturedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {
                capturedCategory = category;
              },
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Act - Enter text with leading/trailing whitespace
      final categoryField = find.byType(TextField).first;
      await tester.enterText(categoryField, '  תנ״ך  ');
      await tester.pump();

      // Assert - Whitespace should be trimmed
      expect(capturedCategory, 'תנ״ך');
    });

    testWidgets('returns null for empty filter values', (tester) async {
      // Arrange
      String? capturedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPanel(
              onFiltersChanged: ({String? category, String? book}) {
                capturedCategory = category;
              },
              onClearFilters: () {},
            ),
          ),
        ),
      );

      // Act - Enter only whitespace
      final categoryField = find.byType(TextField).first;
      await tester.enterText(categoryField, '   ');
      await tester.pump();

      // Assert - Should return null for whitespace-only input
      expect(capturedCategory, null);
    });
  });
}
