import 'dart:io';

import 'src/repo_root.dart';
import 'src/setup_runner.dart';

Future<void> main() async {
  final repoRoot = resolveRepoRoot('SETUP_REPO_ROOT');
  final outcome = await runSetup(repoRoot: repoRoot);

  outcome.messages.forEach(stdout.writeln);
  outcome.errors.forEach(stderr.writeln);

  if (outcome.exitCode != 0) {
    exit(outcome.exitCode);
  }
}
