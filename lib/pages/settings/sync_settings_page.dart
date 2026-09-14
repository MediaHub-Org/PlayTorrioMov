import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/trakt/trakt_constants.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/simkl/simkl_settings.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../services/tmdb/tmdb_service.dart';
import '../../services/tmdb/tmdb_settings.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';

/// Every third-party account or key the app talks to, in one place: Trakt,
/// Simkl, TMDB and Discord Rich Presence. Trakt/Simkl used to be the whole
/// page (two nearly identical cards -- status, connect/disconnect, one sync
/// action); TMDB and Discord joined from the old "General & Data" catch-all,
/// which had nothing left in it once they moved out.
class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connect',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SettingsScrollView(
        children: [
          const _TraktSyncCard(),
          const SizedBox(height: 16),
          const _SimklSyncCard(),
          const SizedBox(height: 16),
          const _TmdbConnectCard(),
          if (_isDesktop) ...[
            const SizedBox(height: 16),
            const _DiscordPresenceCard(),
          ],
        ],
      ),
    );
  }
}

/// Pure visual chrome shared by both providers below -- icon, name,
/// connected badge, connect/disconnect, the pairing-code prompt while
/// waiting on the provider's site, and (once connected) one sync button.
class _SyncCardChrome extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final bool isAuthed;
  final bool isLoading;
  final String? username;
  final bool pairing;
  final String? userCode;
  final String pairingHint;
  final String verifyUrlLabel;

  /// When set, this provider can't be connected right now -- shown as an
  /// info banner instead of a "Connect" button that would just fail (e.g.
  /// Trakt now gates new API-app registration behind Trakt VIP, so without
  /// one configured, tapping Connect always errors with no explanation).
  final String? unavailableNote;

  /// An action offered alongside [unavailableNote] -- for the case where
  /// the user can fix the unavailability themselves. Simkl's is "paste your
  /// own client ID"; Trakt has none, because only the developer can clear
  /// its blocker.
  final String? unavailableActionLabel;
  final VoidCallback? onUnavailableAction;

  /// The most recent auth outcome, shown under the card. Null hides it.
  final String? statusNote;

  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onCopyCode;
  final VoidCallback onOpenVerifyUrl;
  final VoidCallback onSyncNow;

  const _SyncCardChrome({
    required this.icon,
    required this.color,
    required this.name,
    required this.isAuthed,
    required this.isLoading,
    required this.username,
    required this.pairing,
    required this.userCode,
    required this.pairingHint,
    required this.verifyUrlLabel,
    this.unavailableNote,
    this.unavailableActionLabel,
    this.onUnavailableAction,
    this.statusNote,
    required this.onConnect,
    required this.onDisconnect,
    required this.onCopyCode,
    required this.onOpenVerifyUrl,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAuthed
              ? color.withValues(alpha: 0.35)
              : AppColors.inkAlpha(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isAuthed
                                    ? const Color(0xFF10B981)
                                    : AppColors.inkFaint)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAuthed ? 'CONNECTED' : 'DISCONNECTED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isAuthed
                                  ? const Color(0xFF10B981)
                                  : AppColors.inkSubtle,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isAuthed && username != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        username!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkAlpha(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAuthed) ...[
                IconButton(
                  tooltip: 'Sync now',
                  onPressed: onSyncNow,
                  icon: Icon(Icons.sync_rounded, color: color),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: BorderSide(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: onDisconnect,
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else if (unavailableNote == null && !pairing && !isLoading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: onConnect,
                  child: const Text(
                    'Connect',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (unavailableNote != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade300,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      unavailableNote!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade200,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Outside the note on purpose: once the user has supplied a
          // client ID the note is gone, but they still need a way back to
          // the field to change or clear it.
          if (onUnavailableAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onUnavailableAction,
                child: Text(
                  unavailableActionLabel ?? 'Fix this',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          // What the last auth attempt actually did. Connect used to fail
          // with one generic line whatever went wrong -- a missing client
          // ID, an ID the provider rejected, and a dead network all read
          // the same, though only two of those are the user's to fix.
          if (statusNote != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.inkAlpha(0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusNote!,
                    style: TextStyle(
                      color: AppColors.inkAlpha(0.55),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (pairing && userCode != null) ...[
            const SizedBox(height: 20),
            Divider(color: AppColors.inkAlpha(0.10)),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    pairingHint,
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onCopyCode,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userCode!,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.copy_rounded,
                            color: AppColors.inkMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inkAlpha(0.12),
                      foregroundColor: AppColors.ink,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onOpenVerifyUrl,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: Text(
                      verifyUrlLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for authorization...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkAlpha(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openBrowser(String url, String logTag) async {
  try {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('[$logTag] Browser launch error: $e');
    }
  }
}

Future<void> _syncNow(BuildContext context, String providerName) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Syncing with $providerName...')),
  );
  await Future.wait([
    MyListService.syncAll(),
    ContinueWatchingService.syncCloudSessions(),
  ]);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$providerName sync complete!')),
    );
  }
}

class _TraktSyncCard extends StatefulWidget {
  const _TraktSyncCard();

  @override
  State<_TraktSyncCard> createState() => _TraktSyncCardState();
}

class _TraktSyncCardState extends State<_TraktSyncCard> {
  bool _isAuthed = false;
  bool _isLoading = true;
  String? _username;
  bool _pairing = false;
  String? _userCode;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final authed = await TraktService.instance.isAuthenticated();
    final user = authed ? await TraktService.instance.getUsername() : null;
    if (mounted) {
      setState(() {
        _isAuthed = authed;
        _username = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _startPairing() async {
    setState(() {
      _pairing = true;
      _userCode = null;
    });

    final res = await TraktService.instance.requestDeviceCode();
    if (!mounted) return;
    if (res == null) {
      setState(() => _pairing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to request Trakt pairing code.')),
      );
      return;
    }

    final userCode = res['user_code'] as String? ?? '';
    final deviceCode = res['device_code'] as String? ?? '';
    final verifyUrl =
        res['verification_url'] as String? ?? 'https://trakt.tv/activate';
    final interval = (res['interval'] as int? ?? 5).clamp(2, 30);

    setState(() => _userCode = userCode);
    _openBrowser(verifyUrl, 'Trakt');

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: interval), (t) async {
      final status = await TraktService.instance.pollDeviceToken(deviceCode);
      if (status == null) {
        t.cancel();
        if (mounted) {
          setState(() {
            _pairing = false;
            _isAuthed = true;
          });
          _checkStatus();
          MyListService.syncAll();
          ContinueWatchingService.syncCloudSessions();
        }
      } else if (status == 'expired_token' || status == 'access_denied') {
        t.cancel();
        if (mounted) setState(() => _pairing = false);
      }
    });
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await TraktService.instance.logout();
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return _SyncCardChrome(
      icon: Icons.movie_filter_rounded,
      color: const Color(0xFFED1C24),
      name: 'Trakt.tv',
      isAuthed: _isAuthed,
      isLoading: _isLoading,
      username: _username,
      pairing: _pairing,
      userCode: _userCode,
      pairingHint: 'Enter this activation code at trakt.tv/activate:',
      verifyUrlLabel: 'Open trakt.tv/activate',
      // Trakt now gates creating a new API app behind a Trakt VIP
      // subscription for whoever registers it (this app's maintainer, not
      // each connecting user) -- confirmed via Trakt's own forums, this
      // isn't a bug on our end. Until that's set up, kTraktClientId stays
      // empty and Connect would just fail with no explanation, so this
      // shows why instead of a dead-end button.
      unavailableNote: kTraktClientId.isEmpty
          ? "Trakt sync isn't set up yet -- Trakt now requires a VIP "
                'subscription to register a new API app, which the '
                "developer hasn't done. Simkl sync below works without "
                'that.'
          : null,
      onConnect: _startPairing,
      onDisconnect: _logout,
      onCopyCode: () {
        Clipboard.setData(ClipboardData(text: _userCode!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code copied to clipboard!')),
        );
      },
      onOpenVerifyUrl: () => _openBrowser('https://trakt.tv/activate', 'Trakt'),
      onSyncNow: () => _syncNow(context, 'Trakt.tv'),
    );
  }
}

class _SimklSyncCard extends StatefulWidget {
  const _SimklSyncCard();

  @override
  State<_SimklSyncCard> createState() => _SimklSyncCardState();
}

class _SimklSyncCardState extends State<_SimklSyncCard> {
  bool _isAuthed = false;
  bool _isLoading = true;
  String? _username;
  bool _pairing = false;
  String? _userCode;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final authed = await SimklService.instance.isAuthenticated();
    final user = authed ? await SimklService.instance.getUsername() : null;
    if (mounted) {
      setState(() {
        _isAuthed = authed;
        _username = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _startPairing() async {
    setState(() {
      _pairing = true;
      _userCode = null;
    });

    final res = await SimklService.instance.requestPin();
    if (!mounted) return;
    if (res == null) {
      setState(() => _pairing = false);
      // The card's own status line carries the reason; the snackbar would
      // otherwise repeat a generic failure over the top of it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SimklSettings.lastStatus.value ??
                'Failed to request Simkl PIN code.',
          ),
        ),
      );
      return;
    }

    final userCode = res['user_code'] as String? ?? '';
    final verifyUrl = res['verification_url'] as String? ?? 'https://simkl.com/pin';
    final interval = (res['interval'] as int? ?? 5).clamp(2, 30);

    setState(() => _userCode = userCode);
    _openBrowser(verifyUrl, 'Simkl');

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: interval), (t) async {
      final status = await SimklService.instance.pollPin(userCode);
      if (status == null) {
        t.cancel();
        if (mounted) {
          setState(() {
            _pairing = false;
            _isAuthed = true;
          });
          _checkStatus();
          MyListService.syncAll();
          ContinueWatchingService.syncCloudSessions();
        }
      } else if (status == 'expired_token' || status == 'access_denied') {
        t.cancel();
        if (mounted) setState(() => _pairing = false);
      }
    });
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await SimklService.instance.logout();
    await _checkStatus();
  }

  Future<void> _showClientIdDialog() async {
    final controller = TextEditingController(
      text: SimklSettings.clientId.value ?? '',
    );

    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Simkl client ID',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Register an app at simkl.com/settings/developer (free, takes '
              'a minute) and paste its Client ID here. Any redirect URI will '
              'do -- this app signs in with a PIN code, not a redirect.',
              style: TextStyle(
                color: AppColors.inkAlpha(0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Client ID',
                hintStyle: TextStyle(
                  color: AppColors.inkAlpha(0.3),
                ),
                filled: true,
                fillColor: AppColors.bar,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ADFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (id == null) return;
    await SimklSettings.setClientId(id.isEmpty ? null : id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SimklSettings.clientId,
      builder: (context, _, __) => ValueListenableBuilder<String?>(
        valueListenable: SimklSettings.lastStatus,
        builder: (context, status, __) => _buildCard(status),
      ),
    );
  }

  Widget _buildCard(String? status) {
    return _SyncCardChrome(
      icon: Icons.tv_rounded,
      color: const Color(0xFF00ADFF),
      name: 'Simkl',
      isAuthed: _isAuthed,
      isLoading: _isLoading,
      username: _username,
      pairing: _pairing,
      userCode: _userCode,
      pairingHint: 'Enter this PIN code at simkl.com/pin:',
      verifyUrlLabel: 'Open simkl.com/pin',
      // Every published build ships an empty .env, so there is no Simkl
      // client ID in it and Connect could only ever fail. Unlike Trakt's
      // blocker, this one the user can clear themselves in a minute.
      unavailableNote: SimklSettings.needsUserClientId
          ? 'This build shipped without a Simkl client ID, so Connect has '
                'nothing to sign in with. Registering your own app at '
                'simkl.com/settings/developer is free and takes a minute.'
          : null,
      unavailableActionLabel: SimklSettings.clientId.value == null
          ? 'Add a client ID'
          : 'Change client ID',
      onUnavailableAction: _showClientIdDialog,
      statusNote: status,
      onConnect: _startPairing,
      onDisconnect: _logout,
      onCopyCode: () {
        Clipboard.setData(ClipboardData(text: _userCode!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN copied to clipboard!')),
        );
      },
      onOpenVerifyUrl: () => _openBrowser('https://simkl.com/pin', 'Simkl'),
      onSyncNow: () => _syncNow(context, 'Simkl'),
    );
  }
}

class _TmdbConnectCard extends StatelessWidget {
  const _TmdbConnectCard();

  Future<void> _showTmdbKeyDialog(BuildContext context) async {
    final controller = TextEditingController();

    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Connect TMDB',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste your TMDB API key (free — sign up at themoviedb.org, no billing required).',
              style: TextStyle(color: AppColors.inkAlpha(0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'API Key',
                hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
                filled: true,
                fillColor: AppColors.bar,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.inkAlpha(0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF01B4E4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await TmdbSettings.setApiKey(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: TmdbSettings.apiKey,
      builder: (context, apiKey, _) {
        // Three states, not two: no key at all, running on the key this
        // build ships with, or running on the user's own.
        final ownKey = apiKey != null;
        final bundled = TmdbSettings.bundledApiKey != null;
        final connected = ownKey || bundled;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected ? const Color(0xFF01B4E4).withValues(alpha: 0.3) : AppColors.inkAlpha(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF01B4E4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.theaters_rounded, color: Color(0xFF01B4E4)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TMDB Cast Photos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ownKey
                              ? 'Connected with your own key — cast photos and character names load when available.'
                              : bundled
                              ? 'Using this build\'s included key — cast photos and character names load when available. Add your own if you would rather not share it.'
                              : 'Add your own free TMDB API key to fill in cast photos and character names most addons don\'t provide.',
                          style: TextStyle(color: AppColors.inkSubtle, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  // Only the user's own key is theirs to disconnect; the
                  // built-in one is part of the build.
                  if (ownKey)
                    TextButton(
                      onPressed: () => TmdbSettings.setApiKey(null),
                      child: Text(
                        'Disconnect',
                        style: TextStyle(color: AppColors.inkAlpha(0.5), fontSize: 13),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showTmdbKeyDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01B4E4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        bundled ? 'Use my key' : 'Connect',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              // What the last TMDB request actually did. A key that is
              // present but rejected looks exactly like a working one from
              // this card otherwise -- same "Connected" copy, same colour --
              // while every details page quietly shows bare actor names.
              ValueListenableBuilder<String?>(
                valueListenable: TmdbService.lastStatus,
                builder: (context, status, _) {
                  if (status == null) return const SizedBox.shrink();
                  final bad =
                      status.contains('rejected') ||
                      status.contains('Could not reach') ||
                      status.contains('rate-limited');
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          bad
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 15,
                          color: bad
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: bad
                                  ? const Color(0xFFEF4444)
                                  : AppColors.inkSubtle,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiscordPresenceCard extends StatelessWidget {
  const _DiscordPresenceCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DiscordRpcService.instance.isEnabled,
      builder: (context, isEnabled, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFF5865F2).withValues(alpha: 0.3)
                  : AppColors.inkAlpha(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF5865F2),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Discord Rich Presence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeColor: const Color(0xFF5865F2),
                onChanged: (val) => DiscordRpcService.instance.setEnabled(val),
              ),
            ],
          ),
        );
      },
    );
  }
}
