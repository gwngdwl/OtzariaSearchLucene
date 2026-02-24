// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/main.dart';
import 'package:flutter_ui/services/configuration_manager.dart';

void main() {
  testWidgets('App displays SearchScreen with title', (
    WidgetTester tester,
  ) async {
    // Create a test configuration manager
    final configManager = ConfigurationManager();

    // Build our app and trigger a frame.
    await tester.pumpWidget(OtzariaSearchApp(configManager: configManager));

    // Verify that the SearchScreen title is displayed.
    expect(find.text('חיפוש אוצריא'), findsOneWidget);

    // Verify that the search button is displayed.
    expect(find.text('חפש'), findsOneWidget);
  });

  testWidgets('ConfigurationErrorApp displays error messages', (
    WidgetTester tester,
  ) async {
    // Create a test configuration manager
    final configManager = ConfigurationManager();

    // Create error messages
    final errors = [
      'קובץ החיפוש לא נמצא בנתיב: test/path',
      'תיקיית האינדקס לא נמצאה: test/index',
    ];

    // Build the error app
    await tester.pumpWidget(
      ConfigurationErrorApp(errors: errors, configManager: configManager),
    );

    // Verify that the error title is displayed
    expect(find.text('לא ניתן להפעיל את מנוע החיפוש'), findsOneWidget);

    // Verify that error messages are displayed
    expect(find.textContaining('קובץ החיפוש לא נמצא'), findsOneWidget);
    expect(find.textContaining('תיקיית האינדקס לא נמצאה'), findsOneWidget);

    // Verify that the retry button is displayed
    expect(find.text('נסה שוב'), findsOneWidget);
  });
}
