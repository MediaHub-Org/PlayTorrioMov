import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/cloud_backup_settings.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.backupWebdavTitle, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupWebdavBody,
              style: TextStyle(color: AppColors.inkAlpha(0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlController,
              autofocus: true,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
              decoration: _cloudFieldDecoration(l10n.backupWebdavUrl),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userController,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
              decoration: _cloudFieldDecoration(l10n.backupWebdavUsername),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              obscureText: true,
              style: TextStyle(color: AppColors.ink, fontSize: 14),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
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
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.save_alt_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupSectionTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.backupSectionBody,
                      style: TextStyle(color: AppColors.inkSubtle, fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBackingUp ? null : () => _exportData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.inkAlpha(0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(l10n.backupExport),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBackingUp ? null : () => _importData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.inkAlpha(0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 18),
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
                    child: const Icon(Icons.cloud_rounded, color: Color(0xFF01B4E4)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.backupCloudTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? l10n.backupCloudConnected
                              : l10n.backupCloudDisconnected,
                          style: TextStyle(color: AppColors.inkSubtle, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: () => CloudBackupSettings.setConfig(null),
                      child: Text(l10n.backupDisconnect, style: TextStyle(color: AppColors.inkAlpha(0.5), fontSize: 13)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _showCloudConfigDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01B4E4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(l10n.backupConnect, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                ],
              ),
              if (connected) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ? null : () => _uploadCloud(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.inkAlpha(0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(l10n.backupUpload),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ? null : () => _downloadCloud(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.inkAlpha(0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
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

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.settingsCategoryBackup, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SettingsScrollView(
        minGutter: 20,
        topPadding: 24,
        bottomPadding: 24,
        children: [
          _buildBackupSection(),
          const SizedBox(height: 12),
          _buildCloudBackupSection(),
        ],
      ),
    );
  }
}
