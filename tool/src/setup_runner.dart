import 'dart:io';

import 'dart_define.dart';
import 'process_runner.dart';

class SetupOutcome {
  SetupOutcome({
    required this.exitCode,
    required this.messages,
    required this.errors,
  });

  final int exitCode;
  final List<String> messages;
  final List<String> errors;
}

/// Installs Flutter dependencies and prepares `dart_define.json`.
///
/// Mirrors the previous `scripts/setup.sh`, but returns a result instead of
/// calling `exit()` so the logic can be exercised directly in tests.
Future<SetupOutcome> runSetup({
  required Directory repoRoot,
  ProcessRunner processRunner = defaultProcessRunner,
}) async {
  final messages = <String>[];
  final errors = <String>[];

  if (!await isCommandAvailable('flutter', processRunner)) {
    errors
      ..add(
        'Error: flutter command not found. '
        'Please install Flutter and try again.',
      )
      ..add('https://docs.flutter.dev/get-started/install');
    return SetupOutcome(exitCode: 1, messages: messages, errors: errors);
  }

  messages.add('Installing Flutter dependencies...');
  final pubGet = await processRunner(
    'flutter',
    ['pub', 'get'],
    workingDirectory: repoRoot.path,
  );
  if (pubGet.stdout.toString().isNotEmpty) {
    messages.add(pubGet.stdout.toString());
  }
  if (pubGet.exitCode != 0) {
    errors.add(pubGet.stderr.toString());
    return SetupOutcome(
      exitCode: pubGet.exitCode,
      messages: messages,
      errors: errors,
    );
  }

  final dartDefineFile = File('${repoRoot.path}/dart_define.json');
  final exampleFile = File('${repoRoot.path}/dart_define.example.json');
  final created = ensureDartDefineFile(
    dartDefineFile: dartDefineFile,
    exampleFile: exampleFile,
  );
  if (created) {
    messages
      ..add('Creating dart_define.json from dart_define.example.json...')
      ..add(
        'dart_define.json has been created. '
        'Fill in the actual values before running the app.',
      );
  } else {
    messages.add('dart_define.json already exists. Skipping.');
  }

  messages
    ..add('')
    ..add('Setup complete.');
  return SetupOutcome(exitCode: 0, messages: messages, errors: errors);
}
