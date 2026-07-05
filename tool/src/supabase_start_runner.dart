import 'dart:io';

import 'dart_define.dart';
import 'process_runner.dart';

class SupabaseStartOutcome {
  SupabaseStartOutcome({
    required this.exitCode,
    required this.messages,
    required this.errors,
  });

  final int exitCode;
  final List<String> messages;
  final List<String> errors;
}

/// Starts the local Supabase environment, applies migrations, and syncs
/// `dart_define.json` with the local API URL/anon key.
///
/// Mirrors the previous `scripts/supabase-start.sh`, but returns a result
/// instead of calling `exit()` so the logic can be exercised in tests.
Future<SupabaseStartOutcome> runSupabaseStart({
  required Directory repoRoot,
  ProcessRunner processRunner = defaultProcessRunner,
}) async {
  final messages = <String>[];
  final errors = <String>[];

  if (!await isCommandAvailable('docker', processRunner)) {
    errors.add(
      'Error: Docker command not found. '
      'Please install Docker Desktop and try again.',
    );
    return SupabaseStartOutcome(
      exitCode: 1,
      messages: messages,
      errors: errors,
    );
  }

  final dockerInfo = await processRunner('docker', ['info']);
  if (dockerInfo.exitCode != 0) {
    errors.add(
      'Error: Docker is not running. '
      'Please start Docker Desktop and try again.',
    );
    return SupabaseStartOutcome(
      exitCode: 1,
      messages: messages,
      errors: errors,
    );
  }

  messages.add(
    'Starting local Supabase environment (this may take a while on first '
    'run)...',
  );
  final start = await processRunner('npx', ['supabase', 'start']);
  if (start.stdout.toString().isNotEmpty) {
    messages.add(start.stdout.toString());
  }
  if (start.exitCode != 0) {
    errors.add(start.stderr.toString());
    return SupabaseStartOutcome(
      exitCode: start.exitCode,
      messages: messages,
      errors: errors,
    );
  }

  messages.add('Applying migrations...');
  final reset = await processRunner('npx', ['supabase', 'db', 'reset']);
  if (reset.stdout.toString().isNotEmpty) {
    messages.add(reset.stdout.toString());
  }
  if (reset.exitCode != 0) {
    errors.add(reset.stderr.toString());
    return SupabaseStartOutcome(
      exitCode: reset.exitCode,
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
    messages.add('Creating dart_define.json from dart_define.example.json...');
  }

  final status = await processRunner('npx', [
    'supabase',
    'status',
    '-o',
    'env',
  ]);
  final statusOutput = status.stdout.toString();
  final apiUrl = parseStatusValue(statusOutput, 'API_URL');
  final anonKey = parseStatusValue(statusOutput, 'ANON_KEY');

  if (apiUrl == null || apiUrl.isEmpty || anonKey == null || anonKey.isEmpty) {
    errors.add(
      "Error: failed to parse 'supabase status' output. "
      'dart_define.json was not updated.',
    );
    return SupabaseStartOutcome(
      exitCode: 1,
      messages: messages,
      errors: errors,
    );
  }

  updateDartDefineValues(dartDefineFile, {
    'SUPABASE_URL': apiUrl,
    'SUPABASE_ANON_KEY': anonKey,
  });

  messages
    ..add('')
    ..add('Local Supabase environment is ready.')
    ..add('  API URL: $apiUrl')
    ..add('dart_define.json has been updated with the local anon key.');

  return SupabaseStartOutcome(exitCode: 0, messages: messages, errors: errors);
}
