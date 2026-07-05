import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/supabase_start_runner.dart';

const _statusOutput = '''
API_URL="http://127.0.0.1:54321"
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
ANON_KEY="test-local-anon-key"
''';

ProcessResult _ok({String stdout = ''}) => ProcessResult(0, 0, stdout, '');

void main() {
  late Directory repoRoot;

  setUp(() {
    repoRoot = Directory.systemTemp.createTempSync('supabase_start_test_');
    File('${repoRoot.path}/dart_define.example.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'SUPABASE_URL': 'https://xxxxxxxxxxxx.supabase.co',
        'SUPABASE_ANON_KEY': 'your-publishable-key-here',
      }),
    );
  });

  tearDown(() {
    repoRoot.deleteSync(recursive: true);
  });

  test('reports an error when docker is not available', () async {
    final outcome = await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        throw const ProcessException('docker', ['--version']);
      },
    );

    expect(outcome.exitCode, 1);
    expect(outcome.errors, contains(contains('Docker command not found')));
  });

  test('reports an error when the docker daemon is not running', () async {
    final outcome = await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('info')) {
          return ProcessResult(0, 1, '', '');
        }
        return _ok();
      },
    );

    expect(outcome.exitCode, 1);
    expect(outcome.errors, contains(contains('Docker is not running')));
  });

  test('starts supabase and applies migrations', () async {
    final calls = <String>[];
    await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        calls.add(arguments.join(' '));
        if (arguments.contains('status')) {
          return _ok(stdout: _statusOutput);
        }
        return _ok();
      },
    );

    expect(calls, contains('supabase start'));
    expect(calls, contains('supabase db reset'));
  });

  test('creates dart_define.json and fills local values', () async {
    final outcome = await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('status')) {
          return _ok(stdout: _statusOutput);
        }
        return _ok();
      },
    );

    expect(outcome.exitCode, 0);
    final dartDefineFile = File('${repoRoot.path}/dart_define.json');
    expect(dartDefineFile.existsSync(), isTrue);
    final content = dartDefineFile.readAsStringSync();
    expect(content, contains('"SUPABASE_URL": "http://127.0.0.1:54321"'));
    expect(content, contains('"SUPABASE_ANON_KEY": "test-local-anon-key"'));
  });

  test('updates an existing dart_define.json in place', () async {
    final dartDefineFile = File('${repoRoot.path}/dart_define.json')
      ..writeAsStringSync(
        jsonEncode({
          'SUPABASE_URL': 'http://127.0.0.1:11111',
          'SUPABASE_ANON_KEY': 'old-anon-key',
          'SOME_OTHER_KEY': 'unchanged-value',
        }),
      );

    final outcome = await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('status')) {
          return _ok(stdout: _statusOutput);
        }
        return _ok();
      },
    );

    expect(outcome.exitCode, 0);
    final content = dartDefineFile.readAsStringSync();
    expect(content, contains('"SUPABASE_URL": "http://127.0.0.1:54321"'));
    expect(content, contains('"SUPABASE_ANON_KEY": "test-local-anon-key"'));
    expect(content, contains('"SOME_OTHER_KEY": "unchanged-value"'));
  });

  test('does not update dart_define.json when status is unparseable', () async {
    final dartDefineFile = File('${repoRoot.path}/dart_define.json');

    final outcome = await runSupabaseStart(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('status')) {
          return _ok(stdout: 'unparseable status output');
        }
        return _ok();
      },
    );

    expect(outcome.exitCode, 1);
    expect(outcome.errors, contains(contains('failed to parse')));
    expect(
      dartDefineFile.readAsStringSync(),
      contains('"SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co"'),
    );
  });
}
