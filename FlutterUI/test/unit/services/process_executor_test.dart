import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/services/process_executor.dart';

void main() {
  group('ProcessResult', () {
    test('isSuccess returns true when exit code is 0', () {
      final result = ProcessResult(stdout: 'output', stderr: '', exitCode: 0);

      expect(result.isSuccess, true);
    });

    test('isSuccess returns false when exit code is non-zero', () {
      final result = ProcessResult(stdout: '', stderr: 'error', exitCode: 1);

      expect(result.isSuccess, false);
    });

    test('equality works correctly', () {
      final result1 = ProcessResult(
        stdout: 'output',
        stderr: 'error',
        exitCode: 0,
      );
      final result2 = ProcessResult(
        stdout: 'output',
        stderr: 'error',
        exitCode: 0,
      );

      expect(result1, equals(result2));
    });
  });

  group('ProcessExecutor', () {
    late ProcessExecutor executor;

    setUp(() {
      executor = ProcessExecutor();
    });

    group('buildSearchArguments', () {
      test('builds arguments with required parameters only', () {
        final args = executor.buildSearchArguments(
          query: 'תורה',
          indexPath: './search_index',
          limit: 50,
        );

        expect(args, [
          'search',
          'תורה',
          '--index',
          './search_index',
          '--limit',
          '50',
        ]);
      });

      test('builds arguments with category filter', () {
        final args = executor.buildSearchArguments(
          query: 'משה',
          indexPath: './index',
          limit: 25,
          category: 'תנ״ך',
        );

        expect(args, contains('--category'));
        expect(args, contains('תנ״ך'));
        expect(args.indexOf('--category'), args.indexOf('תנ״ך') - 1);
      });

      test('builds arguments with book filter', () {
        final args = executor.buildSearchArguments(
          query: 'בראשית',
          indexPath: './index',
          limit: 100,
          book: 'בראשית',
        );

        expect(args, contains('--book'));
        expect(args, contains('בראשית'));
        expect(args.indexOf('--book'), args.lastIndexOf('בראשית') - 1);
      });

      test('builds arguments with both category and book filters', () {
        final args = executor.buildSearchArguments(
          query: 'test',
          indexPath: './index',
          limit: 10,
          category: 'תנ״ך',
          book: 'שמות',
        );

        expect(args, contains('--category'));
        expect(args, contains('תנ״ך'));
        expect(args, contains('--book'));
        expect(args, contains('שמות'));
      });

      test('handles Hebrew text in query', () {
        final args = executor.buildSearchArguments(
          query: 'ברוך השם',
          indexPath: './index',
          limit: 50,
        );

        expect(args[1], 'ברוך השם');
      });

      test('converts limit to string', () {
        final args = executor.buildSearchArguments(
          query: 'test',
          indexPath: './index',
          limit: 75,
        );

        expect(args, contains('75'));
        expect(args[args.indexOf('--limit') + 1], '75');
      });
    });

    group('getPlatformExecutableName', () {
      test('adds .exe extension on Windows', () {
        // This test will only pass on Windows
        if (Platform.isWindows) {
          final name = executor.getPlatformExecutableName('OtzariaSearch');
          expect(name, 'OtzariaSearch.exe');
        }
      });

      test('does not add extension on non-Windows platforms', () {
        // This test will only pass on non-Windows platforms
        if (!Platform.isWindows) {
          final name = executor.getPlatformExecutableName('OtzariaSearch');
          expect(name, 'OtzariaSearch');
        }
      });

      test('returns correct platform-specific name', () {
        final name = executor.getPlatformExecutableName('OtzariaSearch');
        if (Platform.isWindows) {
          expect(name, endsWith('.exe'));
        } else {
          expect(name, isNot(endsWith('.exe')));
        }
      });
    });

    group('execute', () {
      test('returns error result when executable does not exist', () async {
        final result = await executor.execute(
          executablePath: '/nonexistent/path/to/executable',
          arguments: ['search', 'test'],
        );

        expect(result.isSuccess, false);
        expect(result.exitCode, -1);
        expect(result.stderr, contains('Failed to start process'));
      });

      test('executes echo command successfully on Windows', () async {
        // Only run on Windows
        if (!Platform.isWindows) return;

        final result = await executor.execute(
          executablePath: 'cmd.exe',
          arguments: ['/c', 'echo', 'test'],
        );

        expect(result.isSuccess, true);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('test'));
      });

      test('executes echo command successfully on Unix', () async {
        // Only run on Unix-like systems
        if (Platform.isWindows) return;

        final result = await executor.execute(
          executablePath: '/bin/echo',
          arguments: ['test'],
        );

        expect(result.isSuccess, true);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('test'));
      });

      test('captures stderr on command failure', () async {
        final result = await executor.execute(
          executablePath: Platform.isWindows ? 'cmd.exe' : '/bin/sh',
          arguments: Platform.isWindows
              ? ['/c', 'exit', '1']
              : ['-c', 'exit 1'],
        );

        expect(result.isSuccess, false);
        expect(result.exitCode, 1);
      });

      test('handles Hebrew text in output', () async {
        // Skip this test on Windows as cmd.exe doesn't support UTF-8 output reliably
        if (Platform.isWindows) {
          // On Windows, just verify the command executes successfully
          final result = await executor.execute(
            executablePath: 'cmd.exe',
            arguments: ['/c', 'echo', 'test'],
          );

          expect(result.isSuccess, true);
          expect(result.stdout, isNotEmpty);
        } else {
          // On Unix systems, test Hebrew text support
          final result = await executor.execute(
            executablePath: '/bin/echo',
            arguments: ['שלום'],
          );

          expect(result.isSuccess, true);
          expect(result.stdout, contains('שלום'));
        }
      });
    });
  });
}
