import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/sources/source_filter_settings.dart';
import '../../services/theme/app_colors.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/setting_choice_chip.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/app_units.dart';

/// The one place the source-list filters are set as a global default.
///
/// The Watch screen still carries the same two filters, so they can be
/// changed while browsing sources; both write through [SourceFilterSettings],
/// so this page and that menu always agree.
///
/// Two blocks, not three. There used to be a single-select audio *filter*, a
/// single-select quality filter, and a separate ordered *preferred audio*
/// ranking -- and the first and third both said "audio language" while doing
/// different jobs, which read as three unrelated settings. The audio filter
/// and the ranking are one list now: pick the languages you want, and the
/// source list shows sources matching any of them while the player prefers
/// them in the order you put them.
///
/// This one has state because of that order: it needs to repaint when a
/// language is promoted or demoted, and it owns the subscription that makes
/// that happen.
class SourceFilterSettingsPage extends StatefulWidget {
  const SourceFilterSettingsPage({super.key});

  @override
  State<SourceFilterSettingsPage> createState() =>
      _SourceFilterSettingsPageState();
}

class _SourceFilterSettingsPageState extends State<SourceFilterSettingsPage> {
  @override
  void initState() {
    super.initState();
    // The audio list is the one with its own reordering UI, so this page
    // listens to it directly rather than wrapping the whole body in a third
    // ValueListenableBuilder.
    SourceFilterSettings.audioLanguages.addListener(_onChanged);
  }

  @override
  void dispose() {
    SourceFilterSettings.audioLanguages.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bar.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.sourceFilterTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: ValueListenableBuilder<List<String>>(
          valueListenable: SourceFilterSettings.qualities,
          builder: (context, qualityKeys, __) {
            return SettingsScrollView(
              maxContentWidth: 820,
              bottomPadding: 32 + bottomInset,
              children: [
                _buildIntroCard(context),
                SizedBox(height: context.rem(AppRem.lg)),
                _buildSectionHeader(l10n.sourceFilterAudioSection),
                SizedBox(height: context.rem(AppRem.ms)),
                _buildAudioCard(context),
                SizedBox(height: context.rem(AppRem.lg)),
                _buildSectionHeader(l10n.sourceFilterQualitySection),
                SizedBox(height: context.rem(AppRem.ms)),
                _buildQualityCard(context, qualityKeys),
                SizedBox(height: context.rem(AppRem.xl)),
                _buildResetButton(context),
                SizedBox(height: context.rem(AppRem.md)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    final l10n = context.l10n;
    final palette = AppColors.accent;
    return Container(
      padding: EdgeInsets.all(context.rem(1.125)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.withValues(alpha: 0.16),
            palette.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusXl)),
        border: Border.all(color: palette.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: context.rem(2.875),
            height: context.rem(2.875),
            decoration: BoxDecoration(
              color: palette.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(context.rem(0.875)),
            ),
            child: Icon(
              Icons.filter_alt_rounded,
              color: palette,
              size: context.rem(1.625),
            ),
          ),
          SizedBox(width: context.rem(0.875)),
          Expanded(
            child: Text(
              l10n.sourceFilterIntro,
              style: TextStyle(
                fontSize: AppType.small,
                height: 1.4, // ratio: a line height, not a size
                color: AppColors.inkAlpha(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: context.rem(AppRem.xs)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppType.caption,
          fontWeight: FontWeight.w700,
          color: AppColors.inkAlpha(0.35),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// The audio list: the ranked selection on top, the rest of the catalog
  /// below it.
  ///
  /// Two blocks rather than one, because the two do different jobs: the top
  /// one is what the player will actually do, in order; the bottom is the
  /// menu of everything you can add to it. Selected languages are removed
  /// from the bottom row so the same chip never appears twice with two
  /// different meanings.
  Widget _buildAudioCard(BuildContext context) {
    final l10n = context.l10n;
    final ranked = SourceFilterSettings.audioLanguages.value;
    final available = kAudioFilterKeys
        .where((key) => !ranked.contains(key))
        .toList();

    return _buildCard(
      title: l10n.sourceFilterAudioBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ranked.isEmpty)
            Text(
              l10n.sourceFilterPreferredEmpty,
              style: TextStyle(
                fontSize: AppType.small,
                color: AppColors.inkAlpha(0.5),
              ),
            )
          else
            ...ranked.asMap().entries.map(
              (entry) => _buildRankedRow(
                context,
                entry.key,
                entry.value,
                ranked.length,
              ),
            ),
          if (available.isNotEmpty) ...[
            if (ranked.isNotEmpty) ...[
              SizedBox(height: context.rem(AppRem.ms)),
              Divider(color: AppColors.inkAlpha(0.08), height: 1), // px: a hairline, not a layout size
              SizedBox(height: context.rem(AppRem.ms)),
            ],
            Wrap(
              spacing: context.rem(AppRem.sm),
              runSpacing: context.rem(AppRem.sm),
              children: available
                  .map(
                    (key) => SettingChoiceChip(
                      label: audioFilterLabel(l10n, key),
                      selected: false,
                      multiSelect: true,
                      onSelect: () =>
                          SourceFilterSettings.toggleAudioLanguage(key),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityCard(BuildContext context, List<String> selectedKeys) {
    final l10n = context.l10n;
    return _buildCard(
      title: l10n.sourceFilterQualityBody,
      child: Wrap(
        spacing: context.rem(AppRem.sm),
        runSpacing: context.rem(AppRem.sm),
        children: kQualityFilterKeys
            .map(
              (key) => SettingChoiceChip(
                label: qualityFilterLabel(l10n, key),
                selected: selectedKeys.contains(key),
                multiSelect: true,
                onSelect: () => SourceFilterSettings.toggleQuality(key),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRankedRow(
    BuildContext context,
    int index,
    String key,
    int total,
  ) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(AppRem.sm)),
      child: Row(
        children: [
          Container(
            constraints: BoxConstraints(minWidth: context.rem(AppRem.lg), minHeight: context.rem(AppRem.lg)),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.inkAlpha(0.08),
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: AppType.caption,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          SizedBox(width: context.rem(0.625)),
          Expanded(
            child: Text(
              audioFilterLabel(l10n, key),
              style: TextStyle(fontSize: AppType.body, color: AppColors.ink),
            ),
          ),
          IconButton(
            tooltip: l10n.sourceFilterPreferredUp,
            icon: Icon(Icons.keyboard_arrow_up_rounded, size: context.rem(AppRem.icon)),
            onPressed: index == 0
                ? null
                : () => SourceFilterSettings.promoteAudioLanguage(key),
          ),
          IconButton(
            tooltip: l10n.sourceFilterPreferredDown,
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: context.rem(AppRem.icon)),
            onPressed: index == total - 1
                ? null
                : () => SourceFilterSettings.demoteAudioLanguage(key),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            icon: Icon(Icons.close_rounded, size: context.rem(AppRem.iconSm)),
            onPressed: () => SourceFilterSettings.toggleAudioLanguage(key),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppType.caption,
              color: AppColors.inkAlpha(0.5),
              height: 1.3, // ratio: a line height, not a size
            ),
          ),
          SizedBox(height: context.rem(0.875)),
          child,
        ],
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        icon: Icon(Icons.restart_alt_rounded, size: context.rem(AppRem.iconSm)),
        label: Text(context.l10n.sourceFilterResetButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkMuted,
          side: BorderSide(color: AppColors.inkAlpha(0.15)),
          padding: EdgeInsets.symmetric(horizontal: context.rem(1.25), vertical: context.rem(0.875)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.rem(0.875)),
          ),
        ),
        onPressed: () => SourceFilterSettings.reset(),
      ),
    );
  }
}