import '../../widgets/common/focus_fill.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/l10n.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/trakt/trakt_settings.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/simkl/simkl_settings.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/tmdb/tmdb_service.dart';
import '../../services/tmdb/tmdb_settings.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

/// Shows the Trakt card at all. Off by a product decision, not a technical
/// one: Trakt now gates registering a *new* API app behind a paid VIP
/// subscription (see `TraktSettings`'s own doc comment, and
/// docs/SYNC_AND_BACKUP.md), which makes it impractical to offer as the
/// default sync option -- Simkl needs nothing but a free client ID. The
/// card, `TraktService`, `TraktSettings` and the pasted-credentials path are
/// all left in place rather than deleted: flipping this back to `true` is
/// the whole reopening, for whoever ends up with a working Trakt app
/// (VIP-registered, or one that predates the gate) and wants it back.
const bool _traktSyncEnabled = false;

/// Every third-party account or key the app talks to, in one place: Trakt
/// (disabled, see [_traktSyncEnabled]), Simkl and TMDB. Trakt/Simkl used to
/// be the whole page (two nearly identical cards -- status,
/// connect/disconnect, one sync action); TMDB joined from the old "General
/// & Data" catch-all, which had nothing left in it once it moved out.
class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.settingsCategoryConnect,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.titleSm),
        ),
      ),
      body: SettingsScrollView(
        children: [
          if (_traktSyncEnabled) ...[
            const _TraktSyncCard(),
            SizedBox(height: context.rem(AppRem.md)),
          ],
          const _SimklSyncCard(),
          SizedBox(height: context.rem(AppRem.md)),
          const _TmdbConnectCard(),
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

  /// A second action beside [onUnavailableAction] -- Simkl's is "open the
  /// developer page", the first step of getting a client ID.
  final String? unavailableSecondaryLabel;
  final VoidCallback? onUnavailableSecondary;

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
    this.unavailableSecondaryLabel,
    this.onUnavailableSecondary,
    this.statusNote,
    required this.onConnect,
    required this.onDisconnect,
    required this.onCopyCode,
    required this.onOpenVerifyUrl,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(context.rem(1.25)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
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
                width: context.rem(2.75),
                height: context.rem(2.75),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                ),
                child: Icon(icon, color: color, size: context.rem(AppRem.iconLg)),
              ),
              SizedBox(width: context.rem(0.875)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A Wrap, not a Row: at 3x the provider name and the
                    // CONNECTED/DISCONNECTED badge together are wider than
                    // the space the buttons leave, and the badge is the part
                    // that can move to a second line.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.rem(AppRem.sm),
                      runSpacing: context.rem(AppRem.xs),
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: AppType.bodyLg,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rem(AppRem.sm),
                            vertical: context.rem(AppRem.xxs),
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isAuthed
                                        ? const Color(0xFF10B981)
                                        : AppColors.inkFaint)
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                          ),
                          child: Text(
                            isAuthed
                                ? l10n.syncConnected
                                : l10n.syncDisconnected,
                            style: TextStyle(
                              fontSize: TvType.scale(AppType.micro),
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
                      SizedBox(height: context.rem(AppRem.xs)),
                      Text(
                        username!,
                        style: TextStyle(
                          fontSize: AppType.small,
                          color: AppColors.inkAlpha(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAuthed) ...[
                IconButton(
                  tooltip: l10n.syncNowTooltip,
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
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(0.875),
                      vertical: context.rem(0.625),
                    ),
                  ),
                  onPressed: onDisconnect,
                  child: Text(
                    l10n.syncDisconnect,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ] else if (unavailableNote == null && !pairing && !isLoading)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(AppRem.md),
                      vertical: context.rem(0.625),
                    ),
                  ),
                  onPressed: onConnect,
                  child: Text(
                    l10n.syncConnect,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (unavailableNote != null) ...[
            SizedBox(height: context.rem(AppRem.md)),
            Container(
              padding: EdgeInsets.all(context.rem(AppRem.ms)),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade300,
                    size: context.rem(AppRem.icon),
                  ),
                  SizedBox(width: context.rem(AppRem.ms)),
                  Expanded(
                    child: Text(
                      unavailableNote!,
                      style: TextStyle(
                        fontSize: AppType.caption,
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
            SizedBox(height: context.rem(0.625)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              // Wrap: two labels in a translated language do not share a
              // phone-width row, and a Row would run off the card.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: context.rem(AppRem.xs),
                children: [
                  if (onUnavailableSecondary != null)
                    TextButton(
                      onPressed: onUnavailableSecondary,
                      child: Text(
                        unavailableSecondaryLabel ?? '',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: AppType.small,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: onUnavailableAction,
                    child: Text(
                      unavailableActionLabel ?? l10n.syncFixThis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: AppType.small,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // What the last auth attempt actually did. Connect used to fail
          // with one generic line whatever went wrong -- a missing client
          // ID, an ID the provider rejected, and a dead network all read
          // the same, though only two of those are the user's to fix.
          if (statusNote != null) ...[
            SizedBox(height: context.rem(AppRem.ms)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: context.rem(0.9375),
                  color: AppColors.inkAlpha(0.4),
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                Expanded(
                  child: Text(
                    statusNote!,
                    style: TextStyle(
                      color: AppColors.inkAlpha(0.55),
                      fontSize: AppType.caption,
                      height: 1.35, // ratio: a line height, not a size
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (pairing && userCode != null) ...[
            SizedBox(height: context.rem(1.25)),
            Divider(color: AppColors.inkAlpha(0.10)),
            SizedBox(height: context.rem(AppRem.md)),
            Center(
              child: Column(
                children: [
                  Text(
                    pairingHint,
                    style: TextStyle(fontSize: AppType.small, color: AppColors.inkMuted),
                  ),
                  SizedBox(height: context.rem(AppRem.ms)),
                  FocusFill(
                    radius: context.rem(AppRem.radiusMd),
                    child: InkWell(
                      onTap: onCopyCode,
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.lg),
                          vertical: context.rem(0.875),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userCode!,
                              style: TextStyle(
                                fontSize: AppType.heading,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(width: context.rem(AppRem.ms)),
                            Icon(
                              Icons.copy_rounded,
                              color: AppColors.inkMuted,
                              size: context.rem(AppRem.icon),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rem(0.875)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.inkAlpha(0.12),
                      foregroundColor: AppColors.ink,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rem(AppRem.md),
                        vertical: context.rem(AppRem.sm),
                      ),
                    ),
                    onPressed: onOpenVerifyUrl,
                    icon: Icon(Icons.open_in_browser_rounded, size: context.rem(AppRem.iconXs)),
                    label: Text(
                      verifyUrlLabel,
                      style: const TextStyle(
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: context.rem(0.875)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: context.rem(AppRem.md),
                        height: context.rem(AppRem.md),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                      SizedBox(width: context.rem(0.625)),
                      Text(
                        l10n.syncWaiting,
                        style: TextStyle(
                          fontSize: AppType.caption,
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
  final l10n = context.l10n;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.syncInProgress(providerName))));
  await Future.wait([
    MyListService.syncAll(),
    ContinueWatchingService.syncCloudSessions(),
  ]);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.syncComplete(providerName))));
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
      // The card's own status line carries the reason; the snackbar would
      // otherwise repeat a generic failure over the top of it.
      TraktSettings.note(context.l10n.syncTraktFailedCode);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.syncTraktFailedCode)));
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

  Future<void> _showCredentialsDialog() async {
    final l10n = context.l10n;
    final idController = TextEditingController(
      text: TraktSettings.clientId.value ?? '',
    );
    final secretController = TextEditingController(
      text: TraktSettings.clientSecret.value ?? '',
    );

    Future<void> pasteInto(TextEditingController controller) async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final pasted = data?.text?.trim();
      if (pasted == null || pasted.isEmpty) return;
      controller.text = pasted;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Empty is allowed, but only both at once: it clears saved
          // credentials. Anything else has to look like a credential on
          // both sides, so a half-pasted pair is caught here and not as a
          // 401 later.
          final id = idController.text.trim();
          final secret = secretController.text.trim();
          final bothEmpty = id.isEmpty && secret.isEmpty;
          final bothValid =
              TraktSettings.looksLikeCredential(id) &&
              TraktSettings.looksLikeCredential(secret);
          final isValid = bothEmpty || bothValid;
          InputDecoration field({
            required String hint,
            required TextEditingController controller,
          }) => InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
            errorText: isValid ? null : l10n.syncTraktCredentialsInvalid,
            errorMaxLines: 3,
            filled: true,
            fillColor: AppColors.bar,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              tooltip: l10n.syncSimklPaste,
              icon: Icon(Icons.content_paste_rounded, size: context.rem(AppRem.iconSm)),
              onPressed: () async {
                await pasteInto(controller);
                setDialogState(() {});
              },
            ),
          );
          return AlertDialog(
            backgroundColor: AppColors.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            ),
            title: Text(
              l10n.syncTraktCredentialsTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syncTraktCredentialsBody,
                  style: TextStyle(
                    color: AppColors.inkAlpha(0.7),
                    fontSize: AppType.small,
                    height: 1.4, // ratio: a line height, not a size
                  ),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _openBrowser(
                      'https://trakt.tv/oauth/applications',
                      'Trakt',
                    ),
                    icon: Icon(Icons.open_in_new_rounded, size: context.rem(AppRem.iconXs)),
                    label: Text(l10n.syncTraktOpenAppsPage),
                  ),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                TextField(
                  controller: idController,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
                  decoration: field(
                    hint: l10n.syncClientIdHint,
                    controller: idController,
                  ),
                ),
                SizedBox(height: context.rem(AppRem.xs)),
                TextField(
                  controller: secretController,
                  onChanged: (_) => setDialogState(() {}),
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
                  decoration: field(
                    hint: l10n.syncTraktClientSecretHint,
                    controller: secretController,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.syncCancel,
                  style: TextStyle(color: AppColors.inkAlpha(0.6)),
                ),
              ),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED1C24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                  ),
                ),
                child: Text(
                  l10n.syncSave,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;
    final id = idController.text.trim();
    final secret = secretController.text.trim();
    await TraktSettings.setClientId(id.isEmpty ? null : id);
    await TraktSettings.setClientSecret(secret.isEmpty ? null : secret);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return ValueListenableBuilder<String?>(
      valueListenable: TraktSettings.clientId,
      builder: (context, _, __) => ValueListenableBuilder<String?>(
        valueListenable: TraktSettings.clientSecret,
        builder: (context, _, __) => ValueListenableBuilder<String?>(
          valueListenable: TraktSettings.lastStatus,
          builder: (context, status, __) => _buildCard(status),
        ),
      ),
    );
  }

  Widget _buildCard(String? status) {
    final l10n = context.l10n;
    return _SyncCardChrome(
      icon: Icons.movie_filter_rounded,
      color: const Color(0xFFED1C24),
      name: 'Trakt.tv',
      isAuthed: _isAuthed,
      isLoading: _isLoading,
      username: _username,
      pairing: _pairing,
      userCode: _userCode,
      pairingHint: l10n.syncTraktPairingHint,
      verifyUrlLabel: l10n.syncTraktOpenVerify,
      // Every published build ships an empty .env, and unlike Simkl a Trakt
      // user cannot always register their way out: new API apps need VIP.
      // An app from before that gate still works, and anyone holding
      // working credentials can paste them in below -- no rebuild needed.
      unavailableNote: TraktSettings.needsUserCredentials
          ? l10n.syncTraktUnavailable
          : null,
      unavailableActionLabel: TraktSettings.clientId.value == null
          ? l10n.syncTraktAddCredentials
          : l10n.syncTraktChangeCredentials,
      onUnavailableAction: _showCredentialsDialog,
      unavailableSecondaryLabel: l10n.syncTraktOpenAppsPage,
      onUnavailableSecondary: () =>
          _openBrowser('https://trakt.tv/oauth/applications', 'Trakt'),
      statusNote: status,
      onConnect: _startPairing,
      onDisconnect: _logout,
      onCopyCode: () {
        Clipboard.setData(ClipboardData(text: _userCode!));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncCodeCopied)));
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
            SimklSettings.lastStatus.value ?? context.l10n.syncSimklFailedPin,
          ),
        ),
      );
      return;
    }

    final userCode = res['user_code'] as String? ?? '';
    final verifyUrl =
        res['verification_url'] as String? ?? 'https://simkl.com/pin';
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
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: SimklSettings.clientId.value ?? '',
    );

    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Empty is allowed: it clears a saved ID. Anything else has to look
          // like one, so a pasted URL is caught here and not as a 401 later.
          final text = controller.text.trim();
          final isValid = text.isEmpty || SimklSettings.looksLikeClientId(text);
          return AlertDialog(
            backgroundColor: AppColors.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            ),
            title: Text(
              l10n.syncSimklClientIdTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syncSimklClientIdBody,
                  style: TextStyle(
                    color: AppColors.inkAlpha(0.7),
                    fontSize: AppType.small,
                    height: 1.4, // ratio: a line height, not a size
                  ),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _openBrowser(
                      'https://simkl.com/settings/developer/',
                      'Simkl',
                    ),
                    icon: Icon(Icons.open_in_new_rounded, size: context.rem(AppRem.iconXs)),
                    label: Text(l10n.syncSimklOpenDeveloper),
                  ),
                ),
                SizedBox(height: context.rem(AppRem.snug)),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
                  decoration: InputDecoration(
                    hintText: l10n.syncClientIdHint,
                    hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
                    errorText: isValid ? null : l10n.syncSimklClientIdInvalid,
                    errorMaxLines: 3,
                    filled: true,
                    fillColor: AppColors.bar,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      tooltip: l10n.syncSimklPaste,
                      icon: Icon(Icons.content_paste_rounded, size: context.rem(AppRem.iconSm)),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        final pasted = data?.text?.trim();
                        if (pasted == null || pasted.isEmpty) return;
                        controller.text = pasted;
                        setDialogState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  l10n.syncCancel,
                  style: TextStyle(color: AppColors.inkAlpha(0.6)),
                ),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () => Navigator.pop(ctx, controller.text.trim())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                  ),
                ),
                child: Text(
                  l10n.syncSave,
                  style: const TextStyle(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (id == null) return;
    await SimklSettings.setClientId(id.isEmpty ? null : id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return ValueListenableBuilder<String?>(
      valueListenable: SimklSettings.clientId,
      builder: (context, _, __) => ValueListenableBuilder<String?>(
        valueListenable: SimklSettings.lastStatus,
        builder: (context, status, __) => _buildCard(status),
      ),
    );
  }

  Widget _buildCard(String? status) {
    final l10n = context.l10n;
    return _SyncCardChrome(
      icon: Icons.tv_rounded,
      color: const Color(0xFF00ADFF),
      name: 'Simkl',
      isAuthed: _isAuthed,
      isLoading: _isLoading,
      username: _username,
      pairing: _pairing,
      userCode: _userCode,
      pairingHint: l10n.syncSimklPairingHint,
      verifyUrlLabel: l10n.syncSimklOpenVerify,
      // Every published build ships an empty .env, so there is no Simkl
      // client ID in it and Connect could only ever fail. Unlike Trakt's
      // blocker, this one the user can clear themselves in a minute.
      unavailableNote: SimklSettings.needsUserClientId
          ? l10n.syncSimklUnavailable
          : null,
      unavailableActionLabel: SimklSettings.clientId.value == null
          ? l10n.syncSimklAddClientId
          : l10n.syncSimklChangeClientId,
      onUnavailableAction: _showClientIdDialog,
      unavailableSecondaryLabel: l10n.syncSimklOpenDeveloper,
      onUnavailableSecondary: () =>
          _openBrowser('https://simkl.com/settings/developer/', 'Simkl'),
      statusNote: status,
      onConnect: _startPairing,
      onDisconnect: _logout,
      onCopyCode: () {
        Clipboard.setData(ClipboardData(text: _userCode!));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.syncPinCopied)));
      },
      onOpenVerifyUrl: () => _openBrowser('https://simkl.com/pin', 'Simkl'),
      onSyncNow: () => _syncNow(context, 'Simkl'),
    );
  }
}

class _TmdbConnectCard extends StatelessWidget {
  const _TmdbConnectCard();

  Future<void> _showTmdbKeyDialog(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();

    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg))),
        title: Text(
          l10n.syncTmdbTitle,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.syncTmdbBody,
              style: TextStyle(color: AppColors.inkAlpha(0.7), fontSize: AppType.small),
            ),
            SizedBox(height: context.rem(0.875)),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: InputDecoration(
                hintText: l10n.syncTmdbKeyHint,
                hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
                filled: true,
                fillColor: AppColors.bar,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
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
              l10n.syncCancel,
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF01B4E4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
              ),
            ),
            child: Text(
              l10n.syncSave,
              style: const TextStyle(
                color: AppColors.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: TmdbSettings.apiKey,
      builder: (context, apiKey, _) {
        // Three states, not two: no key at all, running on the key this
        // build ships with, or running on the user's own.
        final ownKey = apiKey != null;
        final bundled = TmdbSettings.bundledApiKey != null;
        final connected = ownKey || bundled;
        return Container(
          padding: EdgeInsets.all(context.rem(AppRem.md)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            border: Border.all(
              color: connected
                  ? const Color(0xFF01B4E4).withValues(alpha: 0.3)
                  : AppColors.inkAlpha(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: context.rem(2.625),
                    height: context.rem(2.625),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01B4E4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                    child: const Icon(
                      Icons.theaters_rounded,
                      color: Color(0xFF01B4E4),
                    ),
                  ),
                  SizedBox(width: context.rem(0.875)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.syncTmdbCardTitle,
                          style: const TextStyle(
                            fontSize: AppType.bodyLg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xs)),
                        Text(
                          ownKey
                              ? l10n.syncTmdbOwnKey
                              : bundled
                              ? l10n.syncTmdbBundledKey
                              : l10n.syncTmdbNoKey,
                          style: TextStyle(
                            color: AppColors.inkSubtle,
                            fontSize: AppType.captionPlus,
                            height: 1.35, // ratio: a line height, not a size
                          ),
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
                        l10n.syncDisconnect,
                        style: TextStyle(
                          color: AppColors.inkAlpha(0.5),
                          fontSize: AppType.small,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showTmdbKeyDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01B4E4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rem(AppRem.md),
                          vertical: context.rem(0.625),
                        ),
                      ),
                      child: Text(
                        bundled ? l10n.syncTmdbUseMyKey : l10n.syncConnect,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppType.small,
                        ),
                      ),
                    ),
                ],
              ),
              // What the last TMDB request actually did. A key that is
              // present but rejected looks exactly like a working one from
              // this card otherwise -- same "Connected" copy, same color --
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
                    padding: EdgeInsets.only(top: context.rem(AppRem.ms)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          bad
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: context.rem(0.9375),
                          color: bad
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        SizedBox(width: context.rem(AppRem.sm)),
                        Expanded(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: bad
                                  ? const Color(0xFFEF4444)
                                  : AppColors.inkSubtle,
                              fontSize: AppType.caption,
                              height: 1.35, // ratio: a line height, not a size
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
