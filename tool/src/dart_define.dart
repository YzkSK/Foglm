import 'dart:convert';
import 'dart:io';

/// Ensures [dartDefineFile] exists by copying [exampleFile] when missing.
/// Returns true if the file was created, false if it already existed.
bool ensureDartDefineFile({
  required File dartDefineFile,
  required File exampleFile,
}) {
  if (dartDefineFile.existsSync()) {
    return false;
  }
  exampleFile.copySync(dartDefineFile.path);
  return true;
}

/// Parses a `KEY="value"` (or `KEY=value`) line out of
/// `supabase status -o env` style output. Returns null if [key] is absent.
String? parseStatusValue(String statusOutput, String key) {
  final pattern = RegExp('^$key="?([^"]*)"?\$', multiLine: true);
  return pattern.firstMatch(statusOutput)?.group(1);
}

/// Updates [updates] keys in [dartDefineFile]'s JSON content in place,
/// preserving any other existing keys.
void updateDartDefineValues(File dartDefineFile, Map<String, String> updates) {
  final current =
      (jsonDecode(dartDefineFile.readAsStringSync()) as Map<String, dynamic>)
        ..addAll(updates);
  const encoder = JsonEncoder.withIndent('  ');
  dartDefineFile.writeAsStringSync('${encoder.convert(current)}\n');
}
