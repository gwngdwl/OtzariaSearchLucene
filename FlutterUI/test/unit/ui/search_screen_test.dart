import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ui/ui/screens/search_screen.dart';
import 'package:flutter_ui/ui/state/search_state.dart';
import 'package:flutter_ui/services/search_service.dart';
import 'package:flutter_ui/services/process_executor.dart';
import 'package:flutter_ui/services/output_parser.dart';
import 'package:flutter_ui/services/configuration_manager.dart';

void main() {
  group('SearchScreen Basic Structure Tests', () {
    late SearchService searchService;
    late SearchState searchState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Initialize services for testing
      final configManager = ConfigurationManager();
      final processExecutor = ProcessExecutor();
      final outputParser = OutputParser();
      searchService = SearchService(
        executor: processExecutor,
        parser: outputParser,
        config: configManager,
      );
      searchState = SearchState(searchService: searchService);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider<SearchState>.value(
          value: searchState,
          child: const SearchScreen(),
        ),
      );
    }

    testWidgets('SearchScreen displays all required UI elements', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Verify AppBar with title
      expect(find.text('חיפוש אוצריא'), findsOneWidget);

      // Verify text fields exist (search + filter fields)
      expect(
        find.byType(TextField),
        findsNWidgets(3),
      ); // search, category, book

      // Verify search button exists
      expect(find.widgetWithText(ElevatedButton, 'חפש'), findsOneWidget);

      // Verify result limit dropdown exists
      expect(find.byType(DropdownButton<int>), findsOneWidget);

      // Verify result limit label
      expect(find.text('מספר תוצאות: '), findsOneWidget);
      expect(find.text('Wildcard (*, ?)'), findsOneWidget);
    });

    testWidgets('SearchScreen has correct default result limit', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Find the dropdown button
      final dropdownFinder = find.byType(DropdownButton<int>);
      expect(dropdownFinder, findsOneWidget);

      // Verify default value is 50
      final dropdown = tester.widget<DropdownButton<int>>(dropdownFinder);
      expect(dropdown.value, equals(50));
    });

    testWidgets('SearchScreen dropdown has all required options', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // Verify all options are present
      expect(find.text('10').hitTestable(), findsOneWidget);
      expect(find.text('25').hitTestable(), findsOneWidget);
      expect(
        find.text('50').hitTestable(),
        findsWidgets,
      ); // Multiple because one is selected
      expect(find.text('100').hitTestable(), findsOneWidget);
    });

    testWidgets('SearchScreen text field has RTL support', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Find all TextFields
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsNWidgets(3));

      // Get the first TextField widget (search field)
      final textField = tester.widget<TextField>(textFieldFinder.first);

      // Verify RTL text direction
      expect(textField.textDirection, equals(TextDirection.rtl));
      expect(textField.textAlign, equals(TextAlign.right));
    });

    testWidgets('SearchScreen shows empty state message initially', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Verify initial empty state message
      expect(find.text('הזן שאילתת חיפוש כדי להתחיל'), findsOneWidget);
    });

    testWidgets('SearchScreen shows error for empty query', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Tap search button without entering text
      await tester.tap(find.widgetWithText(ElevatedButton, 'חפש'));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('נא להזין שאילתת חיפוש'), findsOneWidget);
    });

    testWidgets('SearchScreen can change result limit', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // Select 25 from the dropdown
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();

      // Verify the dropdown value changed
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(dropdown.value, equals(25));
    });

    testWidgets('SearchScreen text field accepts Hebrew input', (
      WidgetTester tester,
    ) async {
      // Build the SearchScreen
      await tester.pumpWidget(createTestWidget());

      // Enter Hebrew text in the first TextField (search field)
      await tester.enterText(find.byType(TextField).first, 'תורה');
      await tester.pump();

      // Verify the text was entered
      expect(find.text('תורה'), findsOneWidget);
    });

    testWidgets('SearchScreen wildcard toggle is disabled by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('wildcard_toggle')),
      );
      expect(toggle.value, isFalse);
    });

    testWidgets('SearchScreen loads persisted wildcard preference', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({'search_wildcard_enabled': true});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('wildcard_toggle')),
      );
      expect(toggle.value, isTrue);
    });
  });
}
