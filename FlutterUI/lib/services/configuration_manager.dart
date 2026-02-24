import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/app_configuration.dart';

/// Manages application configuration with support for multiple sources.
///
/// Configuration sources in priority order:
/// 1. Environment variables (OTZARIA_SEARCH_PATH, OTZARIA_INDEX_PATH)
/// 2. Configuration file (assets/config.json)
/// 3. Default values
///
/// Validates that configured paths exist before use.
class ConfigurationManager {
  /// Default path to the search engine executable.
  static const String _defaultSearchEnginePath = 'publish/OtzariaSearch.exe';

  /// Default path to the search index directory.
  static const String _defaultIndexPath = './search_index';

  /// Environment variable name for search engine path override.
  static const String _envSearchPath = 'OTZARIA_SEARCH_PATH';

  /// Environment variable name for index path override.
  static const String _envIndexPath = 'OTZARIA_INDEX_PATH';

  /// Path to the configuration file in assets.
  static const String _configFilePath = 'assets/config.json';

  /// Current application configuration.
  AppConfiguration? _configuration;

  /// Gets the configured search engine path.
  ///
  /// Returns the path from environment variables, config file, or default.
  String get searchEnginePath =>
      _configuration?.searchEnginePath ?? _defaultSearchEnginePath;

  /// Gets the configured index path.
  ///
  /// Returns the path from environment variables, config file, or default.
  String get indexPath => _configuration?.indexPath ?? _defaultIndexPath;

  /// Gets the default result limit.
  int get defaultResultLimit => _configuration?.defaultResultLimit ?? 50;

  /// Loads configuration from all sources.
  ///
  /// Loads from config.json, then applies environment variable overrides.
  /// Falls back to defaults if config file is not found or invalid.
  ///
  /// This method should be called during application initialization.
  Future<void> loadConfiguration() async {
    try {
      // Try to load from config file
      final configString = await rootBundle.loadString(_configFilePath);
      final configJson = json.decode(configString) as Map<String, dynamic>;
      _configuration = AppConfiguration.fromJson(configJson);
    } catch (e) {
      // If config file doesn't exist or is invalid, use defaults
      _configuration = const AppConfiguration(
        searchEnginePath: _defaultSearchEnginePath,
        indexPath: _defaultIndexPath,
        defaultResultLimit: 50,
      );
    }

    // Apply environment variable overrides
    overrideFromEnvironment();
  }

  /// Overrides configuration values from environment variables.
  ///
  /// Checks for OTZARIA_SEARCH_PATH and OTZARIA_INDEX_PATH environment
  /// variables and overrides the corresponding configuration values if found.
  ///
  /// This method is called automatically by [loadConfiguration] but can also
  /// be called manually to refresh environment variable overrides.
  void overrideFromEnvironment() {
    if (_configuration == null) {
      return;
    }

    final envSearchPath = Platform.environment[_envSearchPath];
    final envIndexPath = Platform.environment[_envIndexPath];

    // Only create a new configuration if there are overrides
    if (envSearchPath != null || envIndexPath != null) {
      _configuration = AppConfiguration(
        searchEnginePath: envSearchPath ?? _configuration!.searchEnginePath,
        indexPath: envIndexPath ?? _configuration!.indexPath,
        defaultResultLimit: _configuration!.defaultResultLimit,
      );
    }
  }

  /// Validates that configured paths exist and are accessible.
  ///
  /// Checks that:
  /// - The search engine executable exists at [searchEnginePath]
  /// - The index directory exists at [indexPath]
  ///
  /// Returns `true` if all paths are valid, `false` otherwise.
  ///
  /// This method should be called after [loadConfiguration] to ensure
  /// the application can function properly.
  Future<bool> validatePaths() async {
    try {
      // Check if search engine executable exists
      final searchEngineFile = File(searchEnginePath);
      final searchEngineExists = await searchEngineFile.exists();

      if (!searchEngineExists) {
        return false;
      }

      // Check if index directory exists
      final indexDirectory = Directory(indexPath);
      final indexExists = await indexDirectory.exists();

      if (!indexExists) {
        return false;
      }

      return true;
    } catch (e) {
      // If any error occurs during validation, consider paths invalid
      return false;
    }
  }

  /// Gets a detailed validation result with specific error messages.
  ///
  /// Returns a map with validation results for each path:
  /// - 'searchEngineValid': true if search engine exists
  /// - 'indexValid': true if index directory exists
  /// - 'searchEnginePath': the path that was checked
  /// - 'indexPath': the path that was checked
  /// - 'errors': list of error messages for invalid paths
  Future<Map<String, dynamic>> getValidationDetails() async {
    final errors = <String>[];

    // Check search engine
    final searchEngineFile = File(searchEnginePath);
    final searchEngineExists = await searchEngineFile.exists();
    if (!searchEngineExists) {
      errors.add('קובץ החיפוש לא נמצא בנתיב: $searchEnginePath');
    }

    // Check index directory
    final indexDirectory = Directory(indexPath);
    final indexExists = await indexDirectory.exists();
    if (!indexExists) {
      errors.add('תיקיית האינדקס לא נמצאה: $indexPath');
    }

    return {
      'searchEngineValid': searchEngineExists,
      'indexValid': indexExists,
      'searchEnginePath': searchEnginePath,
      'indexPath': indexPath,
      'errors': errors,
      'isValid': errors.isEmpty,
    };
  }

  /// Gets the current configuration.
  ///
  /// Returns null if configuration has not been loaded yet.
  AppConfiguration? get configuration => _configuration;
}
