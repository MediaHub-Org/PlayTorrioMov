import 'package:flutter/material.dart';

import '../../services/backup/backup_service.dart';
import '../../services/backup/cloud_backup_settings.dart';
import '../../services/tmdb/tmdb_settings.dart';

/// Backup/restore, TMDB cast enrichment, and keyboard shortcuts reference --
/// ported from the pre-modularization `settings_page.dart` into its own
/// page to match the hub's per-category page convention.
class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  bool _isBackingUp = false;

  Future<void> _exportData(BuildContext context) async {
    setState(() => _isBackingUp = true);
    try {
      final path = await BackupService.export();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved to $path'),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore backup?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'This overwrites your current library, settings and addon config with the last exported backup. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackingUp = true);
    try {
      final restored = await BackupService.import();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored $restored settings — restart the app to see all changes.'),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
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
    final current = CloudBackupSettings.config.value;
    final urlController = TextEditingController(text: current?.url ?? '');
    final userController = TextEditingController(text: current?.username ?? '');
    final passController = TextEditingController(text: current?.password ?? '');

    final result = await showDialog<CloudBackupConfig>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Connect WebDAV', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Point this at a WebDAV endpoint on your own server (Nextcloud, etc.) — the full URL of the file to write, e.g. https://cloud.example.com/remote.php/dav/files/you/playtorrio_backup.json',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _cloudFieldDecoration('WebDAV URL'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _cloudFieldDecoration('Username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _cloudFieldDecoration('Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
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
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: const Color(0xFF0D1017),
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
        const SnackBar(
          content: Text('Backup uploaded.'),
          backgroundColor: Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _downloadCloud(BuildContext context) async {
    final config = CloudBackupSettings.config.value;
    if (config == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore from cloud?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'This overwrites your current library, settings and addon config with the backup stored on your WebDAV server. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
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
          content: Text('Restored $restored settings — restart the app to see all changes.'),
          backgroundColor: const Color(0xFF1E8E3E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _showTmdbKeyDialog() async {
    final controller = TextEditingController();

    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Connect TMDB',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste your TMDB API key (free — sign up at themoviedb.org, no billing required).',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'API Key',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF0D1017),
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
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF01B4E4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await TmdbSettings.setApiKey(key);
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildBackupSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.save_alt_rounded, color: Color(0xFF7C5CFF)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup & Restore',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Save your library, likes, playback history, settings and addon config to a local JSON file — or restore from one.',
                      style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.35),
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
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBackingUp ? null : () => _importData(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupSection() {
    return ValueListenableBuilder<CloudBackupConfig?>(
      valueListenable: CloudBackupSettings.config,
      builder: (context, config, _) {
        final connected = config != null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected ? const Color(0xFF01B4E4).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
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
                        const Text('Cloud Backup (WebDAV)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? 'Connected to your own WebDAV server.'
                              : 'Point this at a WebDAV endpoint on your own server to sync the same backup this app already writes locally.',
                          style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: () => CloudBackupSettings.setConfig(null),
                      child: Text('Disconnect', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _showCloudConfigDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01B4E4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text('Upload'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp ? null : () => _downloadCloud(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.cloud_download_rounded, size: 18),
                        label: const Text('Download'),
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

  Widget _buildTmdbSection() {
    return ValueListenableBuilder<String?>(
      valueListenable: TmdbSettings.apiKey,
      builder: (context, apiKey, _) {
        final connected = apiKey != null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected ? const Color(0xFF01B4E4).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
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
                      connected
                          ? 'Connected — cast photos and character names load when available.'
                          : 'Add your own free TMDB API key to fill in cast photos and character names most addons don\'t provide.',
                      style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (connected)
                TextButton(
                  onPressed: () => TmdbSettings.setApiKey(null),
                  child: Text(
                    'Disconnect',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _showTmdbKeyDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF01B4E4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShortcutsSection() {
    const shortcuts = [
      ('Space / K', 'Play / Pause'),
      ('J', 'Seek -5s'),
      ('L', 'Seek +5s'),
      ('M', 'Mute'),
      ('F', 'Toggle fullscreen'),
      ('Esc', 'Back'),
      ('Tab', 'Focus hub switcher'),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.keyboard_rounded, color: Color(0xFF7C5CFF)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (key, action) in shortcuts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      key,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(action, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('General & Data', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              _buildTmdbSection(),
              const SizedBox(height: 12),
              _buildBackupSection(),
              const SizedBox(height: 12),
              _buildCloudBackupSection(),
              const SizedBox(height: 12),
              _buildShortcutsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
