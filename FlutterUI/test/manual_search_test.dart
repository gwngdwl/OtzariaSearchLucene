// Run this with: dart test/manual_search_test.dart
// Make sure to run from the FlutterUI directory

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_ui/services/search_service.dart';
import 'package:flutter_ui/services/process_executor.dart';
import 'package:flutter_ui/services/output_parser.dart';
import 'package:flutter_ui/services/configuration_manager.dart';

/// Manual test script to verify SearchService works with the real binary.
///
/// This script performs a real search using the OtzariaSearch.exe binary
/// and displays the results to verify the entire service layer is working.
void main() async {
  print('=== בדיקה ידנית של SearchService ===\n');

  // Create service instances
  final executor = ProcessExecutor();
  final parser = OutputParser();
  final config = ConfigurationManager();

  // Load configuration
  print('טוען הגדרות...');
  await config.loadConfiguration();
  print('נתיב מנוע חיפוש: ${config.searchEnginePath}');
  print('נתיב אינדקס: ${config.indexPath}\n');

  // Validate configuration
  print('מאמת נתיבים...');
  try {
    final searchService = SearchService(
      executor: executor,
      parser: parser,
      config: config,
    );

    await searchService.validateConfiguration();
    print('✓ כל הנתיבים תקינים\n');

    // Perform a test search
    print('מבצע חיפוש לדוגמה: "תורה"...');
    final response = await searchService.search(query: 'תורה', limit: 5);

    if (response.isSuccess) {
      print('✓ החיפוש הצליח!\n');
      print('--- מטא-דאטה ---');
      print('שאילתה: ${response.metadata.query}');
      print('סה"כ תוצאות: ${response.metadata.totalResults}');
      print('זמן חיפוש: ${response.metadata.elapsedMilliseconds}ms\n');

      print('--- תוצאות (${response.results.length} ראשונות) ---');
      for (final result in response.results) {
        print('\n${result.rank}. ${result.bookTitle}');
        print('   הפניה: ${result.reference}');
        print('   קטגוריה: ${result.category}');
        print('   ציון: ${result.score.toStringAsFixed(2)}');
        print(
          '   קטע: ${result.snippet.substring(0, result.snippet.length > 100 ? 100 : result.snippet.length)}...',
        );
        if (result.highlights.isNotEmpty) {
          print('   הדגשות: ${result.highlights.length} מילים');
        }
      }

      print('\n✓ הבדיקה הידנית הושלמה בהצלחה!');
      exit(0);
    } else {
      print('✗ החיפוש נכשל!');
      print('שגיאה: ${response.errorMessage}');
      exit(1);
    }
  } catch (e) {
    print('✗ שגיאה באימות הגדרות: $e');
    exit(1);
  }
}
