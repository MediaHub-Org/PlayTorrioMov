import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../services/backup/auto_backup_service.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/cloud_backup_settings.dart';
import '../../services/backup/dropbox_backup_service.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

/// Local export/import plus optional WebDAV cloud backup -- split out of the
/// old "General & Data" catch-all so it reads as its own category, matching
/// Keyboard Shortcuts getting the same treatment.
class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _isBackingUp = false;

  Future<void> _exportData(BuildContext context) async {
    setState(() => _isBackingUp = true);
    try {
      final path = await BackupService.exportToPickedFile();
      if (!context.mounted) return;
      // Null is the user closing the save dialog, which is not a failure
      // and should not claim a backup was written.
      if (path == null) {
        setState(() => _isBackingUp = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.backupSavedTo(path)),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupFailed('$e')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _importData(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg))),
        title: Text(l10n.backupRestoreConfirmTitle, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Text(
          l10n.backupRestoreConfirmBody,
          style: TextStyle(color: AppColors.inkAlpha(0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backupCancel, style: TextStyle(color: AppColors.inkAlpha(0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
            ),
            child: Text(l10n.backupRestore, style: const TextStyle(color: AppColors.onAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackingUp = true);
    try {
      final restored = await BackupService.importFromPickedFile();
      if (!context.mounted) return;
      if (restored == null) {
        setState(() => _isBackingUp = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.backupRestored(restored)),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupRestoreFailed('$e')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _showCloudConfigDialog() async {
    final l10n = context.l10n;
    final current = CloudBackupSettings.config.value;
    final urlController = TextEditingController(text: current?.url ?? '');
    final userController = TextEditingController(text: current?.username ?? '');
    final passController = TextEditingController(text: current?.password ?? '');

    final result = await showDialog<CloudBackupConfig>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg))),
        title: Text(l10n.backupWebdavTitle, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupWebdavBody,
              style: TextStyle(color: AppColors.inkAlpha(0.7), fontSize: AppType.small),
            ),
            SizedBox(height: context.rem(0.875)),
            TextField(
              controller: urlController,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: _cloudFieldDecoration(l10n.backupWebdavUrl),
            ),
            SizedBox(height: context.rem(0.625)),
            TextField(
              controller: userController,
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: _cloudFieldDecoration(l10n.backupWebdavUsername),
            ),
            SizedBox(height: context.rem(0.625)),
            TextField(
              controller: passController,
              obscureText: true,
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: _cloudFieldDecoration(l10n.backupWebdavPassword),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.backupCancel, style: TextStyle(color: AppColors.inkAlpha(0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(
                ctx,
                CloudBackupConfig(url: url, username: userController.text.trim(), password: passController.text),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF01B4E4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
            ),
            child: Text(l10n.backupSave, style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null) {
      await CloudBackupSettings.setConfig(result);
    }
  }

  InputDecoration _cloudFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
        filled: true,
        fillColor: AppColors.bar,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)), borderSide: BorderSide.none),
      );

  Future<void> _uploadCloud(BuildContext context) async {
    final config = CloudBackupSettings.config.value;
    if (config == null) return;
    setState(() => _isBackingUp = true);
    try {
      await BackupService.uploadToCloud(config);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.backupUploaded),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.backupUploadFailed('$e')), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _downloadCloud(BuildContext context) async {
    final l10n = context.l10n;
    final config = CloudBackupSettings.config.value;
    if (config == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg))),
        title: Text(l10n.backupCloudRestoreConfirmTitle, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Text(
          l10n.backupCloudRestoreConfirmBody,
          style: TextStyle(color: AppColors.inkAlpha(0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backupCancel, style: TextStyle(color: AppColors.inkAlpha(0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
            ),
            child: Text(l10n.backupRestore, style: const TextStyle(color: AppColors.onAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackingUp = true);
    try {
      final restored = await BackupService.downloadFromCloud(config);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.backupRestored(restored)),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.backupRestoreFailed('$e')), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Widget _buildBackupSection() {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
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
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                ),
                child: Icon(Icons.save_alt_rounded, color: AppColors.accent),
              ),
              SizedBox(width: context.rem(0.875)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupSectionTitle,
                      style: const TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: context.rem(AppRem.xs)),
                    Text(
                      l10n.backupSectionBody,
                      style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.captionPlus, height: 1.35), // ratio: a line height, not a size
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.rem(AppRem.md)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBackingUp ? null : () => _exportData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.inkAlpha(0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                    padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                  ),
                  icon: Icon(Icons.download_rounded, size: context.rem(AppRem.iconSm)),
                  label: Text(l10n.backupExport),
                ),
              ),
              SizedBox(width: context.rem(0.625)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBackingUp ? null : () => _importData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.inkAlpha(0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                    padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                  ),
                  icon: Icon(Icons.upload_rounded, size: context.rem(AppRem.iconSm)),
                  label: Text(l10n.backupImport),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupSection() {
    final l10n = context.l10n;
    return ValueListenableBuilder<CloudBackupConfig?>(
      valueListenable: CloudBackupSettings.config,
      builder: (context, config, _) {
        final connected = config != null;
        return Container(
          padding: EdgeInsets.all(context.rem(AppRem.md)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
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
                    width: context.rem(2.625),
                    height: context.rem(2.625),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01B4E4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                    child: const Icon(Icons.cloud_rounded, color: Color(0xFF01B4E4)),
                  ),
                  SizedBox(width: context.rem(0.875)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.backupCloudTitle, style: const TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.w800)),
                        SizedBox(height: context.rem(AppRem.xs)),
                        Text(
                          connected
                              ? l10n.backupCloudConnected
                              : l10n.backupCloudDisconnected,
                          style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.captionPlus, height: 1.35), // ratio: a line height, not a size
                        ),
                      ],
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: () => CloudBackupSettings.setConfig(null),
                      child: Text(l10n.backupDisconnect, style: TextStyle(color: AppColors.inkAlpha(0.5), fontSize: AppType.small)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _showCloudConfigDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01B4E4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(0.625)),
                      ),
                      child: Text(l10n.backupConnect, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.small)),
                    ),
                ],
              ),
              if (connected) ...[
                SizedBox(height: context.rem(AppRem.md)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ? null : () => _uploadCloud(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.inkAlpha(0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                          padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                        ),
                        icon: Icon(Icons.cloud_upload_rounded, size: context.rem(AppRem.iconSm)),
                        label: Text(l10n.backupUpload),
                      ),
                    ),
                    SizedBox(width: context.rem(0.625)),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ? null : () => _downloadCloud(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.inkAlpha(0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                          padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                        ),
                        icon: Icon(Icons.cloud_download_rounded, size: context.rem(AppRem.iconSm)),
                        label: Text(l10n.backupDownload),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// "Back up on app open, if it's been long enough" -- works with whichever
  /// destination is connected above (Dropbox preferred, WebDAV otherwise; see
  /// `AutoBackupService`). Shown always, even with nothing connected yet, so
  /// the interval is already set the moment someone does connect one instead
  /// of a second thing to come back and configure.
  Widget _buildAutoBackupSection() {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: AutoBackupSettings.enabled,
      builder: (context, enabled, _) {
        return Container(
          padding: EdgeInsets.all(context.rem(AppRem.md)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            border: Border.all(color: AppColors.inkAlpha(0.08)),
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
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                    child: Icon(Icons.history_rounded, color: AppColors.accent),
                  ),
                  SizedBox(width: context.rem(0.875)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.backupAutoSectionTitle, style: const TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.w800)),
                        SizedBox(height: context.rem(AppRem.xs)),
                        Text(
                          l10n.backupAutoSectionBody,
                          style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.captionPlus, height: 1.35), // ratio: a line height, not a size
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: AppColors.accent,
                    onChanged: AutoBackupSettings.setEnabled,
                  ),
                ],
              ),
              if (enabled) ...[
                SizedBox(height: context.rem(AppRem.md)),
                ValueListenableBuilder<int>(
                  valueListenable: AutoBackupSettings.intervalDays,
                  builder: (context, days, _) {
                    Widget chip(String label, int value) {
                      final selected = days == value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.xxs)),
                          child: OutlinedButton(
                            onPressed: () => AutoBackupSettings.setIntervalDays(value),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selected ? AppColors.accent.withValues(alpha: 0.14) : null,
                              foregroundColor: selected ? AppColors.accent : AppColors.inkAlpha(0.6),
                              side: BorderSide(color: selected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.inkAlpha(0.16)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                              padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.sm)),
                            ),
                            child: Text(label, style: const TextStyle(fontSize: AppType.small)),
                          ),
                        ),
                      );
                    }

                    return Row(
                      children: [
                        chip(l10n.backupAutoIntervalDaily, 1),
                        chip(l10n.backupAutoIntervalWeekly, 7),
                        chip(l10n.backupAutoIntervalMonthly, 30),
                      ],
                    );
                  },
                ),
                SizedBox(height: context.rem(AppRem.sm)),
                FutureBuilder<DateTime?>(
                  future: AutoBackupSettings.lastRunAt(),
                  builder: (context, snapshot) {
                    final last = snapshot.data;
                    return Text(
                      last == null
                          ? l10n.backupAutoNeverRun
                          : l10n.backupAutoLastRun(_formatWhen(last)),
                      style: TextStyle(color: AppColors.inkAlpha(0.4), fontSize: AppType.tiny),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatWhen(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

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
        title: Text(context.l10n.settingsCategoryBackup, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.titleSm)),
      ),
      body: SettingsScrollView(
        minGutter: 20,
        topPadding: 24,
        bottomPadding: 24,
        children: [
          _buildBackupSection(),
          SizedBox(height: context.rem(AppRem.ms)),
          const _DropboxBackupSection(),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildCloudBackupSection(),
          SizedBox(height: context.rem(AppRem.ms)),
          _buildAutoBackupSection(),
        ],
      ),
    );
  }
}

/// Mirrors [_BackupSettingsPageState]'s WebDAV section in shape (connect,
/// upload, download) but owns its own connect/busy state, the way
/// `sync_settings_page.dart`'s Trakt/Simkl cards do -- Dropbox's pairing is a
/// pasted code rather than a URL/username/password dialog, which the WebDAV
/// section's single busy flag has no state for.
class _DropboxBackupSection extends StatefulWidget {
  const _DropboxBackupSection();

  @override
  State<_DropboxBackupSection> createState() => _DropboxBackupSectionState();
}

class _DropboxBackupSectionState extends State<_DropboxBackupSection> {
  bool _isLoading = true;
  bool _connected = false;
  String? _accountName;
  bool _isConnecting = false;
  bool _isBusy = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final connected = await DropboxBackupService.isAuthenticated();
    final name = connected ? await DropboxBackupService.getAccountName() : null;
    if (mounted) {
      setState(() {
        _connected = connected;
        _accountName = name;
        _isLoading = false;
      });
    }
  }

  Future<void> _startConnecting() async {
    setState(() => _isConnecting = true);
    final url = await DropboxBackupService.beginAuthorization();
    try {
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[Dropbox] Browser launch error: $e');
    }
  }

  Future<void> _submitCode() async {
    final l10n = context.l10n;
    setState(() => _isBusy = true);
    try {
      await DropboxBackupService.connectWithCode(_codeController.text);
      _codeController.clear();
      if (mounted) setState(() => _isConnecting = false);
      await _checkStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDropboxConnectFailed('$e')), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _disconnect() async {
    await DropboxBackupService.logout();
    await _checkStatus();
  }

  Future<void> _uploadDropbox() async {
    final l10n = context.l10n;
    setState(() => _isBusy = true);
    try {
      await DropboxBackupService.upload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDropboxUploaded), backgroundColor: const Color(0xFF1E8E3E), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDropboxUploadFailed('$e')), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _downloadDropbox() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg))),
        title: Text(l10n.backupCloudRestoreConfirmTitle, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Text(l10n.backupCloudRestoreConfirmBody, style: TextStyle(color: AppColors.inkAlpha(0.65))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backupCancel, style: TextStyle(color: AppColors.inkAlpha(0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
            ),
            child: Text(l10n.backupRestore, style: const TextStyle(color: AppColors.onAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final restored = await DropboxBackupService.download();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestored(restored)), backgroundColor: const Color(0xFF1E8E3E), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreFailed('$e')), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  static const _dropboxBlue = Color(0xFF0061FF);

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    if (_isLoading) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(
          color: _connected ? _dropboxBlue.withValues(alpha: 0.3) : AppColors.inkAlpha(0.08),
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
                  color: _dropboxBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                ),
                child: const Icon(Icons.cloud_rounded, color: _dropboxBlue),
              ),
              SizedBox(width: context.rem(0.875)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupDropboxTitle, style: const TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.w800)),
                    SizedBox(height: context.rem(AppRem.xs)),
                    Text(
                      !DropboxBackupService.isConfigured
                          ? l10n.backupDropboxUnavailable
                          : _connected
                              ? l10n.backupDropboxConnected(_accountName ?? '')
                              : l10n.backupDropboxDisconnected,
                      style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.captionPlus, height: 1.35), // ratio: a line height, not a size
                    ),
                  ],
                ),
              ),
              if (DropboxBackupService.isConfigured && !_isConnecting)
                if (_connected)
                  TextButton(
                    onPressed: _disconnect,
                    child: Text(l10n.backupDisconnect, style: TextStyle(color: AppColors.inkAlpha(0.5), fontSize: AppType.small)),
                  )
                else
                  ElevatedButton(
                    onPressed: _startConnecting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dropboxBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(0.625)),
                    ),
                    child: Text(l10n.backupDropboxOpenDropbox, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.small)),
                  ),
            ],
          ),
          // The code Dropbox showed in the browser, pasted back here -- no
          // redirect URI/deep link for Dropbox to hand the code to instead.
          if (_isConnecting) ...[
            SizedBox(height: context.rem(AppRem.md)),
            TextField(
              controller: _codeController,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: InputDecoration(
                hintText: l10n.backupDropboxPasteCodeHint,
                hintStyle: TextStyle(color: AppColors.inkAlpha(0.3)),
                filled: true,
                fillColor: AppColors.bar,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: context.rem(0.625)),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _isConnecting = false),
                    child: Text(l10n.backupCancel, style: TextStyle(color: AppColors.inkAlpha(0.6))),
                  ),
                ),
                SizedBox(width: context.rem(0.625)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : _submitCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dropboxBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                    ),
                    child: Text(l10n.backupDropboxSubmitCode, style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
          if (_connected) ...[
            SizedBox(height: context.rem(AppRem.md)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _uploadDropbox,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(color: AppColors.inkAlpha(0.16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                      padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                    ),
                    icon: Icon(Icons.cloud_upload_rounded, size: context.rem(AppRem.iconSm)),
                    label: Text(context.l10n.backupUpload),
                  ),
                ),
                SizedBox(width: context.rem(0.625)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _downloadDropbox,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(color: AppColors.inkAlpha(0.16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                      padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                    ),
                    icon: Icon(Icons.cloud_download_rounded, size: context.rem(AppRem.iconSm)),
                    label: Text(context.l10n.backupDownload),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
