import 'dart:io';

/// Resolves the repository root: [envOverride] (used by tests) if set and
/// non-empty, otherwise the parent of the `tool/` directory containing the
/// running script.
Directory resolveRepoRoot(String envOverride) {
  final override = Platform.environment[envOverride];
  if (override != null && override.isNotEmpty) {
    return Directory(override);
  }
  final toolDir = File(Platform.script.toFilePath()).parent;
  return toolDir.parent;
}
