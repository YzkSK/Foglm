import 'dart:io';

/// Runs a process and waits for it to complete, capturing its output.
///
/// Injectable so callers can substitute a fake in tests without spawning
/// real subprocesses or relying on PATH-based stub executables.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

Future<ProcessResult> defaultProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  // runInShell is required on Windows, where commands such as `flutter` and
  // `npx` are `.bat`/`.cmd` wrappers that Process.run cannot resolve
  // directly from a bare executable name.
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
}

/// Returns whether [command] is available on PATH by probing
/// `command --version`. A thrown [ProcessException] (executable not found)
/// is treated as "not available".
Future<bool> isCommandAvailable(
  String command,
  ProcessRunner processRunner,
) async {
  try {
    final result = await processRunner(command, ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
