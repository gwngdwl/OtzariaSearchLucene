import 'dart:convert';
import 'dart:io';

/// Result of a process execution.
///
/// Contains the stdout, stderr, exit code, and success status of a process.
class ProcessResult {
  /// The standard output from the process.
  final String stdout;

  /// The standard error output from the process.
  final String stderr;

  /// The exit code returned by the process.
  final int exitCode;

  /// Whether the process executed successfully (exit code 0).
  bool get isSuccess => exitCode == 0;

  const ProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessResult &&
          runtimeType == other.runtimeType &&
          stdout == other.stdout &&
          stderr == other.stderr &&
          exitCode == other.exitCode;

  @override
  int get hashCode => Object.hash(stdout, stderr, exitCode);

  @override
  String toString() =>
      'ProcessResult(exitCode: $exitCode, isSuccess: $isSuccess, '
      'stdout: ${stdout.length} chars, stderr: ${stderr.length} chars)';
}

/// Executes external processes for the Otzaria search engine.
///
/// Handles process spawning, parameter building, and output capture
/// with UTF-8 encoding for Hebrew text support.
class ProcessExecutor {
  /// Builds command-line arguments for a search operation.
  ///
  /// Constructs arguments in the format:
  /// ["search", query, "--index", indexPath, "--limit", limit]
  /// with optional "--category" and "--book" parameters.
  ///
  /// Parameters:
  /// - [query]: The search query text
  /// - [indexPath]: Path to the search index directory
  /// - [limit]: Maximum number of results to return
  /// - [category]: Optional category filter
  /// - [book]: Optional book filter
  /// - [wildcard]: Enables wildcard query syntax (* and ?)
  List<String> buildSearchArguments({
    required String query,
    required String indexPath,
    required int limit,
    String? category,
    String? book,
    bool wildcard = false,
  }) {
    final arguments = <String>[
      'search',
      query,
      '--index',
      indexPath,
      '--limit',
      limit.toString(),
    ];

    if (category != null) {
      arguments.addAll(['--category', category]);
    }

    if (book != null) {
      arguments.addAll(['--book', book]);
    }

    if (wildcard) {
      arguments.add('--wildcard');
    }

    return arguments;
  }

  /// Gets the platform-specific executable name.
  ///
  /// Adds ".exe" extension on Windows, returns base name on other platforms.
  ///
  /// Parameters:
  /// - [baseName]: The base executable name (e.g., "OtzariaSearch")
  ///
  /// Returns: The platform-specific executable name
  String getPlatformExecutableName(String baseName) {
    if (Platform.isWindows) {
      return '$baseName.exe';
    }
    return baseName;
  }

  /// Executes a process with the given executable path and arguments.
  ///
  /// Spawns a process with UTF-8 encoding for Hebrew text support,
  /// captures stdout and stderr, and returns the result.
  ///
  /// Parameters:
  /// - [executablePath]: Path to the executable file
  /// - [arguments]: List of command-line arguments
  ///
  /// Returns: A [ProcessResult] containing the output and exit code
  ///
  /// Throws: [ProcessException] if the process cannot be started
  Future<ProcessResult> execute({
    required String executablePath,
    required List<String> arguments,
  }) async {
    try {
      final process = await Process.start(executablePath, arguments);

      // Capture stdout with UTF-8 decoding
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();

      // Capture stderr with UTF-8 decoding
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      // Wait for process to complete and get all outputs
      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      return ProcessResult(stdout: stdout, stderr: stderr, exitCode: exitCode);
    } on ProcessException catch (e) {
      // Return a failed result with error details
      return ProcessResult(
        stdout: '',
        stderr: 'Failed to start process: ${e.message}',
        exitCode: -1,
      );
    }
  }
}
