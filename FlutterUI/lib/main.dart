import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/search_service.dart';
import 'services/process_executor.dart';
import 'services/output_parser.dart';
import 'services/configuration_manager.dart';
import 'ui/state/search_state.dart';
import 'ui/screens/search_screen.dart';

/// Main entry point for the Otzaria Search Flutter application.
///
/// This function:
/// 1. Initializes ConfigurationManager and loads configuration
/// 2. Validates that search engine and index paths exist
/// 3. Creates all service dependencies (ProcessExecutor, OutputParser, SearchService)
/// 4. Sets up Provider with SearchState
/// 5. Handles critical initialization errors gracefully
///
/// **Validates: Requirements 7.4, 7.5, 8.1, 8.2, 8.5**
void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ConfigurationManager and load configuration
  final configManager = ConfigurationManager();

  try {
    // Load configuration from file and environment variables
    await configManager.loadConfiguration();

    // Validate that configured paths exist
    final validationDetails = await configManager.getValidationDetails();

    if (!validationDetails['isValid']) {
      // If validation fails, show error screen
      runApp(
        ConfigurationErrorApp(
          errors: validationDetails['errors'] as List<String>,
          configManager: configManager,
        ),
      );
      return;
    }
  } catch (e) {
    // Handle critical initialization errors
    runApp(
      ConfigurationErrorApp(
        errors: ['שגיאה באתחול המערכת: ${e.toString()}'],
        configManager: configManager,
      ),
    );
    return;
  }

  // If configuration is valid, run the main app
  runApp(OtzariaSearchApp(configManager: configManager));
}

/// Main application widget with properly initialized services.
///
/// This widget sets up:
/// - All service dependencies with validated configuration
/// - Provider state management with SearchState
/// - MaterialApp with Hebrew and RTL support
/// - Theme with Hebrew-compatible fonts
///
/// **Validates: Requirements 8.1, 8.2, 8.5**
class OtzariaSearchApp extends StatelessWidget {
  final ConfigurationManager configManager;

  const OtzariaSearchApp({super.key, required this.configManager});

  @override
  Widget build(BuildContext context) {
    // Initialize services with validated configuration
    final processExecutor = ProcessExecutor();
    final outputParser = OutputParser();
    final searchService = SearchService(
      executor: processExecutor,
      parser: outputParser,
      config: configManager,
    );

    return MultiProvider(
      providers: [
        // Provide SearchState with SearchService dependency
        ChangeNotifierProvider(
          create: (_) => SearchState(searchService: searchService),
        ),
      ],
      child: MaterialApp(
        title: 'חיפוש אוצריא',

        // Hebrew and RTL support
        locale: const Locale('he', 'IL'),

        // Support RTL text direction
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,

          // Use fonts that support Hebrew
          // Roboto has good Hebrew support, but can be customized
          fontFamily: 'Roboto',

          // Ensure text direction is RTL
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 14),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),

        home: const SearchScreen(),
      ),
    );
  }
}

/// Error screen displayed when critical configuration errors occur during startup.
///
/// This widget shows:
/// - Clear error messages in Hebrew
/// - Specific details about what went wrong
/// - Guidance on how to fix the issues
/// - Retry button to re-validate configuration
///
/// **Validates: Requirements 6.1, 6.2, 7.4, 7.5**
class ConfigurationErrorApp extends StatelessWidget {
  final List<String> errors;
  final ConfigurationManager configManager;

  const ConfigurationErrorApp({
    super.key,
    required this.errors,
    required this.configManager,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'שגיאת הגדרות - חיפוש אוצריא',
      locale: const Locale('he', 'IL'),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('שגיאת הגדרות'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error icon and title
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'לא ניתן להפעיל את מנוע החיפוש',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Error details
                      const Text(
                        'נמצאו הבעיות הבאות:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...errors.map(
                        (error) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            right: 16.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Guidance section
                      const Text(
                        'נא לבדוק:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.only(right: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• שקובץ החיפוש קיים בנתיב הנכון',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• שתיקיית האינדקס קיימת ונגישה',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• שמשתני הסביבה מוגדרים נכון (אם רלוונטי)',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• שיש הרשאות קריאה לקבצים והתיקיות',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Configuration details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'נתיבים מוגדרים:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'קובץ חיפוש: ${configManager.searchEnginePath}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'תיקיית אינדקס: ${configManager.indexPath}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Retry button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Retry initialization
                            try {
                              await configManager.loadConfiguration();
                              final validationDetails = await configManager
                                  .getValidationDetails();

                              if (validationDetails['isValid']) {
                                // Configuration is now valid, restart the app
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => OtzariaSearchApp(
                                      configManager: configManager,
                                    ),
                                  ),
                                );
                              } else {
                                // Still invalid, show updated errors
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => ConfigurationErrorApp(
                                      errors:
                                          validationDetails['errors']
                                              as List<String>,
                                      configManager: configManager,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              // Show error in snackbar
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'שגיאה באימות הגדרות: ${e.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('נסה שוב'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
