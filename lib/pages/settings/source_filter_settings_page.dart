import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/sources/source_filter_settings.dart';
import '../../services/theme/app_colors.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/setting_choice_chip.dart';
import '../../widgets/settings/settings_scroll_view.dart';

/// The one place the source-list filters are set as a global default.
///
/// The Watch screen still carries the same two dropdowns, so the filter can
/// be changed while browsing sources; both write through
/// [SourceFilterSettings], so this page and that dropdown always agree.
///
/// This one has state because of the preferred-audio ranking, the only
/// filter with an order: it needs to repaint when a language is promoted or
/// demoted, and it owns the subscription that makes that happen.
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
    // The ranked list is the one filter with its own reordering UI, so this
    // page listens to it directly rather than wrapping the whole body in a
    // third ValueListenableBuilder.
    SourceFilterSettings.preferredAudioLanguages.addListener(_onChanged);
  }

  @override
  void dispose() {
    SourceFilterSettings.preferredAudioLanguages.removeListener(_onChanged);
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
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.sourceFilterTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: ValueListenableBuilder<String>(
          valueListenable: SourceFilterSettings.audioLanguage,
          builder: (context, audioKey, __) {
            return ValueListenableBuilder<String>(
              valueListenable: SourceFilterSettings.quality,
              builder: (context, qualityKey, _) {
                return SettingsScrollView(
                  maxContentWidth: 820,
                  bottomPadding: 32 + bottomInset,
                  children: [
                    _buildIntroCard(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader(l10n.sourceFilterAudioSection),
                    const SizedBox(height: 12),
                    _buildAudioCard(context, audioKey),
                    const SizedBox(height: 24),
                    _buildSectionHeader(l10n.sourceFilterQualitySection),
                    const SizedBox(height: 12),
                    _buildQualityCard(context, qualityKey),
                    const SizedBox(height: 24),
                    _buildSectionHeader(l10n.sourceFilterPreferredSection),
                    const SizedBox(height: 12),
                    _buildPreferredAudioCard(context),
                    const SizedBox(height: 32),
                    _buildResetButton(context),
                    const SizedBox(height: 16),
                  ],
                );
              },
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.withValues(alpha: 0.16),
            palette.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: palette.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.filter_alt_rounded,
              color: palette,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.sourceFilterIntro,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
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
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.inkAlpha(0.35),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildAudioCard(BuildContext context, String selectedKey) {
    final l10n = context.l10n;
    return _buildCard(
      title: l10n.sourceFilterAudioBody,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kAudioFilterKeys
            .map(
              (key) => SettingChoiceChip(
                label: audioFilterLabel(l10n, key),
                selected: selectedKey == key,
                onSelect: () => SourceFilterSettings.setAudioLanguage(key),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildQualityCard(BuildContext context, String selectedKey) {
    final l10n = context.l10n;
    return _buildCard(
      title: l10n.sourceFilterQualityBody,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kQualityFilterKeys
            .map(
              (key) => SettingChoiceChip(
                label: qualityFilterLabel(l10n, key),
                selected: selectedKey == key,
                onSelect: () => SourceFilterSettings.setQuality(key),
              ),
            )
            .toList(),
      ),
    );
  }

  /// The ranked list, above the full catalogue of choosable languages.
  ///
  /// Two blocks rather than one, because the two do different jobs: the top
  /// one is what the player will actually do, in order; the bottom is the
  /// menu of everything you can add to it. Selected languages are removed
  /// from the bottom row so the same chip never appears twice with two
  /// different meanings.
  Widget _buildPreferredAudioCard(BuildContext context) {
    final l10n = context.l10n;
    final ranked = SourceFilterSettings.preferredAudioLanguages.value;
    final available = kPreferredAudioLanguageKeys
        .where((key) => !ranked.contains(key))
        .toList();

    return _buildCard(
      title: l10n.sourceFilterPreferredBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ranked.isEmpty)
            Text(
              l10n.sourceFilterPreferredEmpty,
              style: TextStyle(
                fontSize: 13,
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
              const SizedBox(height: 12),
              Divider(color: AppColors.inkAlpha(0.08), height: 1),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available
                  .map(
                    (key) => SettingChoiceChip(
                      label: preferredAudioLabel(l10n, key),
                      selected: false,
                      onSelect: () =>
                          SourceFilterSettings.togglePreferredAudio(key),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.inkAlpha(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              preferredAudioLabel(l10n, key),
              style: TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ),
          IconButton(
            tooltip: l10n.sourceFilterPreferredUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            onPressed: index == 0
                ? null
                : () => SourceFilterSettings.promotePreferredAudio(key),
          ),
          IconButton(
            tooltip: l10n.sourceFilterPreferredDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: index == total - 1
                ? null
                : () => SourceFilterSettings.demotePreferredAudio(key),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => SourceFilterSettings.togglePreferredAudio(key),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.inkAlpha(0.5),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.restart_alt_rounded, size: 18),
        label: Text(context.l10n.sourceFilterResetButton),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkMuted,
          side: BorderSide(color: AppColors.inkAlpha(0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => SourceFilterSettings.reset(),
      ),
    );
  }
}