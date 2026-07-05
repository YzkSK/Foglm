import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/supabase_stop_runner.dart';

void main() {
  test('calls supabase stop', () async {
    List<String>? calledArguments;

    final outcome = await runSupabaseStop(
      processRunner: (executable, arguments, {workingDirectory}) async {
        calledArguments = arguments;
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(calledArguments, ['supabase', 'stop']);
    expect(outcome.exitCode, 0);
  });

  test('propagates a non-zero exit code', () async {
    final outcome = await runSupabaseStop(
      processRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 1, '', 'boom');
      },
    );

    expect(outcome.exitCode, 1);
    expect(outcome.errors, contains('boom'));
  });
}
