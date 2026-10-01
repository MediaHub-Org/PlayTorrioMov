import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/stream/stream_model.dart';
import '../../pages/player/player_screen.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../utils/fullscreen_navigator.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../common/hover_button.dart';
import '../../services/app_units.dart';

class MagnetFileItem {
  final int id;
  final String name;
  final int size;
  final String? downloadUrl;
  final bool isVideo;

  const MagnetFileItem({
    required this.id,
    required this.name,
    required this.size,
    this.downloadUrl,
    required this.isVideo,
  });

  String get cleanFilename {
    if (name.contains('/')) return name.split('/').last;
    if (name.contains(r'\')) return name.split(r'\').last;
    return name;
  }

  String get extension {
    final clean = cleanFilename;
    final dotIdx = clean.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < clean.length - 1) {
      return clean.substring(dotIdx + 1).toUpperCase();
    }
    return '';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}

class MagnetFilesView extends StatefulWidget {
  final String magnet;

  const MagnetFilesView({
    super.key,
    required this.magnet,
  });

  @override
  State<MagnetFilesView> createState() => _MagnetFilesViewState();
}

class _MagnetFilesViewState extends State<MagnetFilesView> {
  bool _isLoading = true;
  String? _errorMessage;
  String _torrentTitle = '';
  String? _infoHash;
  bool _isDebrid = false;
  String _providerName = 'Torrent Engine';
  int _totalSize = 0;
  List<MagnetFileItem> _files = [];

  String _searchFilter = '';
  String _activeCategory = 'all'; // 'all', 'video', 'other'

  @override
  void initState() {
    super.initState();
    _loadMagnetFiles();
  }

  @override
  void didUpdateWidget(covariant MagnetFilesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.magnet != widget.magnet) {
      _loadMagnetFiles();
    }
  }

  static bool _checkIsVideo(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.3gp');
  }

  static String? _extractHash(String magnetOrHash) {
    final match = RegExp(r'[0-9a-fA-F]{40}').firstMatch(magnetOrHash);
    return match?.group(0)?.toLowerCase();
  }

  static String _extractDisplayName(String magnet) {
    try {
      final match = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnet);
      if (match != null && match.group(1) != null) {
        return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
      }
    } catch (_) {
      // A magnet with no parseable display name falls back to the caller
      // default.
    }
    return '';
  }

  Future<void> _loadMagnetFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _files = [];
      _totalSize = 0;
    });

    final rawMagnet = widget.magnet.trim();
    final rawHash = _extractHash(rawMagnet);
    _infoHash = rawHash;

    String normalizedMagnet = rawMagnet;
    if (!rawMagnet.toLowerCase().startsWith('magnet:')) {
      if (rawHash != null) {
        normalizedMagnet = 'magnet:?xt=urn:btih:$rawHash';
      }
    }

    final dn = _extractDisplayName(normalizedMagnet);
    _torrentTitle = dn.isNotEmpty ? dn : (rawHash ?? 'Magnet Torrent');

    try {
      final useDebrid = await DebridService().isDebridActiveForStreams();
      _isDebrid = useDebrid;

      if (useDebrid) {
        final activeService = await DebridService().getSelectedService();
        _providerName = activeService;

        final debridFiles = await DebridService().resolveMagnet(magnet: normalizedMagnet);
        if (debridFiles.isEmpty) {
          throw Exception('$activeService returned no files for this magnet.');
        }

        final items = <MagnetFileItem>[];
        int sumBytes = 0;
        for (int i = 0; i < debridFiles.length; i++) {
          final df = debridFiles[i];
          final isVid = _checkIsVideo(df.filename);
          sumBytes += df.filesize;
          items.add(MagnetFileItem(
            id: i,
            name: df.filename,
            size: df.filesize,
            downloadUrl: df.downloadUrl,
            isVideo: isVid,
          ));
        }

        if (mounted) {
          setState(() {
            _files = items;
            _totalSize = sumBytes;
            _isLoading = false;
          });
        }
      } else {
        _providerName = 'Torrent Engine';
        final tss = TorrentStreamService();
        final info = await tss.getTorrentMetadata(normalizedMagnet);

        if (info == null || info.fileStats.isEmpty) {
          throw Exception('Could not retrieve torrent metadata from swarm. Check peer connectivity.');
        }

        final items = <MagnetFileItem>[];
        int sumBytes = 0;
        for (final stat in info.fileStats) {
          final isVid = _checkIsVideo(stat.path);
          sumBytes += stat.length;
          items.add(MagnetFileItem(
            id: stat.id,
            name: stat.path,
            size: stat.length,
            isVideo: isVid,
          ));
        }

        if (info.title.isNotEmpty && _torrentTitle == (rawHash ?? '')) {
          _torrentTitle = info.title;
        }

        if (mounted) {
          setState(() {
            _files = items;
            _totalSize = sumBytes > 0 ? sumBytes : info.torrentSize;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _playFile(MagnetFileItem file) {
    final streamTitle = file.cleanFilename;

    StreamSource source;
    if (_isDebrid) {
      source = StreamSource(
        name: _providerName,
        title: streamTitle,
        url: file.downloadUrl,
        addonName: _providerName,
      );
    } else {
      source = StreamSource(
        name: 'Torrent Engine',
        title: streamTitle,
        infoHash: _infoHash,
        fileIdx: file.id,
        addonName: 'Torrent Engine',
      );
    }

    pushFullscreenPage(
      PlayerScreen(
        source: source,
        title: streamTitle,
      ),
    );
  }

  List<MagnetFileItem> get _filteredFiles {
    return _files.where((f) {
      if (_activeCategory == 'video' && !f.isVideo) return false;
      if (_activeCategory == 'other' && f.isVideo) return false;
      if (_searchFilter.isNotEmpty) {
        return f.name.toLowerCase().contains(_searchFilter.toLowerCase());
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        if (_isLoading) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.lg)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(context.rem(1.25)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primaryColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: palette.primaryColor.withValues(alpha: 0.3),
                        width: 1.5, // px: a hairline, not a layout size
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primaryColor.withValues(alpha: 0.25),
                          blurRadius: context.rem(AppRem.lg),
                          spreadRadius: context.rem(AppRem.xs),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: context.rem(2.375),
                      height: context.rem(2.375),
                      child: CircularProgressIndicator(
                        color: palette.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  SizedBox(height: context.rem(AppRem.lg)),
                  Text(
                    _isDebrid ? context.l10n.playerStatusUsing(_providerName) : context.l10n.magnetConnecting,
                    style: TextStyle(
                      fontSize: AppType.bodyLg,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: context.rem(AppRem.sm)),
                  Text(
                    context.l10n.magnetGathering,
                    style: TextStyle(
                      fontSize: AppType.small,
                      color: AppColors.inkAlpha(0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_errorMessage != null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.xl)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(context.rem(1.125)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: context.rem(2.25)),
                  ),
                  SizedBox(height: context.rem(1.125)),
                  Text(
                    context.l10n.magnetFailed,
                    style: TextStyle(fontSize: AppType.subhead, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                  SizedBox(height: context.rem(AppRem.sm)),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppType.small, color: AppColors.inkAlpha(0.6), height: 1.4), // ratio: a line height, not a size
                  ),
                  SizedBox(height: context.rem(1.25)),
                  ElevatedButton.icon(
                    onPressed: _loadMagnetFiles,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryColor,
                      foregroundColor: AppColors.onAccent,
                      padding: EdgeInsets.symmetric(horizontal: context.rem(1.25), vertical: context.rem(AppRem.ms)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd))),
                    ),
                    icon: Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconSm)),
                    label: Text(context.l10n.commonTryAgain, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = _filteredFiles;
        final videoCount = _files.where((f) => f.isVideo).length;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            context.rem(AppRem.md),
            MediaQuery.paddingOf(context).top + kToolbarHeight + context.rem(1.25),
            context.rem(AppRem.md),
            40 + MediaQuery.paddingOf(context).bottom,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            // Header Info Card
            _buildTorrentHeaderCard(palette, videoCount),

            SizedBox(height: context.rem(1.125)),

            // Search & Filter Toolbar
            _buildFilterToolbar(palette, videoCount),

            SizedBox(height: context.rem(0.875)),

            // Files List
            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.rem(2.5)),
                  child: Text(
                    context.l10n.magnetNoMatch,
                    style: TextStyle(color: AppColors.inkAlpha(0.4), fontSize: AppType.body),
                  ),
                ),
              )
            else
              ...filtered.map((file) => _buildFileTile(file, palette)),
          ],
        );
      },
    );
  }

  Widget _buildTorrentHeaderCard(AppThemePalette palette, int videoCount) {
    return Container(
      padding: EdgeInsets.all(context.rem(1.125)),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusXl)),
        border: Border.all(
          color: palette.primaryColor.withValues(alpha: 0.3),
          width: 1.2, // px: a hairline, not a layout size
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: context.rem(1.125),
            offset: Offset(0, context.rem(AppRem.snug)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.rem(0.625)),
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                ),
                child: Icon(Icons.link_rounded, color: palette.primaryColor, size: context.rem(AppRem.iconMd)),
              ),
              SizedBox(width: context.rem(AppRem.ms)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _torrentTitle,
                      style: TextStyle(
                        fontSize: AppType.bodyLg,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_infoHash != null) ...[
                      SizedBox(height: context.rem(0.1875)),
                      Text(
                        _infoHash!,
                        style: TextStyle(
                          fontSize: AppType.tiny,
                          color: AppColors.inkAlpha(0.4),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.rem(0.875)),
          Wrap(
            spacing: context.rem(AppRem.sm),
            runSpacing: context.rem(AppRem.sm),
            children: [
              // Provider Badge
              _buildBadge(
                icon: _isDebrid ? Icons.cloud_done_rounded : Icons.hub_rounded,
                label: _isDebrid ? '$_providerName Cloud' : 'P2P Swarm',
                color: _isDebrid ? Colors.cyanAccent : palette.primaryColor,
              ),
              // Size Badge
              _buildBadge(
                icon: Icons.storage_rounded,
                label: MagnetFileItem.formatBytes(_totalSize),
                color: AppColors.inkMuted,
              ),
              // Total Files Badge
              _buildBadge(
                icon: Icons.folder_rounded,
                label: '${_files.length} ${_files.length == 1 ? "file" : "files"}',
                color: AppColors.inkMuted,
              ),
              // Video Files Badge
              if (videoCount > 0)
                _buildBadge(
                  icon: Icons.movie_rounded,
                  label: '$videoCount ${videoCount == 1 ? "video" : "videos"}',
                  color: palette.primaryColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(0.3125)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8), // px: a hairline, not a layout size
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rem(0.8125), color: color),
          SizedBox(width: context.rem(0.3125)),
          Text(
            label,
            style: TextStyle(
              fontSize: AppType.tinyPlus,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(AppThemePalette palette, int videoCount) {
    return Column(
      children: [
        // Search Filter Input
        Container(
          height: context.rem(2.375),
          decoration: BoxDecoration(
            color: AppColors.inkAlpha(0.05),
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
            border: Border.all(color: AppColors.inkAlpha(0.08)),
          ),
          child: TextField(
            style: TextStyle(color: AppColors.ink, fontSize: AppType.small),
            onChanged: (val) => setState(() => _searchFilter = val),
            decoration: InputDecoration(
              hintText: context.l10n.magnetFilterFiles,
              hintStyle: TextStyle(color: AppColors.inkAlpha(0.3), fontSize: AppType.small),
              prefixIcon: Icon(Icons.filter_list_rounded, size: context.rem(AppRem.iconXs), color: AppColors.inkAlpha(0.4)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(AppRem.sm)),
              isDense: true,
            ),
          ),
        ),
        SizedBox(height: context.rem(0.625)),
        // Filter Chips
        Row(
          children: [
            _buildCategoryChip('all', 'All (${_files.length})', palette),
            SizedBox(width: context.rem(AppRem.sm)),
            _buildCategoryChip('video', 'Videos ($videoCount)', palette),
            SizedBox(width: context.rem(AppRem.sm)),
            _buildCategoryChip('other', 'Other (${_files.length - videoCount})', palette),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category, String label, AppThemePalette palette) {
    final isSelected = _activeCategory == category;
    return HoverButton(
      scaleAmount: 1.05,
      focusFillRadius: context.rem(1.25),
      onTap: () => setState(() => _activeCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(AppRem.snug)),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primaryColor.withValues(alpha: 0.25)
              : AppColors.inkAlpha(0.05),
          borderRadius: BorderRadius.circular(context.rem(1.25)),
          border: Border.all(
            color: isSelected
                ? palette.primaryColor
                : AppColors.inkAlpha(0.1),
            width: 1, // px: a hairline, not a layout size
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppType.tinyPlus,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.ink : AppColors.inkAlpha(0.60),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(MagnetFileItem file, AppThemePalette palette) {
    final ext = file.extension;

    return Container(
      margin: EdgeInsets.only(bottom: context.rem(AppRem.sm)),
      padding: EdgeInsets.all(context.rem(AppRem.ms)),
      decoration: BoxDecoration(
        color: file.isVideo
            ? AppColors.raised.withValues(alpha: 0.75)
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(context.rem(0.875)),
        border: Border.all(
          color: file.isVideo
              ? palette.primaryColor.withValues(alpha: 0.2)
              : AppColors.inkAlpha(0.05),
          width: 0.9, // px: a hairline, not a layout size
        ),
      ),
      child: Row(
        children: [
          // File Type Icon
          Container(
            width: context.rem(2.375),
            height: context.rem(2.375),
            decoration: BoxDecoration(
              color: file.isVideo
                  ? palette.primaryColor.withValues(alpha: 0.15)
                  : AppColors.inkAlpha(0.05),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
            ),
            child: Icon(
              file.isVideo
                  ? Icons.movie_rounded
                  : (ext == 'MP3' || ext == 'FLAC' || ext == 'M4A'
                      ? Icons.audiotrack_rounded
                      : Icons.insert_drive_file_rounded),
              color: file.isVideo ? palette.primaryColor : AppColors.inkSubtle,
              size: context.rem(AppRem.icon),
            ),
          ),
          SizedBox(width: context.rem(AppRem.ms)),

          // Filename & Size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.cleanFilename,
                  style: TextStyle(
                    fontSize: AppType.small,
                    fontWeight: file.isVideo ? FontWeight.w600 : FontWeight.normal,
                    color: file.isVideo ? AppColors.ink : AppColors.inkMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.rem(AppRem.xs)),
                Row(
                  children: [
                    if (ext.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.rem(0.3125), vertical: context.rem(0.0938)),
                        decoration: BoxDecoration(
                          color: AppColors.inkAlpha(0.08),
                          borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                        ),
                        child: Text(
                          ext,
                          style: TextStyle(
                            fontSize: TvType.scale(AppType.nanoPlus),
                            fontWeight: FontWeight.bold,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      SizedBox(width: context.rem(AppRem.snug)),
                    ],
                    Text(
                      MagnetFileItem.formatBytes(file.size),
                      style: TextStyle(
                        fontSize: AppType.tiny,
                        color: AppColors.inkAlpha(0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: context.rem(0.625)),

          // Action Button
          if (file.isVideo)
            ElevatedButton.icon(
              onPressed: () => _playFile(file),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryColor,
                foregroundColor: AppColors.onAccent,
                padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.5625)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                elevation: 0,
              ),
              icon: Icon(Icons.play_arrow_rounded, size: context.rem(AppRem.iconSm)),
              label: Text(
                context.l10n.playerPlay,
                style: const TextStyle(
                  fontSize: AppType.captionPlus,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              context.l10n.magnetNonVideo,
              style: TextStyle(
                fontSize: AppType.tiny,
                color: AppColors.inkAlpha(0.25),
              ),
            ),
        ],
      ),
    );
  }
}
