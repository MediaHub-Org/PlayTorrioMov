import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/subtitle/subtitle_model.dart';
import '../../services/subtitles/subtitle_languages.dart';
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

  /// The language being heard, so the embedded list can put its tracks
  /// first. Null when the audio track carries no language tag.
  final String? audioLanguage;
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
    this.audioLanguage,
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
  /// Forced is never the default: it narrows to a kind of track, and a
  /// viewer who opened the panel chose to browse.
  late _SubtitleSource _source = widget.embeddedSubtitles.isNotEmpty
      ? _SubtitleSource.embedded
      : _SubtitleSource.online;

  _SubtitleFilter _filter = _SubtitleFilter.all;

  /// How many languages the online list shows before "Show all".
  ///
  /// A provider search returns a couple of hundred languages, most with a
  /// single file. The fifteen with the most files are the ones a provider
  /// actually has coverage for, and they are what a viewer is looking for.
  static const int _onlineCap = 15;

  /// Whether the viewer asked for the whole online list.
  bool _showAllOnline = false;

  /// The language whose files are open, if any. One at a time: two open
  /// lists at once would push the rest of the languages off the panel.
  String? _expandedLanguage;

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
    //
    // Clamped to what the anchor can actually give it. A card taller than
    // that overflows the anchor's own scroll view, and the result is two
    // nested scrollables where the outer one cannot be reached: the wheel
    // goes to the inner list, and the bottom of the panel -- which is where
    // "More options" expands to -- is unreachable.
    final roomForCard = PlayerMenuAnchor.availableHeight(context);
    final preferred = (screen.height - 160).clamp(280.0, 460.0);
    final cardHeight = preferred < roomForCard ? preferred : roomForCard;

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

  /// Embedded / Online / Forced, as three pills rather than one merged list.
  ///
  /// They are different questions. An embedded track is already in the file
  /// and plays instantly; an online one has to be fetched; a forced one
  /// covers only the foreign-language dialogue, whichever side it comes
  /// from. Merging them meant the file's own tracks -- usually the answer --
  /// sat among a hundred downloads, and forced tracks hid among full
  /// translations they are not. Forced spans both sources, so it reads both
  /// lists narrowed to forced files.
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
        const SizedBox(width: 6),
        Expanded(
          child: _TabButton(
            label: context.l10n.subsForced,
            count: _forcedCount,
            isSelected: _source == _SubtitleSource.forced,
            // The whole view is forced files, so arriving with the Forced
            // filter chip set would show a state no visible chip explains.
            // It falls back to All; the chip row below hides Forced here.
            onTap: () => setState(() {
              _source = _SubtitleSource.forced;
              if (_filter == _SubtitleFilter.forced) {
                _filter = _SubtitleFilter.all;
              }
            }),
          ),
        ),
        // A file with no embedded tracks has nothing to show on that tab, so
        // it opens on Online rather than on an empty list.
        if (!hasEmbedded && _source == _SubtitleSource.embedded)
          const SizedBox.shrink(),
      ],
    );
  }

  /// How many forced rows the Forced pill counts: embedded forced tracks
  /// plus online forced files, the same "rows below" convention the other
  /// two pills use.
  int get _forcedCount =>
      widget.embeddedSubtitles.where((t) => t.isForced).length +
      widget.groups.fold(
        0,
        (sum, group) =>
            sum + group.variants.where((v) => v.isForced).length,
      );

  /// All / CC-SDH / Forced, filtering whichever pill is showing. On Forced
  /// the last chip is hidden: the whole view is forced files, so a chip for
  /// it would change nothing and read as broken.
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
        if (_source != _SubtitleSource.forced) ...[
          const SizedBox(width: 6),
          _FilterChip(
            label: context.l10n.subsForced,
            isSelected: _filter == _SubtitleFilter.forced,
            onTap: () => setState(() => _filter = _SubtitleFilter.forced),
          ),
        ],
      ],
    );
  }

  /// Whether [variant] is the one playing.
  ///
  /// Compared by URL, and a variant with no URL is never the selected one.
  /// The guard matters: an empty `downloadUrl` on both sides made every row
  /// in the list match, so the whole online list drew as selected.
  bool _isSelectedVariant(SubtitleVariant variant) {
    if (!widget.isSubtitleEnabled) return false;
    final selected = widget.selectedVariant?.downloadUrl;
    if (selected == null || selected.isEmpty) return false;
    return selected == variant.downloadUrl;
  }

  /// Whether any file in [group] is the one playing.
  ///
  /// The language row is marked when the language is on, not only when its
  /// *best* file is. Picking the second file for Arabic left the Arabic row
  /// unmarked, which read as "nothing is selected" while a subtitle played.
  ///
  /// The group must match too, not just the URL: one provider lists the same
  /// file under every language it was translated into, so the URL alone
  /// ticked a row in each of them. The selected file went through the same
  /// grouping on its way in, so mapping it back names exactly one group --
  /// and a radio list never shows two.
  bool _isSelectedGroup(SubtitleLanguageGroup group) {
    final selected = widget.selectedVariant;
    if (!widget.isSubtitleEnabled || selected == null) return false;
    final url = selected.downloadUrl;
    if (url.isEmpty) return false;
    if (canonicalLanguageGroup(selected.language) != group.language) {
      return false;
    }
    return group.variants.any((v) => v.downloadUrl == url);
  }

  List<Widget> _buildRows(BuildContext context) {
    final rows = <Widget>[];

    // One tick for the whole list. The group and its open files would each
    // match the playing file on their own; the flag below moves the tick
    // down to the file. Embedded rows tick by unique index instead, and the
    // player clears one side when the other is picked, so the two halves
    // cannot both claim it.
    var markedSelected = false;

    if (_source != _SubtitleSource.online) {
      // Embedded, and the embedded half of Forced.
      //
      // File order is the muxer's, which is arbitrary to a viewer -- a
      // twelve-track disc put its languages in whatever order they were
      // authored, so the list looked shuffled. Alphabetical is the order
      // someone scanning for "Spanish" can actually use, and the audio
      // language leads because it is the track they are most likely to
      // want. See SubtitleAutoPick.embeddedForDisplay.
      final embedded = SubtitleAutoPick.embeddedForDisplay(
        widget.embeddedSubtitles,
        audioLanguage: widget.audioLanguage,
      );
      for (final track in embedded) {
        // Forced shows forced files only; the All and CC-SDH chips still
        // narrow them further below.
        if (_source == _SubtitleSource.forced && !track.isForced) continue;
        if (!_passesFilter(
          isForced: track.isForced,
          isHearingImpaired: track.isHearingImpaired,
        )) {
          continue;
        }
        rows.add(
          PlayerMenuRow(
            leading: LanguageFlag(track.language ?? '', height: 13),
            title: track.displayName,
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
    }

    // Not `else`: Forced reads both halves narrowed to forced files, so it
    // runs each block the other pills skip.
    if (_source != _SubtitleSource.embedded) {
      // Online, and the online half of Forced.
      //
      // The language being heard first, then most files first.
      //
      // Audio-first for the same reason the embedded list leads with it: it
      // is the language a viewer is most likely to want, and a viewer whose
      // audio is Spanish should not have to read past Chinese to find it.
      // After that, a language with twelve files is one a provider actually
      // has coverage for; the long tail of one-file languages is where the
      // junk lives, and it is also what made this list 200 rows. Alphabetical
      // breaks a tie, so the order is stable rather than whatever the
      // providers happened to answer in.
      //
      // Forced narrows each group to its forced files first, dropping
      // languages with none: the pill promises forced files, and a group
      // whose best file is forced but whose second is not would otherwise
      // offer the second one anyway.
      final base = _source == _SubtitleSource.forced
          ? [
              for (final group in widget.groups)
                if (group.variants.any((v) => v.isForced))
                  SubtitleLanguageGroup(
                    language: group.language,
                    variants: group.variants
                        .where((v) => v.isForced)
                        .toList(),
                  ),
            ]
          : widget.groups;
      final spoken = SubtitleAutoPick.languageKey(widget.audioLanguage);
      final groups = base
          .where((g) => g.variants.isNotEmpty)
          // A result with no language has no row name and nothing to
          // choose it by, so it is not offered rather than listed blank.
          .where((g) => g.language.trim().isNotEmpty)
          .where(
            (g) => _passesFilter(
              isForced: g.variants.first.isForced,
              isHearingImpaired: g.variants.first.isHearingImpaired,
            ),
          )
          .toList()
        ..sort((a, b) {
          final aSpoken =
              spoken != null && SubtitleAutoPick.languageKey(a.language) == spoken;
          final bSpoken =
              spoken != null && SubtitleAutoPick.languageKey(b.language) == spoken;
          if (aSpoken != bSpoken) return aSpoken ? -1 : 1;
          final byCount = b.variants.length.compareTo(a.variants.length);
          if (byCount != 0) return byCount;
          return a.language.compareTo(b.language);
        });

      final visible = _showAllOnline ? groups : groups.take(_onlineCap).toList();

      for (final group in visible) {
        final best = group.variants.first;
        final isExpanded = _expandedLanguage == group.language;
        final groupTicked = _isSelectedGroup(group);
        if (groupTicked && !isExpanded) markedSelected = true;
        rows.add(
          PlayerMenuRow(
            leading: LanguageFlag(group.language, height: 13),
            title: group.language,
            // The count is back, but as a reason to tap rather than a fact
            // about the implementation: it says there is more than one file
            // here, which is what the chevron opens.
            badges: [
              if (group.variants.length > 1)
                context.l10n.playerSubtitleCount(group.variants.length),
            ],
            // While the files are open the tick moves down to the file:
            // the group staying ticked beside it read as two selections.
            isSelected: groupTicked && !isExpanded,
            trailing: group.variants.length > 1                ? Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: PlayerTheme.inkSubtle,
                  )
                : null,
            // One tap picks the best file, the way Netflix and Disney+ do.
            // A second tap on the same row opens the rest, for when the
            // first one is wrong -- which is the only reason to want them.
            onTap: () {
              if (group.variants.length > 1 && isExpanded) {
                setState(() => _expandedLanguage = null);
                return;
              }
              widget.onSelectVariant(best);
              if (group.variants.length > 1) {
                setState(() => _expandedLanguage = group.language);
              }
            },
          ),
        );

        if (isExpanded) {
          for (final variant in group.variants) {
            // First match only: duplicate links that survived dedupe share
            // the playing file's URL, and each would tick on its own.
            final fileTicked =
                !markedSelected && _isSelectedVariant(variant);
            if (fileTicked) markedSelected = true;
            rows.add(
              PlayerMenuRow(
                leading: const SizedBox(width: 0),
                title: _variantLabel(context, variant),
                isSelected: fileTicked,
                onTap: () => widget.onSelectVariant(variant),
              ),
            );
          }
        }
      }

      if (!_showAllOnline && groups.length > _onlineCap) {
        rows.add(
          _ShowAllRow(
            label: context.l10n.playerSubtitleShowAll(groups.length),
            onTap: () => setState(() => _showAllOnline = true),
          ),
        );
      }
    }

    if (rows.isEmpty) {
      // A filter that matched nothing is not the same as a stream with no
      // subtitles, and saying the latter would be wrong -- the tracks are
      // there, the filter is hiding them. Forced gets its own line for the
      // same reason: non-forced tracks being there does not mean a forced
      // one is.
      late final String message;
      if (_source == _SubtitleSource.forced &&
          _filter != _SubtitleFilter.sdh) {
        message = context.l10n.playerNoForcedSubtitles;
      } else if (_filter == _SubtitleFilter.all) {
        message = context.l10n.playerNoSubtitlesForStream;
      } else {
        message = context.l10n.playerSubtitleNoneMatchFilter;
      }
      rows.add(PlayerMenuEmptyRow(message));
    }
    return rows;
  }

  /// What one file in an expanded language is called.
  ///
  /// The provider and the release tags, which are the only things that tell
  /// two files for one language apart. They are hidden until the row is
  /// opened, because at the top level they are noise -- but once a viewer is
  /// choosing between files, they are the whole basis for the choice.
  ///
  /// The format is left out when the title already ends in it. A provider
  /// that names its files "Movie.srt" produced rows reading "SubtitleCat ·
  /// SRT" beside a title that said SRT, which is the same fact twice.
  String _variantLabel(BuildContext context, SubtitleVariant variant) {
    final title = variant.title.trim();
    final format = variant.format.toUpperCase();
    final titleSaysFormat = format.isNotEmpty &&
        title.toUpperCase().endsWith(format);
    final parts = <String>[
      if (variant.providerName.isNotEmpty) variant.providerName,
      if (format.isNotEmpty && !titleSaysFormat) format,
      if (variant.isHearingImpaired) context.l10n.subsSdhShort,
      if (variant.isForced) context.l10n.subsForced,
    ];
    if (title.isNotEmpty && title.toLowerCase() != 'standard') {
      parts.add(title);
    }
    return parts.isEmpty ? variant.title : parts.join(' · ');
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
enum _SubtitleSource { embedded, online, forced }

/// Which tracks the list is narrowed to.
enum _SubtitleFilter { all, sdh, forced }

/// The row that lifts the online list's cap.
///
/// A row rather than a button: it sits at the end of the list it extends, so
/// it reads as "there is more below" rather than as a control somewhere else.
class _ShowAllRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ShowAllRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: PlayerTheme.edgeSoft),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: PlayerTheme.inkSubtle,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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