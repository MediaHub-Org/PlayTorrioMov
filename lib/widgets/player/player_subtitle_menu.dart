import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/subtitle/subtitle_model.dart';
import 'language_flag.dart';
import 'player_glass.dart';
import 'player_menu_row.dart';
import 'player_sub_style_modal.dart' show SubtitleStyleEditor;

/// Subtitle on/off and the language list.
///
/// Rows are languages, not files. Four OpenSubtitles files for Arabic are one
/// row with a count; picking it takes the best of them. The files themselves
/// -- their provider, format, quality and release tags -- are not shown,
/// because none of it changes which language a viewer wants, and a list of
/// them buried the languages it was supposed to be listing.
///
/// The appearance editor still opens in place rather than over the video:
/// a pop-up hid the subtitles it exists to style.
class PlayerSubtitleMenu extends StatefulWidget {
  final List<SubtitleLanguageGroup> groups;
  final List<PlayerEmbeddedSubtitle> embeddedSubtitles;
  final int? selectedEmbeddedIndex;
  final SubtitleVariant? selectedVariant;
  final bool isSubtitleEnabled;
  final double delaySec;
  final ValueChanged<SubtitleVariant> onSelectVariant;
  final ValueChanged<PlayerEmbeddedSubtitle> onSelectEmbedded;

  /// Turns subtitles on, choosing the track for the language being heard.
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onOpenSyncBar;

  /// Re-runs the online subtitle search. The player scrapes once when it
  /// opens a stream; this is the manual retry for when that came back thin.
  final VoidCallback? onRefresh;

  /// Told when the appearance editor opens or closes, so the player can show
  /// sample subtitles while it is open.
  final ValueChanged<bool>? onAppearanceOpenChanged;

  /// The media player, for the appearance editor's live preview.
  final dynamic player;

  final VoidCallback? onBack;

  const PlayerSubtitleMenu({
    super.key,
    this.groups = const [],
    this.embeddedSubtitles = const [],
    this.selectedEmbeddedIndex,
    this.selectedVariant,
    required this.isSubtitleEnabled,
    this.delaySec = 0,
    required this.onSelectVariant,
    required this.onSelectEmbedded,
    required this.onEnable,
    required this.onDisable,
    required this.onOpenSyncBar,
    this.onRefresh,
    this.onAppearanceOpenChanged,
    this.player,
    this.onBack,
  });

  @override
  State<PlayerSubtitleMenu> createState() => _PlayerSubtitleMenuState();
}

class _PlayerSubtitleMenuState extends State<PlayerSubtitleMenu> {
  bool _showAppearance = false;

  /// Which list is showing. Opens on Embedded when the file has any, since
  /// those are already there and play instantly; otherwise on Online.
  late _SubtitleSource _source = widget.embeddedSubtitles.isNotEmpty
      ? _SubtitleSource.embedded
      : _SubtitleSource.online;

  _SubtitleFilter _filter = _SubtitleFilter.all;

  void _setAppearance(bool open) {
    setState(() => _showAppearance = open);
    widget.onAppearanceOpenChanged?.call(open);
  }

  @override
  void dispose() {
    // The menu can close with the editor still open; the sample subtitles
    // must not outlive it. After the frame, because this runs while the tree
    // is being torn down and the callback calls setState.
    final onChanged = widget.onAppearanceOpenChanged;
    if (_showAppearance && onChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    // One fixed height for both states. The panel used to resize when the
    // appearance editor opened, which slid the whole thing up the screen
    // under the viewer's cursor -- and the editor's own `Expanded` rows need
    // a bounded height anyway, so the fixed height is doing two jobs.
    final cardHeight = (screen.height - 160).clamp(280.0, 460.0);

    return PlayerGlassCard(
      width: PlayerTheme.menuWidthFor(context),
      height: cardHeight,
      padding: const EdgeInsets.all(10),
      child: _showAppearance
          ? _buildAppearanceEditor(context)
          : _buildTrackList(context),
    );
  }

  /// The appearance editor. It fills the card, which is what gives its
  /// `Expanded` rows a height to share.
  Widget _buildAppearanceEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PlayerIconButton(
              size: 28,
              iconSize: 14,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: context.l10n.subsBackToSubtitles,
              onPressed: () => _setAppearance(false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: PlayerMenuHeader(
                title: context.l10n.subsAppearance.toUpperCase(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(child: SubtitleStyleEditor(player: widget.player)),
      ],
    );
  }

  Widget _buildTrackList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.onBack != null) ...[
              PlayerIconButton(
                size: 28,
                iconSize: 14,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: context.l10n.playerBackToSettings,
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: PlayerMenuHeader(
                title: context.l10n.detailsSubtitles.toUpperCase(),
              ),
            ),
            // The three actions, in the header's right corner. They were a
            // row of their own under the toggle, which cost a line of height
            // and read as a second set of choices rather than as actions on
            // the list below.
            PlayerIconButton(
              size: 28,
              iconSize: 15,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.l10n.subsRefreshOnline,
              onPressed: widget.onRefresh,
            ),
            const SizedBox(width: 2),
            PlayerIconButton(
              size: 28,
              iconSize: 15,
              icon: const Icon(Icons.timer_outlined),
              tooltip: context.l10n.subsSyncBar,
              showActiveBadge: widget.delaySec != 0,
              onPressed: widget.selectedEmbeddedIndex != null
                  ? null
                  : widget.onOpenSyncBar,
            ),
            const SizedBox(width: 2),
            PlayerIconButton(
              size: 28,
              iconSize: 15,
              icon: const Icon(Icons.tune_rounded),
              tooltip: context.l10n.subsAppearanceTooltip,
              onPressed: () => _setAppearance(true),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // One button, two states. It reads "Turn subtitles off" while they
        // are on and "Turn subtitles on" while they are off, so the label
        // always names where a press takes you rather than where you are.
        _SubtitleToggleButton(
          isEnabled: widget.isSubtitleEnabled,
          onPressed: widget.isSubtitleEnabled
              ? widget.onDisable
              : widget.onEnable,
        ),

        const SizedBox(height: 8),
        _buildSourceTabs(context),
        const SizedBox(height: 6),
        _buildFilterChips(context),
        const SizedBox(height: 6),
        const Divider(color: PlayerTheme.edgeSoft, height: 1),
        const SizedBox(height: 6),

        // Expanded, not a bounded scroll box: the rows take whatever is left
        // under the controls and scroll within it, so a one-language list
        // does not leave a gap and a long one does not shorten the card.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildRows(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Embedded / Online, as two tabs rather than one merged list.
  ///
  /// They are different kinds of thing: an embedded track is already in the
  /// file and plays instantly, an online one has to be fetched. Merging them
  /// meant the file's own tracks -- usually the answer -- were mixed in with
  /// a hundred downloads, so the tabs separate the two questions.
  Widget _buildSourceTabs(BuildContext context) {
    final hasEmbedded = widget.embeddedSubtitles.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: context.l10n.subsEmbedded,
            count: widget.embeddedSubtitles.length,
            isSelected: _source == _SubtitleSource.embedded,
            onTap: () => setState(() => _source = _SubtitleSource.embedded),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _TabButton(
            label: context.l10n.subsOnline,
            count: widget.groups.fold(0, (s, g) => s + g.variants.length),
            isSelected: _source == _SubtitleSource.online,
            onTap: () => setState(() => _source = _SubtitleSource.online),
          ),
        ),
        // A file with no embedded tracks has nothing to show on that tab, so
        // it opens on Online rather than on an empty list.
        if (!hasEmbedded && _source == _SubtitleSource.embedded)
          const SizedBox.shrink(),
      ],
    );
  }

  /// All / CC-SDH / Forced, filtering whichever tab is showing.
  Widget _buildFilterChips(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: context.l10n.subsAll,
          isSelected: _filter == _SubtitleFilter.all,
          onTap: () => setState(() => _filter = _SubtitleFilter.all),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: context.l10n.subsSdhShort,
          isSelected: _filter == _SubtitleFilter.sdh,
          onTap: () => setState(() => _filter = _SubtitleFilter.sdh),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: context.l10n.subsForced,
          isSelected: _filter == _SubtitleFilter.forced,
          onTap: () => setState(() => _filter = _SubtitleFilter.forced),
        ),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context) {
    final rows = <Widget>[];

    if (_source == _SubtitleSource.embedded) {
      final embedded = [...widget.embeddedSubtitles]
        ..sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
      for (final track in embedded) {
        if (!_passesFilter(
          isForced: track.isForced,
          isHearingImpaired: track.isHearingImpaired,
        )) {
          continue;
        }
        rows.add(
          PlayerMenuRow(
            leading: LanguageFlag(track.language ?? '', height: 13),
            title: track.language?.isNotEmpty == true
                ? track.language!
                : track.title,
            badges: [
              if (track.isForced) context.l10n.subsForced,
              if (track.isHearingImpaired) context.l10n.subsSdhShort,
            ],
            isSelected: widget.isSubtitleEnabled &&
                widget.selectedEmbeddedIndex == track.index,
            onTap: () => widget.onSelectEmbedded(track),
          ),
        );
      }
    } else {
      for (final group in widget.groups) {
        if (group.variants.isEmpty) continue;
        final best = group.variants.first;
        if (!_passesFilter(
          isForced: best.isForced,
          isHearingImpaired: best.isHearingImpaired,
        )) {
          continue;
        }
        rows.add(
          PlayerMenuRow(
            leading: LanguageFlag(group.language, height: 13),
            title: group.language,
            badges: [
              if (group.variants.length > 1)
                context.l10n.playerSubtitleCount(group.variants.length),
            ],
            isSelected: widget.isSubtitleEnabled &&
                widget.selectedVariant?.downloadUrl == best.downloadUrl,
            onTap: () => widget.onSelectVariant(best),
          ),
        );
      }
    }

    if (rows.isEmpty) {
      rows.add(PlayerMenuEmptyRow(context.l10n.playerNoSubtitlesForStream));
    }
    return rows;
  }

  /// Whether a track survives the active filter. `all` passes everything.
  bool _passesFilter({
    required bool isForced,
    required bool isHearingImpaired,
  }) => switch (_filter) {
    _SubtitleFilter.all => true,
    _SubtitleFilter.sdh => isHearingImpaired,
    _SubtitleFilter.forced => isForced,
  };
}

/// Which list the panel is showing.
enum _SubtitleSource { embedded, online }

/// Which tracks the list is narrowed to.
enum _SubtitleFilter { all, sdh, forced }

/// One of the Embedded / Online tabs.
class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? PlayerTheme.accent.withValues(alpha: 0.18)
                : PlayerTheme.raised,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? PlayerTheme.accent.withValues(alpha: 0.55)
                  : PlayerTheme.edgeSoft,
            ),
          ),
          child: Text(
            count > 0 ? '$label  $count' : label,
            style: TextStyle(
              color: isSelected ? PlayerTheme.ink : PlayerTheme.inkSubtle,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the All / CC-SDH / Forced chips.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? PlayerTheme.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isSelected ? PlayerTheme.edge : PlayerTheme.edgeSoft,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? PlayerTheme.ink : PlayerTheme.inkSubtle,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The on/off control. One button whose label and colour follow the state,
/// rather than two chips where one is always inert.
class _SubtitleToggleButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _SubtitleToggleButton({
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isEnabled
                ? PlayerTheme.accent.withValues(alpha: 0.18)
                : PlayerTheme.raised,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isEnabled
                  ? PlayerTheme.accent.withValues(alpha: 0.55)
                  : PlayerTheme.edgeSoft,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isEnabled
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_disabled_rounded,
                size: 17,
                color: isEnabled
                    ? PlayerTheme.accent
                    : PlayerTheme.inkDisabled,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isEnabled
                      ? context.l10n.playerSubtitleTurnOff
                      : context.l10n.playerSubtitleTurnOn,
                  style: TextStyle(
                    color:
                        isEnabled ? PlayerTheme.ink : PlayerTheme.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}