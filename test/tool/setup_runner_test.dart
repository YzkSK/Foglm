import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/setup_runner.dart';

void main() {
  late Directory repoRoot;

  setUp(() {
    repoRoot = Directory.systemTemp.createTempSync('setup_runner_test_');
    File(
      '${repoRoot.path}/dart_define.example.json',
    ).writeAsStringSync(
      jsonEncode({
        'SUPABASE_URL': 'https://xxxxxxxxxxxx.supabase.co',
        'SUPABASE_ANON_KEY': 'your-publishable-key-here',
      }),
    );
  });

  tearDown(() {
    repoRoot.deleteSync(recursive: true);
  });

  test('reports an error when flutter is not available', () async {
    final outcome = await runSetup(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        throw const ProcessException('flutter', ['--version']);
      },
    );

    expect(outcome.exitCode, 1);
    expect(
      outcome.errors,
      contains(contains('flutter command not found')),
    );
  });

  test('propagates a non-zero exit code from flutter pub get', () async {
    final outcome = await runSetup(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('pub')) {
          return ProcessResult(0, 1, '', 'pub get failed');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(outcome.exitCode, 1);
    expect(outcome.errors, contains('pub get failed'));
  });

  test('creates dart_define.json from the example when missing', () async {
    final outcome = await runSetup(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(outcome.exitCode, 0);
    final dartDefineFile = File('${repoRoot.path}/dart_define.json');
    expect(dartDefineFile.existsSync(), isTrue);
    expect(
      outcome.messages,
      contains(contains('Creating dart_define.json')),
    );
  });

  test('does not overwrite an existing dart_define.json', () async {
    final dartDefineFile = File('${repoRoot.path}/dart_define.json')
      ..writeAsStringSync(jsonEncode({'SUPABASE_ANON_KEY': 'existing-key'}));

    final outcome = await runSetup(
      repoRoot: repoRoot,
      processRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(outcome.exitCode, 0);
    expect(dartDefineFile.readAsStringSync(), contains('existing-key'));
    expect(
      outcome.messages,
      contains(contains('dart_define.json already exists')),
    );
  });
}
