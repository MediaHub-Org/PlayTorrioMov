// Which gist a device uses for the profile. The lookup is by description, so a
// new device finds the profile without any id being configured.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/gist_sync.dart';

void main() {
  test('picks the profile gist among other gists', () {
    final gists = [
      {'id': 'aaa', 'description': 'Some other gist'},
      {'id': 'bbb', 'description': GistSync.description},
    ];

    expect(GistSync.pickGistId(gists), 'bbb');
  });

  test('takes the newest match when there are several, since GitHub lists newest first', () {
    final gists = [
      {'id': 'newest', 'description': GistSync.description},
      {'id': 'older', 'description': GistSync.description},
    ];

    expect(GistSync.pickGistId(gists), 'newest');
  });

  test('finds nothing when no gist carries the description', () {
    final gists = [
      {'id': 'aaa', 'description': 'PlayTorrio profile'},
      {'id': 'bbb'},
    ];

    expect(GistSync.pickGistId(gists), isNull);
    expect(GistSync.pickGistId([]), isNull);
  });

  test('ignores entries that are not gists', () {
    final gists = ['not a gist', 42, {'id': 'ccc', 'description': GistSync.description}];

    expect(GistSync.pickGistId(gists), 'ccc');
  });
}
