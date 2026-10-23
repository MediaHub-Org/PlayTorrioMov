// The profile sync's merge, key by key. Each case is one way the two devices
// and the cloud copy can disagree about a key since they last agreed.
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/backup/profile_merge.dart';

void main() {
  group('three-way merge', () {
    test('nothing changed on either side leaves the profile alone', () {
      final plan = ProfileMerge.merge(
        base: {'watchlist': '[1]'},
        local: {'watchlist': '[1]'},
        remote: {'watchlist': '[1]'},
      );

      expect(plan.merged, {'watchlist': '[1]'});
      expect(plan.conflicts, isEmpty);
    });

    test('a change made only here is kept and goes up', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]'},
        local: {'likes': '[1,2]'},
        remote: {'likes': '[1]'},
      );

      expect(plan.merged, {'likes': '[1,2]'});
      expect(plan.conflicts, isEmpty);
    });

    test('a change made only in the cloud is taken', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]'},
        local: {'likes': '[1]'},
        remote: {'likes': '[1,3]'},
      );

      expect(plan.merged, {'likes': '[1,3]'});
      expect(plan.conflicts, isEmpty);
    });

    test('changes on different keys on each side are both kept', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]', 'watchlist': '[9]'},
        local: {'likes': '[1,2]', 'watchlist': '[9]'},
        remote: {'likes': '[1]', 'watchlist': '[9,8]'},
      );

      expect(plan.merged, {'likes': '[1,2]', 'watchlist': '[9,8]'});
      expect(plan.conflicts, isEmpty);
    });

    test('the same key changed to the same value on both sides is no conflict', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]'},
        local: {'likes': '[1,2]'},
        remote: {'likes': '[1,2]'},
      );

      expect(plan.merged, {'likes': '[1,2]'});
      expect(plan.conflicts, isEmpty);
    });

    test('the same key changed differently on both sides is a conflict, and the cloud copy wins', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]'},
        local: {'likes': '[1,2]'},
        remote: {'likes': '[1,3]'},
      );

      expect(plan.merged, {'likes': '[1,3]'});
      expect(plan.conflicts, ['likes']);
    });

    test('a key removed here and untouched in the cloud is removed', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]', 'theme': 'dark'},
        local: {'theme': 'dark'},
        remote: {'likes': '[1]', 'theme': 'dark'},
      );

      expect(plan.merged, {'theme': 'dark'});
      expect(plan.conflicts, isEmpty);
    });

    test('a key removed in the cloud and untouched here is removed here', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]', 'theme': 'dark'},
        local: {'likes': '[1]', 'theme': 'dark'},
        remote: {'theme': 'dark'},
      );

      expect(plan.merged, {'theme': 'dark'});
      expect(plan.conflicts, isEmpty);
    });

    test('a key removed here while the cloud changed it is a conflict, and the cloud copy stays', () {
      final plan = ProfileMerge.merge(
        base: {'likes': '[1]'},
        local: {},
        remote: {'likes': '[1,4]'},
      );

      expect(plan.merged, {'likes': '[1,4]'});
      expect(plan.conflicts, ['likes']);
    });

    test('the first sync from a device with its own data keeps both sides', () {
      final plan = ProfileMerge.merge(
        base: {},
        local: {'likes': '[1]'},
        remote: {'watchlist': '[7]'},
      );

      expect(plan.merged, {'likes': '[1]', 'watchlist': '[7]'});
      expect(plan.conflicts, isEmpty);
    });

    test('the first sync of a shared key with different values is a conflict', () {
      final plan = ProfileMerge.merge(
        base: {},
        local: {'likes': '[1]'},
        remote: {'likes': '[2]'},
      );

      expect(plan.merged, {'likes': '[2]'});
      expect(plan.conflicts, ['likes']);
    });

    test('a brand-new device with nothing takes the whole cloud copy', () {
      final plan = ProfileMerge.merge(
        base: {},
        local: {},
        remote: {'likes': '[1]', 'theme': 'dark'},
      );

      expect(plan.merged, {'likes': '[1]', 'theme': 'dark'});
      expect(plan.conflicts, isEmpty);
    });

    test('a value of another type than the base counts as a change', () {
      final plan = ProfileMerge.merge(
        base: {'count': 1},
        local: {'count': 1},
        remote: {'count': '1'},
      );

      expect(plan.merged, {'count': '1'});
    });
  });

  group('which keys are synced', () {
    test('the profile is synced', () {
      expect(ProfileMerge.isSynced('likes'), isTrue);
      expect(ProfileMerge.isSynced('watchlist'), isTrue);
      expect(ProfileMerge.isSynced('simkl_username'), isTrue);
    });

    test("a device's own bookkeeping is not", () {
      expect(ProfileMerge.isSynced('profile_sync_base'), isFalse);
      expect(ProfileMerge.isSynced('auto_backup_last_run_ms'), isFalse);
      expect(ProfileMerge.isSynced('auto_backup_enabled'), isFalse);
      expect(ProfileMerge.isSynced('dropbox_token_expiry_ms'), isFalse);
      expect(ProfileMerge.isSynced('trakt_token_expiry_ms'), isFalse);
      expect(ProfileMerge.isSynced('backup_passphrase'), isFalse);
    });
  });

  group('the stored form', () {
    test('encodes the same profile to the same text whatever the key order', () {
      final a = ProfileMerge.encodeData({'b': '2', 'a': '1'});
      final b = ProfileMerge.encodeData({'a': '1', 'b': '2'});

      expect(a, b);
    });

    test('keeps plain values and drops anything else', () {
      final data = ProfileMerge.decodeData({
        'text': 'x',
        'flag': true,
        'count': 3,
        'ratio': 0.5,
        'list': ['a', 'b'],
        'nested': {'no': 'way'},
        'mixed': ['a', 2],
      });

      expect(data, {
        'text': 'x',
        'flag': true,
        'count': 3,
        'ratio': 0.5,
        'list': ['a', 'b'],
      });
    });

    test('decodes nothing from something that is not a map', () {
      expect(ProfileMerge.decodeData(['not', 'a', 'map']), isEmpty);
      expect(ProfileMerge.decodeData(null), isEmpty);
    });
  });
}
