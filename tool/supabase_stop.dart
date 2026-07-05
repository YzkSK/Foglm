import 'dart:io';

import 'src/supabase_stop_runner.dart';

Future<void> main() async {
  final outcome = await runSupabaseStop();

  outcome.messages.forEach(stdout.writeln);
  outcome.errors.forEach(stderr.writeln);

  if (outcome.exitCode != 0) {
    exit(outcome.exitCode);
  }
}
