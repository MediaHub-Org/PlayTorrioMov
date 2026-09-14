// test/services/http_timeouts_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `package:http` call with no `.timeout(...)` waits on the socket for as
/// long as the OS lets it -- minutes, on a server that accepts the connection
/// and then says nothing. That is not theoretical here: a debrid provider or
/// a metadata addon that goes quiet used to hang the future that a page was
/// `await`ing, so the spinner stayed up with no error and no way back.
///
/// `dart:io`'s `HttpClient` has `connectionTimeout`, and every construction of
/// one in this app sets it. `package:http` has no equivalent -- the deadline
/// has to be attached per call -- which is why this is a test and not a
/// convention.
void main() {
  // `http.get(...)`, `_client.post(...)` and friends. Deliberately matches on
  // the receiver name rather than the import, because that is what the call
  // sites actually look like and a renamed import would be caught by the
  // receivers list going stale rather than by the rule silently passing.
  final call = RegExp(
    r'\b(?:http|_client|client|httpClient)\.'
    r'(?:get|post|put|delete|head|send|read)\s*\(',
  );

  test('every package:http call carries a timeout', () {
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();

      for (final match in call.allMatches(source)) {
        // Walk to the call's own closing paren so the check reads what comes
        // *after* the argument list, not whatever happens to be 120 characters
        // along -- argument lists here run to dozens of lines of headers.
        var i = match.end - 1;
        var depth = 0;
        while (i < source.length) {
          final c = source[i];
          if (c == '(') {
            depth++;
          } else if (c == ')') {
            depth--;
            if (depth == 0) break;
          }
          i++;
        }

        if (i >= source.length) continue; // unbalanced; nothing to read

        // Then read to the end of the statement, so a `.timeout` belonging
        // to the *next* call cannot be mistaken for this one's.
        var j = i + 1;
        while (j < source.length && source[j] != ';') {
          j++;
        }
        if (source.substring(i + 1, j).contains('.timeout(')) continue;

        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'attach .timeout(const Duration(seconds: N)) -- a hung socket '
          'otherwise hangs whatever is awaiting it',
    );
  });
}
