import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/services/addon/addon_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first launch installs Cinemeta over the network. That call used to be
/// a single attempt whose failure was caught and discarded, after which
/// `_initialized` was set anyway — so a cold start that could not reach
/// Cinemeta left the session with no addons, and every catalog page showed
/// its error card until the app was restarted.
///
/// These pin the state machine around it. The network call itself is not
/// exercised (it needs the network, which CI does not have); what is pinned
/// is that a failed bootstrap stays retryable instead of latching, and that a
/// user who removed every addon is not treated as a fresh install and given
/// Cinemeta back on the next catalog read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AddonManager.instance.resetForTest();
    // Refuses instantly, so the failure path is deterministic. CI has a
    // working network, so asking for the real URL would exercise success.
    AddonManager.defaultAddonUrl = 'http://127.0.0.1:1';
  });

  tearDown(() {
    AddonManager.defaultAddonUrl = 'https://v3-cinemeta.strem.io';
    AddonManager.instance.resetForTest();
  });

  test('a stored empty list is a choice, not a fresh install', () async {
    // Removing every addon writes `[]`. Re-adding Cinemeta behind the user's
    // back on the next catalog read would be the app overruling them.
    SharedPreferences.setMockInitialValues({'installed_addons_v4': '[]'});
    await AddonManager.instance.initialize();

    expect(AddonManager.instance.addons, isEmpty);
    expect(
      AddonManager.instance.defaultsPendingForTest,
      isFalse,
      reason: 'nothing is owed: the empty set is what the user asked for',
    );
  });

  test('a fresh install that could not reach the network stays retryable',
      () async {
    // No stored key at all is the fresh-install case, pointed at an address
    // that refuses -- the same outcome as a cold start that cannot reach
    // Cinemeta.
    SharedPreferences.setMockInitialValues({});
    await AddonManager.instance.initialize();

    expect(
      AddonManager.instance.defaultsPendingForTest,
      isTrue,
      reason: 'the install did not happen, so it must remain owed',
    );
  });

  test('ensureReady is throttled so an offline read does not re-time-out',
      () async {
    SharedPreferences.setMockInitialValues({});
    await AddonManager.instance.initialize();
    final firstAttempt = AddonManager.instance.lastDefaultsAttemptForTest;
    expect(firstAttempt, isNotNull);

    // Immediately after, a catalog read must not start another fetch: the
    // user should reach the page's error card and its retry button rather
    // than sit through a fresh timeout per read.
    await AddonManager.instance.ensureReady();
    expect(AddonManager.instance.lastDefaultsAttemptForTest, firstAttempt);
  });
}
