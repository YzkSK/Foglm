import 'dart:io';

import 'src/repo_root.dart';
import 'src/supabase_start_runner.dart';

Future<void> main() async {
  final repoRoot = resolveRepoRoot('SUPABASE_START_REPO_ROOT');
  final outcome = await runSupabaseStart(repoRoot: repoRoot);

  outcome.messages.forEach(stdout.writeln);
  outcome.errors.forEach(stderr.writeln);

  if (outcome.exitCode != 0) {
    exit(outcome.exitCode);
  }
}
