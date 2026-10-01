import '../../widgets/common/focus_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../models/addon/addon.dart';
import '../../services/addon/addon_manager.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../widgets/common/hover_button.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

/// The keys that activate a focused [_FeatureToggleChip]. `final`, not
/// `const`: `LogicalKeyboardKey` overrides `==`, and the analyzer rejects
/// that inside a `const` set literal.
final _activators = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.gameButtonA,
};

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
          content: Text(
            context.l10n.addonsInstalledSuccess(addon.manifest.name),
          ),
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
    final l10n = context.l10n;
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rem(1.25)),
          ),
          title: Text(
            l10n.addonsAddDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.addonsAddDialogBody,
                style: TextStyle(
                  fontSize: AppType.small,
                  color: AppColors.inkAlpha(0.50),
                  height: 1.35, // ratio: a line height, not a size
                ),
              ),
              SizedBox(height: context.rem(AppRem.md)),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: AppType.smallPlus, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'https://opensubtitles-v3.strem.io/manifest.json',
                  hintStyle: TextStyle(
                    color: AppColors.inkAlpha(0.22),
                    fontSize: AppType.captionPlus,
                  ),
                  filled: true,
                  fillColor: AppColors.bar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    borderSide: BorderSide(
                      color: AppColors.inkAlpha(0.10),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    borderSide: BorderSide(
                      color: AppColors.inkAlpha(0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.rem(AppRem.md),
                    vertical: context.rem(0.875),
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
                l10n.addonsCancel,
                style: TextStyle(color: AppColors.inkAlpha(0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: context.rem(1.25),
                  vertical: context.rem(AppRem.ms),
                ),
              ),
              child: Text(
                l10n.addonsInstall,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.small,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemove(InstalledAddon addon) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
          ),
          title: Text(l10n.addonsRemoveConfirm(addon.manifest.name)),
          content: Text(
            l10n.addonsRemoveConfirmBody,
            style: TextStyle(color: AppColors.inkAlpha(0.55), fontSize: AppType.smallPlus),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.addonsCancel,
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
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                ),
              ),
              child: Text(
                l10n.addonsRemove,
                style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    final addons = _manager.addons;

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
          l10n.settingsCategoryAddons,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // Description
          Padding(
            padding: EdgeInsets.only(bottom: context.rem(1.25)),
            child: Text(
              l10n.addonsIntro,
              style: TextStyle(
                fontSize: AppType.smallPlus,
                color: AppColors.inkAlpha(0.5),
                height: 1.4, // ratio: a line height, not a size
              ),
            ),
          ),

          // Add Addon Button
          _AddAddonButton(isLoading: _isAdding, onTap: _addAddon),
          SizedBox(height: context.rem(AppRem.lg)),

          // Section Header
          Row(
            children: [
              Text(
                l10n.addonsInstalledHeader,
                style: TextStyle(
                  fontSize: AppType.caption,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkAlpha(0.35),
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(AppRem.xxs)),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                ),
                child: Text(
                  l10n.addonsTotalBadge(addons.length),
                  style: TextStyle(
                    fontSize: AppType.tiny,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rem(AppRem.ms)),

          // Addons List or Empty State
          if (addons.isEmpty)
            Container(
              padding: EdgeInsets.all(context.rem(1.75)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                border: Border.all(color: AppColors.inkAlpha(0.06)),
              ),
              child: Column(
                children: [
                  Icon(Icons.extension_off_rounded, size: context.rem(2.5), color: AppColors.inkAlpha(0.25)),
                  SizedBox(height: context.rem(AppRem.ms)),
                  Text(
                    l10n.addonsEmptyTitle,
                    style: TextStyle(fontSize: AppType.bodyLg, fontWeight: FontWeight.bold, color: AppColors.inkMuted),
                  ),
                  SizedBox(height: context.rem(AppRem.snug)),
                  Text(
                    l10n.addonsEmptyBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppType.captionPlus, color: AppColors.inkAlpha(0.4)),
                  ),
                ],
              ),
            )
          else
            ...addons.map(
              (addon) => Padding(
                padding: EdgeInsets.only(bottom: context.rem(AppRem.ms)),
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
    AppColors.dependOn(context);
    final l10n = context.l10n;
    final m = addon.manifest;

    final hasCatalogs = m.supportsCatalog || m.catalogs.isNotEmpty;
    final hasSearch = m.catalogs.any((c) => c.supportsSearch) || m.supportsCatalog;
    final hasStreams = m.supportsStream;
    final hasSubtitles = m.supportsSubtitles;
    final hasAnyFeature = hasCatalogs || hasSearch || hasStreams || hasSubtitles;

    // The version line is assembled from translated parts rather than
    // interpolated into one English sentence, because the count's plural
    // form differs in the other three languages and `·` is a separator, not
    // text. `addonsFeatureCatalogCount` carries the plural.
    final versionLine = StringBuffer('v${m.version}  \u00b7  ');
    if (m.supportsSubtitles && m.catalogs.isEmpty) {
      versionLine.write(l10n.addonsFeatureSubtitlesProvider);
    } else {
      versionLine.write(l10n.addonsFeatureCatalogCount(m.catalogs.length));
      if (m.supportsSubtitles) {
        versionLine.write('  \u00b7  ${l10n.addonsFeatureSubtitles}');
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
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
                width: context.rem(2.625),
                height: context.rem(2.625),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: AppColors.accent,
                  size: context.rem(AppRem.iconMd),
                ),
              ),
              SizedBox(width: context.rem(AppRem.ms)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: AppType.bodyMdPlus,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: context.rem(AppRem.xxs)),
                    Text(
                      versionLine.toString(),
                      style: TextStyle(
                        fontSize: AppType.caption,
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
            SizedBox(height: context.rem(0.625)),
            Text(
              m.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppType.captionPlus,
                color: AppColors.inkAlpha(0.45),
                height: 1.35, // ratio: a line height, not a size
              ),
            ),
          ],

          // Feature Toggles Section
          if (addon.enabled && hasAnyFeature) ...[
            SizedBox(height: context.rem(0.875)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(0.625)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
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
                        size: context.rem(0.8125),
                        color: AppColors.inkAlpha(0.45),
                      ),
                      SizedBox(width: context.rem(0.3125)),
                      Text(
                        l10n.addonsFunctionsHeader,
                        style: TextStyle(
                          fontSize: TvType.scale(AppType.microPlus),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.inkAlpha(0.45),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rem(AppRem.sm)),
                  Wrap(
                    spacing: context.rem(AppRem.sm),
                    runSpacing: context.rem(AppRem.sm),
                    children: [
                      if (hasCatalogs)
                        _FeatureToggleChip(
                          icon: Icons.grid_view_rounded,
                          label: l10n.addonsFeatureCatalogs,
                          count: m.catalogs.isNotEmpty ? m.catalogs.length : null,
                          isEnabled: addon.enableCatalogs,
                          onTap: () => onUpdateFeature(
                            enableCatalogs: !addon.enableCatalogs,
                          ),
                        ),
                      if (hasSearch)
                        _FeatureToggleChip(
                          icon: Icons.search_rounded,
                          label: l10n.addonsFeatureSearch,
                          isEnabled: addon.enableSearch,
                          onTap: () => onUpdateFeature(
                            enableSearch: !addon.enableSearch,
                          ),
                        ),
                      if (hasStreams)
                        _FeatureToggleChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: l10n.addonsFeatureSources,
                          isEnabled: addon.enableStreams,
                          onTap: () => onUpdateFeature(
                            enableStreams: !addon.enableStreams,
                          ),
                        ),
                      if (hasSubtitles)
                        _FeatureToggleChip(
                          icon: Icons.subtitles_rounded,
                          label: l10n.addonsFeatureSubtitles,
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

          SizedBox(height: context.rem(AppRem.ms)),

          // Type badges + Remove
          Row(
            children: [
              ...m.types.map(
                (type) => Padding(
                  padding: EdgeInsetsDirectional.only(end: context.rem(AppRem.snug)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rem(0.5625),
                      vertical: context.rem(0.2188),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inkAlpha(0.06),
                      borderRadius: BorderRadius.circular(context.rem(0.4375)),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: AppType.tiny,
                        color: AppColors.inkAlpha(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: context.rem(AppRem.icon)),
                color: Colors.red.withValues(alpha: 0.6),
                onPressed: onRemove,
                tooltip: context.l10n.addonsRemoveTooltip,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: context.rem(2.25), minHeight: context.rem(2.25)),
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
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_activators.contains(event.logicalKey)) return KeyEventResult.ignored;
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final activeColor = AppColors.accent;
    final isEnabled = widget.isEnabled;
    final hovered = _hovered || _focused;

    return FocusFill(
      radius: context.rem(0.5625),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _handleKey,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.625), vertical: context.rem(AppRem.snug)),
            decoration: BoxDecoration(
              color: isEnabled
                  ? (hovered
                      ? activeColor.withValues(alpha: 0.25)
                      : activeColor.withValues(alpha: 0.15))
                  : (hovered
                      ? AppColors.inkAlpha(0.08)
                      : AppColors.inkAlpha(0.03)),
              borderRadius: BorderRadius.circular(context.rem(0.5625)),
              border: Border.all(
                color: isEnabled
                    ? activeColor.withValues(alpha: 0.50)
                    : AppColors.inkAlpha(0.08),
                width: 1, // px: a hairline, not a layout size
              ),
              boxShadow: isEnabled && hovered
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.25),
                        blurRadius: context.rem(AppRem.sm),
                        offset: Offset(0, context.rem(AppRem.xxs)),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: context.rem(0.875),
                  color: isEnabled
                      ? activeColor
                      : AppColors.inkAlpha(0.35),
                ),
                SizedBox(width: context.rem(AppRem.snug)),
                Text(
                  widget.count != null
                      ? '${widget.label} (${widget.count})'
                      : widget.label,
                  style: TextStyle(
                    fontSize: AppType.caption,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                    color: isEnabled
                        ? AppColors.ink
                        : AppColors.inkAlpha(0.45),
                  ),
                ),
                SizedBox(width: context.rem(AppRem.snug)),
                Icon(
                  isEnabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  size: context.rem(0.8125),
                  color: isEnabled
                      ? const Color(0xFF34D399)
                      : AppColors.inkAlpha(0.25),
                ),
              ],
            ),
          ),
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
    AppColors.dependOn(context);
    return IgnorePointer(
      ignoring: isLoading,
      child: ExcludeFocus(
        excluding: isLoading,
        child: HoverButton(
      scaleAmount: 1.02,
      showFocusRing: true,
      focusRingBorderRadius: context.rem(AppRem.radiusLg) + context.rem(AppRem.xxs),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: context.rem(1.25)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
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
                width: context.rem(1.25),
                height: context.rem(1.25),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              Icon(Icons.add_rounded, color: AppColors.accent, size: context.rem(AppRem.iconMd)),
            SizedBox(width: context.rem(0.625)),
            Text(
              isLoading ? context.l10n.addonsInstalling : context.l10n.addonsAdd,
              style: TextStyle(
                fontSize: AppType.bodyPlus,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}
