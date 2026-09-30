import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/l10n.dart';
import '../../services/updater/app_updater_service.dart';
import '../../app_info.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Getters, not variables: a top-level or static variable is initialized
  // lazily, once, on its first read -- which would freeze whichever theme
  // happened to be active when this screen was first opened, and leave it
  // there through every later theme change.
  static Color get _surfaceColor => AppColors.surface;
  static Color get _backgroundColor => AppColors.canvas;
  static Color get _accentColor => AppColors.accent;

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return PopScope(
      canPop: !_isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isDownloading) {
          AppUpdaterService.dismissVersion(widget.updateInfo.latestVersion);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: context.rem(31.25)),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(context.rem(1.25)),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.3),
              width: 1.5, // px: a hairline, not a layout size
            ),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.2),
              blurRadius: context.rem(2.5),
              spreadRadius: context.rem(0.3125),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.all(context.rem(AppRem.lg)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accentColor.withValues(alpha: 0.2),
                    _accentColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(context.rem(1.25)),
                  topRight: Radius.circular(context.rem(1.25)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.rem(AppRem.ms)),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      color: _accentColor,
                      size: context.rem(2),
                    ),
                  ),
                  SizedBox(width: context.rem(AppRem.md)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.updateAvailable.toUpperCase(),
                          style: TextStyle(
                            fontSize: AppType.tiny,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: _accentColor,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xs)),
                        Text(
                          context.l10n.updateVersion(widget.updateInfo.latestVersion),
                          style: TextStyle(
                            fontSize: AppType.titleMd,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(context.rem(AppRem.lg)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version details container
                  Container(
                    padding: EdgeInsets.all(context.rem(AppRem.md)),
                    decoration: BoxDecoration(
                      color: AppColors.inkAlpha(0.05),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      border: Border.all(
                        color: AppColors.inkAlpha(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.updateCurrent,
                              style: TextStyle(
                                fontSize: AppType.tiny,
                                color: AppColors.inkDisabled,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              widget.updateInfo.currentVersion,
                              style: TextStyle(
                                fontSize: AppType.bodyLg,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: _accentColor,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              context.l10n.updateLatest,
                              style: TextStyle(
                                fontSize: AppType.tiny,
                                color: AppColors.inkDisabled,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: context.rem(AppRem.xs)),
                            Text(
                              widget.updateInfo.latestVersion,
                              style: TextStyle(
                                fontSize: AppType.bodyLg,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.rem(1.25)),

                  // Release notes header & box
                  Text(
                    context.l10n.updateWhatsNew.toUpperCase(),
                    style: TextStyle(
                      fontSize: AppType.tiny,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.inkDisabled,
                    ),
                  ),
                  SizedBox(height: context.rem(0.625)),
                  Container(
                    constraints: BoxConstraints(maxHeight: context.rem(11.25)),
                    padding: EdgeInsets.all(context.rem(AppRem.md)),
                    decoration: BoxDecoration(
                      color: _backgroundColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      border: Border.all(
                        color: AppColors.inkAlpha(0.08),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        widget.updateInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: AppType.small,
                          color: AppColors.inkMuted,
                          height: 1.5, // ratio: a line height, not a size
                        ),
                      ),
                    ),
                  ),

                  if (widget.updateInfo.isFlatpak) ...[
                    SizedBox(height: context.rem(AppRem.md)),
                    Container(
                      padding: EdgeInsets.all(context.rem(AppRem.ms)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
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
                              context.l10n.updateFlatpakNote,
                              style: TextStyle(
                                fontSize: AppType.caption,
                                color: Colors.orange.shade200,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.updateInfo.isMacOS ||
                      widget.updateInfo.isIOS) ...[
                    SizedBox(height: context.rem(AppRem.md)),
                    Container(
                      padding: EdgeInsets.all(context.rem(AppRem.ms)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
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
                              widget.updateInfo.isIOS
                                  ? "iOS: You'll be redirected to GitHub to download the IPA"
                                  : "macOS: You'll be redirected to GitHub to download",
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

                  if (_isDownloading) ...[
                    SizedBox(height: context.rem(1.25)),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.updateDownloading,
                              style: TextStyle(
                                fontSize: AppType.small,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                            Text(
                              '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: AppType.small,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.rem(AppRem.sm)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: AppColors.ink.withValues(
                              alpha: 0.1,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _accentColor,
                            ),
                            minHeight: context.rem(AppRem.sm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Buttons
            if (!_isDownloading)
              Padding(
                padding: EdgeInsets.fromLTRB(context.rem(AppRem.lg), 0, context.rem(AppRem.lg), context.rem(AppRem.lg)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          AppUpdaterService.dismissVersion(widget.updateInfo.latestVersion);
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.md)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                            side: BorderSide(
                              color: AppColors.inkAlpha(0.15),
                            ),
                          ),
                        ),
                        child: Text(
                          context.l10n.updateLater,
                          style: TextStyle(
                            fontSize: AppType.body,
                            fontWeight: FontWeight.bold,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: context.rem(AppRem.ms)),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: AppColors.onAccent,
                          padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.md)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.updateNow,
                              style: const TextStyle(
                                fontSize: AppType.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: context.rem(AppRem.sm)),
                            Icon(Icons.download_rounded, size: context.rem(AppRem.icon)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _handleUpdate() async {
    if (kIsWeb) {
      await AppUpdaterService().openDownloadPage(widget.updateInfo.downloadUrl);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (Platform.isAndroid) {
      await _downloadAndInstallAndroid();
    } else if (Platform.isWindows || Platform.isLinux) {
      await _downloadAndInstallDesktop();
    } else {
      // macOS / iOS - open browser
      await AppUpdaterService().openDownloadPage(widget.updateInfo.downloadUrl);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _downloadAndInstallAndroid() async {
    WakelockPlus.enable();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      OtaUpdate()
          .execute(
            widget.updateInfo.downloadUrl,
            destinationFilename:
                '${AppInfo.name}_${widget.updateInfo.latestVersion}.apk',
          )
          .listen(
            (OtaEvent event) {
              if (mounted) {
                setState(() {
                  switch (event.status) {
                    case OtaStatus.DOWNLOADING:
                      final value = event.value;
                      if (value != null) {
                        final numVal = num.tryParse(value.toString()) ?? 0;
                        _downloadProgress = (numVal / 100.0).clamp(0.0, 1.0);
                      }
                      break;
                    case OtaStatus.INSTALLING:
                      _downloadProgress = 1.0;
                      WakelockPlus.disable();
                      break;
                    case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                      _isDownloading = false;
                      WakelockPlus.disable();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.updatePermission(AppInfo.name),
                          ),
                          duration: const Duration(seconds: 5),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      Navigator.of(context).pop();
                      break;
                    case OtaStatus.ALREADY_RUNNING_ERROR:
                    case OtaStatus.INTERNAL_ERROR:
                    case OtaStatus.DOWNLOAD_ERROR:
                    case OtaStatus.CHECKSUM_ERROR:
                      _isDownloading = false;
                      WakelockPlus.disable();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.updateFailed('${event.status}')),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      Navigator.of(context).pop();
                      break;
                    default:
                      break;
                  }
                });
              }
            },
            onError: (error) {
              WakelockPlus.disable();
              if (mounted) {
                setState(() => _isDownloading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.updateDownloadFailed('$error')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          );
    } catch (e) {
      WakelockPlus.disable();
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.updateFailed('$e')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndInstallDesktop() async {
    WakelockPlus.enable();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      Directory? downloadsDir;
      try {
        downloadsDir = await getDownloadsDirectory();
      } catch (_) {
        downloadsDir = null;
      }
      final dir = downloadsDir ?? await getTemporaryDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extension = Platform.isWindows
          ? '.exe'
          : (widget.updateInfo.isFlatpak ? '.flatpak' : '.AppImage');
      final fileName =
          '${AppInfo.name}-${widget.updateInfo.latestVersion}$extension';
      final filePath = path.join(dir.path, fileName);
      final file = File(filePath);

      final request = http.Request(
        'GET',
        Uri.parse(widget.updateInfo.downloadUrl),
      );
      final response = await request.send();

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (contentLength > 0 &&
            mounted &&
            (now - lastUpdateTime > 100 || downloadedBytes == contentLength)) {
          lastUpdateTime = now;
          final progress = downloadedBytes / contentLength;
          setState(() {
            _downloadProgress = progress;
          });
        }
      }

      await sink.close();

      if (mounted) {
        WakelockPlus.disable();
        setState(() => _isDownloading = false);

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _surfaceColor,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: context.rem(2)),
                SizedBox(width: context.rem(AppRem.ms)),
                Text(
                  context.l10n.updateDownloadComplete,
                  style: TextStyle(color: AppColors.ink),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.updateDownloadedTo,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
                SizedBox(height: context.rem(AppRem.sm)),
                Container(
                  padding: EdgeInsets.all(context.rem(AppRem.ms)),
                  decoration: BoxDecoration(
                    color: _backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                  ),
                  child: SelectableText(
                    filePath,
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: AppType.caption,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                SizedBox(height: context.rem(AppRem.md)),
                if (widget.updateInfo.isFlatpak) ...[
                  Text(
                    context.l10n.updateReinstallBundle,
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  SizedBox(height: context.rem(AppRem.sm)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.rem(AppRem.ms)),
                    decoration: BoxDecoration(
                      color: _backgroundColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                    ),
                    child: SelectableText(
                      'flatpak install --user --reinstall "$filePath"',
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: AppType.caption,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ] else
                  Text(
                    Platform.isWindows
                        ? context.l10n.updateCloseAndRun(AppInfo.name)
                        : context.l10n.updateMakeExecutable(fileName),
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
              ],
            ),
            actions: [
              if (widget.updateInfo.isFlatpak)
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: 'flatpak install --user --reinstall "$filePath"',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.updateCommandCopied),
                        ),
                      );
                    }
                  },
                  child: Text(
                    context.l10n.updateCopyCommand,
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ),
              TextButton(
                onPressed: () async {
                  if (Platform.isWindows) {
                    await Process.run('explorer', ['/select,', filePath]);
                  } else if (Platform.isLinux) {
                    await Process.run('xdg-open', [dir.path]);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  context.l10n.updateOpenFolder,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: AppColors.onAccent,
                ),
                child: Text(context.l10n.commonOk),
              ),
            ],
          ),
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      WakelockPlus.disable();
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.updateDownloadFailed('$e'))));
      }
    }
  }
}
