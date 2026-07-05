import 'process_runner.dart';

class SupabaseStopOutcome {
  SupabaseStopOutcome({
    required this.exitCode,
    required this.messages,
    required this.errors,
  });

  final int exitCode;
  final List<String> messages;
  final List<String> errors;
}

/// Stops the local Supabase environment. Mirrors the previous
/// `scripts/supabase-stop.sh`.
Future<SupabaseStopOutcome> runSupabaseStop({
  ProcessRunner processRunner = defaultProcessRunner,
}) async {
  final messages = ['Stopping local Supabase environment...'];
  final stop = await processRunner('npx', ['supabase', 'stop']);
  if (stop.stdout.toString().isNotEmpty) {
    messages.add(stop.stdout.toString());
  }
  final errors = <String>[
    if (stop.exitCode != 0) stop.stderr.toString(),
  ];

  return SupabaseStopOutcome(
    exitCode: stop.exitCode,
    messages: messages,
    errors: errors,
  );
}
