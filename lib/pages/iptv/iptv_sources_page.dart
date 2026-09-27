import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_network.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../services/theme/app_colors.dart';
import '../../services/theme/app_theme_service.dart';
import '../../utils/navigation/route_transitions.dart';
import 'iptv_portal_browser_page.dart';

/// Live TV's sources, as a page rather than a modal.
///
/// Adding, discovering and removing portals and playlists used to live in
/// `IptvPortalsModal`, a 1400-line dialog with its own tabs, its own edit
/// modes and its own copy of every display preference the settings page
/// already owns. A dialog is the wrong shape for it: managing sources is a
/// destination, not an interruption, and cramming two lists, two forms and
/// a scrape control into one box is what made the modal need tabs and modes
/// in the first place. Here each list gets its own section, the forms open
/// inline, and display preferences stay where they are -- in settings.
///
/// Tapping a source opens its channels in [IptvPortalBrowserPage], which is
/// Live TV only: a portal's movies and series are not live, and giving them
/// their own tabs here rebuilt the app's Films/Series navigation inside a
/// source browser.
class IptvSourcesPage extends StatefulWidget {
  const IptvSourcesPage({super.key});

  @override
  State<IptvSourcesPage> createState() => _IptvSourcesPageState();
}

class _IptvSourcesPageState extends State<IptvSourcesPage> {
  final _ctrl = IptvController.instance;

  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _m3uNameCtrl = TextEditingController();
  final _m3uUrlCtrl = TextEditingController();

  bool _showPortalForm = false;
  bool _showM3uForm = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uNameCtrl.dispose();
    _m3uUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPortal() async {
    final success = await _ctrl.addManual(
      url: _urlCtrl.text,
      username: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (success) {
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      setState(() => _showPortalForm = false);
    }
  }

  Future<void> _submitM3u() async {
    if (_m3uUrlCtrl.text.trim().isEmpty) return;
    await _ctrl.addM3uFromUrl(_m3uNameCtrl.text, _m3uUrlCtrl.text.trim());
    _m3uNameCtrl.clear();
    _m3uUrlCtrl.clear();
    setState(() => _showM3uForm = false);
  }

  /// A destructive action asks first. Portals scraped in bulk are easy to
  /// re-find, but a hand-entered login is not, and the tap that gets here
  /// sits beside harmless ones in the same menu.
  Future<bool> _confirmRemove() async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.iptvRemoveSourceTitle,
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        content: Text(
          context.l10n.iptvRemoveSourceBody,
          style: TextStyle(color: AppColors.inkAlpha(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.libraryCancel,
              style: TextStyle(color: AppColors.inkAlpha(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.libraryRemove,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return answer == true;
  }

  void _copyLogin(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.iptvCopied(text)),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.raised,
      ),
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
        // The framework back button, like the Library shelves: a custom
        // glass circle here rendered oversized against the plain bar.
        title: Text(
          context.l10n.iptvManagePortals,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPortalSection(context),
                const SizedBox(height: 28),
                _buildM3uSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Xtream portals ────────────────────────────────────────────────────

  Widget _buildPortalSection(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.l10n.iptvTabXtream(_ctrl.verified.length),
          onDeleteAll: _ctrl.verified.isEmpty
              ? null
              : () async {
                  if (await _confirmRemove()) {
                    await _ctrl.deleteAllPortals();
                  }
                },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: _ctrl.isScraping
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : const Icon(
                      Icons.radar_rounded,
                      size: 16,
                      color: AppColors.onAccent,
                    ),
              label: Text(
                _ctrl.isScraping
                    ? context.l10n.iptvFinding(
                        _ctrl.scrapeSource == CatalogSource.cloudVault
                            ? 'Cloud Vault'
                            : 'Reddit',
                      )
                    : context.l10n.iptvGeneratePortals,
                style: const TextStyle(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _ctrl.isScraping ? null : _ctrl.scrape,
            ),
            _ScrapeSourcePicker(
              source: _ctrl.scrapeSource,
              onSelected: _ctrl.setScrapeSource,
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: BorderSide(color: AppColors.inkAlpha(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                context.l10n.iptvAddPortal,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () =>
                  setState(() => _showPortalForm = !_showPortalForm),
            ),
          ],
        ),
        if (_ctrl.statusText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _ctrl.statusText,
            style: const TextStyle(
              color: Color(0xFF00D2EF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_showPortalForm) ...[
          const SizedBox(height: 14),
          _FormCard(
            children: [
              Text(
                context.l10n.iptvAddXtreamTitle,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _urlCtrl,
                style: TextStyle(color: AppColors.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: context.l10n.iptvServerUrl,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userCtrl,
                      style: TextStyle(color: AppColors.ink, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.l10n.iptvUsername,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _passCtrl,
                      style: TextStyle(color: AppColors.ink, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.l10n.iptvPassword,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_ctrl.addError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _ctrl.addError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  onPressed: _ctrl.isAdding ? null : _submitPortal,
                  child: _ctrl.isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : Text(context.l10n.iptvVerifySave),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (_ctrl.verified.isEmpty)
          _EmptyLine(
            text: context.l10n.iptvNoVerified(
              _ctrl.scrapeSource == CatalogSource.cloudVault
                  ? 'Cloud Vault'
                  : 'Reddit',
            ),
          )
        else
          for (var i = 0; i < _ctrl.verified.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PortalRow(
              index: i,
              onOpen: () => pushPage(
                context,
                IptvPortalBrowserPage(portal: _ctrl.verified[i]),
              ),
              onDelete: () async {
                if (await _confirmRemove()) {
                  await _ctrl.deletePortalsByKeys(
                    {_ctrl.verified[i].key},
                  );
                }
              },
              onCopyLogin: _copyLogin,
            ),
          ],
      ],
    );
  }

  // ── M3U playlists ─────────────────────────────────────────────────────

  Widget _buildM3uSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.l10n.iptvTabM3u(_ctrl.m3uPlaylists.length),
          onDeleteAll: _ctrl.m3uPlaylists.isEmpty
              ? null
              : () async {
                  if (await _confirmRemove()) {
                    await _ctrl.deleteAllM3uPlaylists();
                  }
                },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: BorderSide(color: AppColors.inkAlpha(0.2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.playlist_add_rounded, size: 16),
          label: Text(
            context.l10n.iptvAddM3uUrl,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => setState(() => _showM3uForm = !_showM3uForm),
        ),
        if (_showM3uForm) ...[
          const SizedBox(height: 14),
          _FormCard(
            children: [
              Text(
                context.l10n.iptvAddM3uTitle,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _m3uNameCtrl,
                style: TextStyle(color: AppColors.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: context.l10n.iptvPlaylistName,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _m3uUrlCtrl,
                style: TextStyle(color: AppColors.ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: context.l10n.iptvM3uUrl,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  onPressed: _ctrl.isM3uLoading ? null : _submitM3u,
                  child: _ctrl.isM3uLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onAccent,
                          ),
                        )
                      : Text(context.l10n.iptvFetchSave),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (_ctrl.m3uPlaylists.isEmpty)
          _EmptyLine(text: context.l10n.iptvNoM3u)
        else
          for (var i = 0; i < _ctrl.m3uPlaylists.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _M3uRow(
              index: i,
              onOpen: () => pushPage(
                context,
                IptvPortalBrowserPage(m3uPlaylist: _ctrl.m3uPlaylists[i]),
              ),
              onDelete: () async {
                if (await _confirmRemove()) {
                  await _ctrl.deleteM3uPlaylist(_ctrl.m3uPlaylists[i].id);
                }
              },
              onCopyUrl: _copyLogin,
            ),
          ],
      ],
    );
  }
}

/// A section heading with an optional remove-all action. The bulk delete
/// the modal's edit mode offered survives here as one confirmed button:
/// selecting portals one by one to delete them was the mode, not the
/// feature.
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onDeleteAll;

  const _SectionHeader({required this.title, this.onDeleteAll});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onDeleteAll != null)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: Text(
              context.l10n.iptvDeleteAll,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: onDeleteAll,
          ),
      ],
    );
  }
}

/// Where the portal scrape looks: the shared vault or community posts.
/// Small and inline, the way the modal had it -- this is a source choice,
/// not a setting, so it lives next to the button that uses it.
class _ScrapeSourcePicker extends StatelessWidget {
  final CatalogSource source;
  final ValueChanged<CatalogSource> onSelected;

  const _ScrapeSourcePicker({required this.source, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return PopupMenuButton<CatalogSource>(
      tooltip: context.l10n.iptvChooseSource,
      initialValue: source,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.inkAlpha(0.12)),
      ),
      color: AppColors.raised,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
        decoration: BoxDecoration(
          color: AppColors.inkAlpha(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inkAlpha(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              source == CatalogSource.cloudVault
                  ? Icons.cloud_done_rounded
                  : Icons.forum_rounded,
              size: 15,
              color: source == CatalogSource.cloudVault
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFFFF5722),
            ),
            const SizedBox(width: 6),
            // Flexible: at a large text scale the source name outgrows the
            // rail, and a min-size Row sizes its children to their natural
            // width unless one may give.
            Flexible(
              child: Text(
                source == CatalogSource.cloudVault ? 'Cloud Vault' : 'Reddit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: CatalogSource.cloudVault,
          child: Text(
            context.l10n.iptvCloudVaultTitle,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
          ),
        ),
        PopupMenuItem(
          value: CatalogSource.reddit,
          child: Text(
            context.l10n.iptvRedditTitle,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// The bordered card an add form opens in.
class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inkAlpha(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// A list that is empty says so, rather than leaving a gap the shape of
/// missing content.
class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: AppColors.inkSubtle)),
    );
  }
}

/// One verified portal. Tapping opens its channels; the star pins it as a
/// favorite and the menu holds the rest, so the row reads as a source
/// first and a set of chores second.
class _PortalRow extends StatelessWidget {
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<String> onCopyLogin;

  const _PortalRow({
    required this.index,
    required this.onOpen,
    required this.onDelete,
    required this.onCopyLogin,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final ctrl = IptvController.instance;
    final p = ctrl.verified[index];
    final isFav = ctrl.isFavoritePortal(p.key);
    final palette = AppThemeService.currentPalette.value;
    final showExp =
        IptvSettings.showPortalExpiry.value && p.expiry.isNotEmpty;
    final showConn =
        IptvSettings.showPortalConnections.value && p.maxConnections.isNotEmpty;

    return _SourceRowShell(
      onOpen: onOpen,
      leading: const _SourceIconTile(
        icon: Icons.settings_input_antenna_rounded,
      ),
      title: p.name.isNotEmpty ? p.name : p.portal.url,
      subtitle: p.portal.url,
      badges: [
        if (showExp)
          _Badge(
            text: context.l10n.iptvExpiry(p.expiry),
            color: palette.primaryColor,
          ),
        if (showConn)
          _Badge(
            text: context.l10n.iptvConnections(
              p.activeConnections,
              p.maxConnections,
            ),
            color: AppColors.inkMuted,
          ),
        if (p.portal.source.isNotEmpty)
          _Badge(text: p.portal.source, color: AppColors.inkMuted),
      ],
      actions: [
        IconButton(
          tooltip: isFav
              ? context.l10n.iptvRemoveFavorite
              : context.l10n.iptvAddFavorite,
          icon: Icon(
            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFav ? const Color(0xFFFFC107) : AppColors.inkDisabled,
            size: 20,
          ),
          onPressed: () => ctrl.toggleFavoritePortal(p.key),
        ),
        IconButton(
          tooltip: context.l10n.iptvCopyLogin,
          icon: Icon(Icons.copy_rounded, color: AppColors.inkSubtle, size: 18),
          onPressed: () => onCopyLogin(
            '${p.portal.url}:${p.portal.username}:${p.portal.password}',
          ),
        ),
        IconButton(
          tooltip: context.l10n.iptvDeletePortal,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// One saved playlist. Same shape as a portal row, minus the favorite star
/// the modal never gave it.
class _M3uRow extends StatelessWidget {
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<String> onCopyUrl;

  const _M3uRow({
    required this.index,
    required this.onOpen,
    required this.onDelete,
    required this.onCopyUrl,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final ctrl = IptvController.instance;
    final pl = ctrl.m3uPlaylists[index];

    return _SourceRowShell(
      onOpen: onOpen,
      leading: const _SourceIconTile(icon: Icons.queue_music_rounded),
      title: pl.name,
      subtitle:
          '${context.l10n.iptvChannelsCount(pl.channels.length)}'
          '${pl.sourceUrl != null ? ' · ${pl.sourceUrl!}' : ''}',
      actions: [
        IconButton(
          tooltip: context.l10n.iptvCopyPlaylistUrl,
          icon: Icon(Icons.copy_rounded, color: AppColors.inkSubtle, size: 18),
          onPressed: () {
            final text = pl.sourceUrl ?? '';
            if (text.isNotEmpty) onCopyUrl(text);
          },
        ),
        IconButton(
          tooltip: context.l10n.iptvDeletePlaylist,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// One fixed tile for every source row, so portals and playlists read as
/// the same kind of thing. The row centers it against text of any height;
/// the old green dot sat wherever the row's height put it, which moved
/// with the badges below the title.
class _SourceIconTile extends StatelessWidget {
  final IconData icon;

  const _SourceIconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final palette = AppThemeService.currentPalette.value;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: palette.primaryColor, size: 20),
    );
  }
}

/// The shared row both lists draw: a tap target that opens the source,
/// a title with one subtitle line, optional badges, and one icon per
/// action. The actions used to hide in an overflow menu, which buried the
/// two taps every source needs -- copy the login, remove the source --
/// behind a third tap that named neither.
class _SourceRowShell extends StatelessWidget {
  final VoidCallback onOpen;
  final Widget? leading;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final List<Widget> actions;

  const _SourceRowShell({
    required this.onOpen,
    this.leading,
    required this.title,
    required this.subtitle,
    this.badges = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.inkAlpha(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkAlpha(0.08)),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkAlpha(0.45),
                        fontSize: 11,
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(spacing: 6, runSpacing: 4, children: badges),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// A small tinted label on a portal row: expiry, connections, or the source
/// the portal was found through.
class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
