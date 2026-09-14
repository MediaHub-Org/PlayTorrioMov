import 'package:flutter/material.dart';
import '../../models/addon/addon.dart';
import '../../services/addon/addon_manager.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';

class AddonsSettingsPage extends StatefulWidget {
  const AddonsSettingsPage({super.key});

  @override
  State<AddonsSettingsPage> createState() => _AddonsSettingsPageState();
}

class _AddonsSettingsPageState extends State<AddonsSettingsPage> {
  final _manager = AddonManager.instance;
  bool _isAdding = false;

  Future<void> _addAddon() async {
    final url = await _showAddDialog();
    if (url == null || url.trim().isEmpty) return;

    setState(() => _isAdding = true);

    try {
      final addon = await _manager.addAddon(url);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${addon.manifest.name} installed successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<String?> _showAddDialog() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Stremio Addon',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the Stremio addon manifest.json URL to install catalogs, metadata, streams, or subtitles.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkAlpha(0.50),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: 13.5, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'https://opensubtitles-v3.strem.io/manifest.json',
                  hintStyle: TextStyle(
                    color: AppColors.inkAlpha(0.22),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: AppColors.bar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.inkAlpha(0.10),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.inkAlpha(0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.inkAlpha(0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Install',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemove(InstalledAddon addon) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Remove ${addon.manifest.name}?'),
          content: Text(
            'Its catalogs and metadata will be removed from your home page.',
            style: TextStyle(color: AppColors.inkAlpha(0.55), fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.inkAlpha(0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _manager.removeAddon(addon.manifest.id);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Remove',
                style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final addons = _manager.addons;

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
          'Addons',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // Description
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              'Addons provide movie, series, and anime metadata catalogs for your home page and search.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.inkAlpha(0.5),
                height: 1.4,
              ),
            ),
          ),

          // Add Addon Button
          _AddAddonButton(isLoading: _isAdding, onTap: _addAddon),
          const SizedBox(height: 24),

          // Section Header
          Row(
            children: [
              Text(
                'INSTALLED ADDONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkAlpha(0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${addons.length} Total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Addons List or Empty State
          if (addons.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inkAlpha(0.06)),
              ),
              child: Column(
                children: [
                  Icon(Icons.extension_off_rounded, size: 40, color: AppColors.inkAlpha(0.25)),
                  const SizedBox(height: 12),
                  Text(
                    'No Addons Installed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click "Add Addon" above to install a Stremio manifest URL.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkAlpha(0.4)),
                  ),
                ],
              ),
            )
          else
            ...addons.map(
              (addon) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddonCard(
                  addon: addon,
                  onToggle: (enabled) async {
                    await _manager.toggleAddon(addon.manifest.id, enabled);
                    setState(() {});
                  },
                  onUpdateFeature: ({
                    enableCatalogs,
                    enableSearch,
                    enableSubtitles,
                    enableStreams,
                  }) async {
                    await _manager.updateAddonFeature(
                      addonId: addon.manifest.id,
                      enableCatalogs: enableCatalogs,
                      enableSearch: enableSearch,
                      enableSubtitles: enableSubtitles,
                      enableStreams: enableStreams,
                    );
                    setState(() {});
                  },
                  onRemove: () => _confirmRemove(addon),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Addon Card
// ─────────────────────────────────────────────────────────────────────────────

class _AddonCard extends StatelessWidget {
  final InstalledAddon addon;
  final ValueChanged<bool> onToggle;
  final void Function({
    bool? enableCatalogs,
    bool? enableSearch,
    bool? enableSubtitles,
    bool? enableStreams,
  }) onUpdateFeature;
  final VoidCallback onRemove;

  const _AddonCard({
    required this.addon,
    required this.onToggle,
    required this.onUpdateFeature,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final m = addon.manifest;

    final hasCatalogs = m.supportsCatalog || m.catalogs.isNotEmpty;
    final hasSearch = m.catalogs.any((c) => c.supportsSearch) || m.supportsCatalog;
    final hasStreams = m.supportsStream;
    final hasSubtitles = m.supportsSubtitles;
    final hasAnyFeature = hasCatalogs || hasSearch || hasStreams || hasSubtitles;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: addon.enabled
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.inkAlpha(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.supportsSubtitles && m.catalogs.isEmpty
                          ? 'v${m.version}  ·  Subtitles Provider'
                          : 'v${m.version}  ·  ${m.catalogs.length} catalog${m.catalogs.length == 1 ? '' : 's'}${m.supportsSubtitles ? '  ·  Subtitles' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkAlpha(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: addon.enabled,
                onChanged: onToggle,
                activeColor: AppColors.accent,
              ),
            ],
          ),

          // Description
          if (m.description != null && m.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              m.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.inkAlpha(0.45),
                height: 1.35,
              ),
            ),
          ],

          // Feature Toggles Section
          if (addon.enabled && hasAnyFeature) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.inkAlpha(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: AppColors.inkAlpha(0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'FUNCTIONS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.inkAlpha(0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasCatalogs)
                        _FeatureToggleChip(
                          icon: Icons.grid_view_rounded,
                          label: 'Catalogs',
                          count: m.catalogs.isNotEmpty ? m.catalogs.length : null,
                          isEnabled: addon.enableCatalogs,
                          onTap: () => onUpdateFeature(
                            enableCatalogs: !addon.enableCatalogs,
                          ),
                        ),
                      if (hasSearch)
                        _FeatureToggleChip(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          isEnabled: addon.enableSearch,
                          onTap: () => onUpdateFeature(
                            enableSearch: !addon.enableSearch,
                          ),
                        ),
                      if (hasStreams)
                        _FeatureToggleChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Sources',
                          isEnabled: addon.enableStreams,
                          onTap: () => onUpdateFeature(
                            enableStreams: !addon.enableStreams,
                          ),
                        ),
                      if (hasSubtitles)
                        _FeatureToggleChip(
                          icon: Icons.subtitles_rounded,
                          label: 'Subtitles',
                          isEnabled: addon.enableSubtitles,
                          onTap: () => onUpdateFeature(
                            enableSubtitles: !addon.enableSubtitles,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Type badges + Remove
          Row(
            children: [
              ...m.types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inkAlpha(0.06),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkAlpha(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red.withValues(alpha: 0.6),
                onPressed: onRemove,
                tooltip: 'Remove addon',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureToggleChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool isEnabled;
  final VoidCallback onTap;

  const _FeatureToggleChip({
    required this.icon,
    required this.label,
    this.count,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  State<_FeatureToggleChip> createState() => _FeatureToggleChipState();
}

class _FeatureToggleChipState extends State<_FeatureToggleChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.accent;
    final isEnabled = widget.isEnabled;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? (_hovered
                    ? activeColor.withValues(alpha: 0.25)
                    : activeColor.withValues(alpha: 0.15))
                : (_hovered
                    ? AppColors.inkAlpha(0.08)
                    : AppColors.inkAlpha(0.03)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isEnabled
                  ? activeColor.withValues(alpha: 0.50)
                  : AppColors.inkAlpha(0.08),
              width: 1,
            ),
            boxShadow: isEnabled && _hovered
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: isEnabled
                    ? activeColor
                    : AppColors.inkAlpha(0.35),
              ),
              const SizedBox(width: 6),
              Text(
                widget.count != null
                    ? '${widget.label} (${widget.count})'
                    : widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                  color: isEnabled
                      ? AppColors.ink
                      : AppColors.inkAlpha(0.45),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isEnabled
                    ? Icons.check_circle_rounded
                    : Icons.cancel_outlined,
                size: 13,
                color: isEnabled
                    ? const Color(0xFF34D399)
                    : AppColors.inkAlpha(0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Addon Button
// ─────────────────────────────────────────────────────────────────────────────

class _AddAddonButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _AddAddonButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.25),
          ),
          color: AppColors.accent.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              Icon(Icons.add_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Installing...' : 'Add Addon',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
