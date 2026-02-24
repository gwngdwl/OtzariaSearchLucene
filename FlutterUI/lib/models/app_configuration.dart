/// Application configuration for the Otzaria search Flutter UI.
///
/// Contains paths to the search engine executable and index directory,
/// as well as default settings like result limit.
class AppConfiguration {
  /// Path to the OtzariaSearch executable.
  final String searchEnginePath;

  /// Path to the search index directory.
  final String indexPath;

  /// Default maximum number of results to return (default: 50).
  final int defaultResultLimit;

  const AppConfiguration({
    required this.searchEnginePath,
    required this.indexPath,
    this.defaultResultLimit = 50,
  });

  /// Creates an AppConfiguration from a JSON map.
  factory AppConfiguration.fromJson(Map<String, dynamic> json) {
    return AppConfiguration(
      searchEnginePath: json['searchEnginePath'] as String,
      indexPath: json['indexPath'] as String,
      defaultResultLimit: json['defaultResultLimit'] as int? ?? 50,
    );
  }

  /// Converts this AppConfiguration to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'searchEnginePath': searchEnginePath,
      'indexPath': indexPath,
      'defaultResultLimit': defaultResultLimit,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfiguration &&
          runtimeType == other.runtimeType &&
          searchEnginePath == other.searchEnginePath &&
          indexPath == other.indexPath &&
          defaultResultLimit == other.defaultResultLimit;

  @override
  int get hashCode =>
      Object.hash(searchEnginePath, indexPath, defaultResultLimit);

  @override
  String toString() =>
      'AppConfiguration(searchEnginePath: $searchEnginePath, '
      'indexPath: $indexPath, defaultResultLimit: $defaultResultLimit)';
}
