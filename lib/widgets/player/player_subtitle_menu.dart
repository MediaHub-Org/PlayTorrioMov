import 'package:flutter/material.dart';
import 'package:playtorriomov/l10n/l10n.dart';
import 'package:playtorriomov/models/subtitle/subtitle_display.dart';
import 'package:playtorriomov/models/subtitle/subtitle_model.dart';
import 'package:playtorriomov/services/subtitles/subtitle_service.dart';
import 'language_flag.dart';
import 'player_sub_style_modal.dart' show SubtitleStyleEditor;
import 'player_glass.dart';

/// Full-featured subtitle selection, search, and timing menu.
/// Responsive across mobile portrait, mobile landscape, tablet, and desktop screens.
class PlayerSubtitleMenu extends StatefulWidget {
  final List<SubtitleLanguageGroup> groups;
  final List<PlayerEmbeddedSubtitle> embeddedSubtitles;
  final int? selectedEmbeddedIndex;
  final SubtitleVariant? selectedVariant;
  final bool isSubtitleEnabled;
  final String movieTitle;
  final String? imdbId;
  final int? season;
  final int? episode;
  final int? year;
  final double delaySec;
  final ValueChanged<SubtitleVariant?> onSelectVariant;
  final ValueChanged<PlayerEmbeddedSubtitle> onSelectEmbedded;
  final VoidCallback onToggleOff;
  final VoidCallback onOpenSyncBar;
  final VoidCallback onClose;

  /// The media player, handed to the embedded appearance editor so its live
  /// preview and its changes apply to the running session.
  final dynamic player;

  /// Picks the best subtitle automatically -- the audio language first, then
  /// the file's default, then English, then anything. The transport bar's
  /// subtitle button used to do this on every press as a CC toggle; the
  /// button opens this panel now, and "Auto" is here so that one-tap
  /// behavior survived the move.
  final VoidCallback onAutoPick;

  /// Back to the settings root, when this menu was stepped into from
  /// there rather than opened directly from the transport bar.
  final VoidCallback? onBack;

  /// Told when the appearance editor opens or closes, so the player can show
  /// sample subtitles while it is open. Also told `false` when this menu goes
  /// away with the editor still showing.
  final ValueChanged<bool>? onAppearanceOpenChanged;

  const PlayerSubtitleMenu({
    super.key,
    required this.groups,
    this.embeddedSubtitles = const [],
    this.selectedEmbeddedIndex,
    this.selectedVariant,
    required this.isSubtitleEnabled,
    required this.movieTitle,
    this.imdbId,
    this.season,
    this.episode,
    this.year,
    required this.delaySec,
    required this.onSelectVariant,
    required this.onSelectEmbedded,
    required this.onToggleOff,
    required this.onOpenSyncBar,
    required this.onAutoPick,
    required this.onClose,
    this.player,
    this.onBack,
    this.onAppearanceOpenChanged,
  });

  @override
  State<PlayerSubtitleMenu> createState() => _PlayerSubtitleMenuState();
}

class _PlayerSubtitleMenuState extends State<PlayerSubtitleMenu> {
  String? _selectedLanguage;
  bool _filterHI = false;
  bool _filterForced = false;

  /// Whether the appearance editor is showing in place of the track list.
  /// The editor used to open as its own pop-up over the video, which hid
  /// the subtitles it exists to style -- the one thing you need to see while
  /// adjusting them. In here it shares the panel, and the video stays
  /// visible behind the glass.
  bool _showAppearance = false;

  void _setAppearance(bool open) {
    setState(() => _showAppearance = open);
    widget.onAppearanceOpenChanged?.call(open);
  }

  @override
  void dispose() {
    // The menu can close (a tap off the panel) with the editor still open;
    // the sample subtitles must not outlive it. After the frame, because this
    // runs while the tree is being torn down and the callback calls setState.
    final onChanged = widget.onAppearanceOpenChanged;
    if (_showAppearance && onChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(false));
    }
    super.dispose();
  }
  List<SubtitleLanguageGroup> _dynamicGroups = [];
  bool _isLoadingSearch = false;
  String? _searchQuery;

  static String cleanMediaTitle(String raw) {
    var name = raw;
    name = name.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|ts|mov|m4v|srt|vtt)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[._]'), ' ');
    name = name.replaceAll(RegExp(r'\b(2160p|1080p|720p|480p|4k|uhd|ds4k|webrip|web-dl|bluray|brrip|h264|x264|h265|x265|hevc|10bit|ddp5\.1|dd5\.1|atmos|aac|ac3|dts|flac|remux|hdr|dv|proper|repack|hdtv)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void initState() {
    super.initState();
    _dynamicGroups = List.from(widget.groups);
    if (widget.selectedEmbeddedIndex != null) {
      _selectedLanguage = '__embedded__';
    } else if (widget.selectedVariant != null) {
      _selectedLanguage = widget.selectedVariant!.language;
    } else if (widget.embeddedSubtitles.isNotEmpty) {
      _selectedLanguage = '__embedded__';
    } else if (_dynamicGroups.isNotEmpty) {
      _selectedLanguage = _dynamicGroups.first.language;
    } else {
      _selectedLanguage = '__all__';
    }

    if (_dynamicGroups.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchOnline();
      });
    }
  }

  @override
  void didUpdateWidget(PlayerSubtitleMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groups.isNotEmpty && widget.groups != oldWidget.groups) {
      setState(() {
        _dynamicGroups = List.from(widget.groups);
        _selectedLanguage ??= _dynamicGroups.first.language;
      });
    }
  }

  Future<void> _searchOnline() async {
    setState(() => _isLoadingSearch = true);
    try {
      int? year = widget.year;
      final rawTitle = widget.movieTitle;
      if (year == null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawTitle);
        if (yMatch != null) year = int.tryParse(yMatch.group(1)!);
      }

      final query = _searchQuery?.isNotEmpty == true
          ? _searchQuery!
          : cleanMediaTitle(rawTitle);

      debugPrint('[PlayerSubtitleMenu] Searching subtitles online for: "$query" (year: $year, imdb: ${widget.imdbId})');
      final results = await SubtitleService().fetchAllSubtitles(
        query,
        imdbId: widget.imdbId,
        season: widget.season,
        episode: widget.episode,
        year: year,
      );
      debugPrint('[PlayerSubtitleMenu] Found ${results.length} subtitle language groups');
      if (mounted) {
        setState(() {
          _dynamicGroups = results;
          if (_dynamicGroups.isNotEmpty && _selectedLanguage == null) {
            _selectedLanguage = _dynamicGroups.first.language;
          }
        });
      }
    } catch (e) {
      debugPrint('[PlayerSubtitleMenu] search error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  // Replaces the per-menu `_getLanguageEmoji` that matched ISO code
  // substrings against a display name -- which is why "Spanish" drew the
  // globe and "Chinese" drew the Indian flag. See language_flag.dart.
  Widget _flag(String lang, {double height = 12}) =>
      LanguageFlag(lang, height: height);

  /// Every variant of the selected language, before the CC and Forced
  /// filters -- what the filter chips count.
  List<SubtitleVariant> _variantsForLanguage() {
    List<SubtitleVariant> all = [];
    if (_selectedLanguage == '__all__' || _selectedLanguage == null) {
      all = _dynamicGroups.expand((g) => g.variants).toList();
    } else {
      final g = _dynamicGroups.firstWhere(
        (group) => group.language == _selectedLanguage,
        orElse: () => SubtitleLanguageGroup(language: '', variants: []),
      );
      all = g.variants;
    }
    return all;
  }

  List<SubtitleVariant> _getFilteredVariants() {
    return _variantsForLanguage().where((v) {
      // The variant's own classification, not a title sniff -- same source
      // the row badges use, so the filter and the badges can never disagree.
      if (_filterHI && !v.isHearingImpaired) {
        return false;
      }
      if (_filterForced && !v.isForced) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalVariantsCount = _dynamicGroups.fold<int>(0, (sum, g) => sum + g.variants.length);
    final isOff = !widget.isSubtitleEnabled || (widget.selectedVariant == null && widget.selectedEmbeddedIndex == null);
    final filteredVariants = _getFilteredVariants();
    final screen = MediaQuery.sizeOf(context);

    // Responsive Breakpoints
    final isCompact = screen.width < 560; // Mobile portrait or narrow screen
    final isLandscapeMobile = screen.height < 450 && screen.width >= 560; // Mobile landscape

    // Compute responsive dimensions
    final double cardWidth;
    if (isCompact) {
      cardWidth = (screen.width - 24).clamp(280.0, 520.0);
    } else if (isLandscapeMobile) {
      cardWidth = (screen.width - 48).clamp(460.0, 600.0);
    } else {
      cardWidth = (540.0).clamp(400.0, screen.width - 48);
    }

    // This panel fixes its own height -- its two columns share one Expanded,
    // which needs a bounded box -- so it has to agree with the anchor about
    // how much room there is. Clamping to the anchor's figure is what keeps
    // a landscape phone from being handed a card taller than the gap above
    // the transport bar.
    final roomForCard = PlayerMenuAnchor.availableHeight(context);
    final double preferredHeight;
    if (isLandscapeMobile) {
      preferredHeight = roomForCard;
    } else if (isCompact) {
      preferredHeight = (screen.height * 0.65).clamp(340.0, 520.0);
    } else {
      preferredHeight = (screen.height * 0.65).clamp(380.0, 540.0);
    }
    // min, not clamp: clamp(lower, upper) throws when upper < lower, and a
    // very short viewport can leave less room than any of the preferred
    // heights above.
    final cardHeight = preferredHeight < roomForCard
        ? preferredHeight
        : roomForCard;

    final headerPaddingV = (isLandscapeMobile || isCompact) ? 8.0 : 12.0;
    final buttonSize = (isLandscapeMobile || isCompact) ? 30.0 : 34.0;
    final iconSize = (isLandscapeMobile || isCompact) ? 15.0 : 17.0;

    return PlayerGlassCard(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 1. Header Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: headerPaddingV),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title and badge
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back to the settings root. This menu is the deepest
                      // thing behind the gear and had no way back, so
                      // reaching Aspect ratio from here meant closing and
                      // reopening it.
                      if (_showAppearance) ...[
                        PlayerIconButton(
                          size: buttonSize,
                          iconSize: iconSize,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          tooltip: context.l10n.subsBackToSubtitles,
                          onPressed: () =>
                              _setAppearance(false),
                        ),
                        const SizedBox(width: 6),
                      ] else if (widget.onBack != null) ...[
                        PlayerIconButton(
                          size: buttonSize,
                          iconSize: iconSize,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          tooltip: context.l10n.playerBackToSettings,
                          onPressed: widget.onBack,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        // The header names the view, and the back arrow
                        // returns from Appearance to the track list -- the
                        // same pattern every other player menu uses, so the
                        // editor is a step inside the panel rather than a
                        // second panel fighting it for the screen.
                        _showAppearance ? context.l10n.subsAppearance : context.l10n.detailsSubtitles,
                        style: const TextStyle(
                          color: PlayerTheme.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_showAppearance && totalVariantsCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PlayerTheme.raised,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$totalVariantsCount',
                            style: const TextStyle(
                              color: PlayerTheme.inkSubtle,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Header Action Icons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Online Search Trigger
                    PlayerIconButton(
                      size: buttonSize,
                      iconSize: iconSize,
                      icon: _isLoadingSearch
                          ? SizedBox(
                              width: iconSize,
                              height: iconSize,
                              child: CircularProgressIndicator(
                                color: PlayerTheme.accent,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      tooltip: context.l10n.subsRefreshOnline,
                      onPressed: _isLoadingSearch ? null : _searchOnline,
                    ),
                    const SizedBox(width: 3),

                    // Subtitle Delay Bar (external subtitles only)
                    if (widget.selectedEmbeddedIndex == null) ...[
                      PlayerIconButton(
                        size: buttonSize,
                        iconSize: iconSize,
                        icon: const Icon(Icons.timer_outlined),
                        tooltip: context.l10n.subsSyncBar,
                        showActiveBadge: widget.delaySec != 0,
                        onPressed: () {
                          widget.onClose();
                          widget.onOpenSyncBar();
                        },
                      ),
                      const SizedBox(width: 3),
                    ],

                    // Subtitle Appearance, shown inside this panel rather
                    // than as a pop-up over the video: the pop-up hid the
                    // subtitles it exists to style.
                    PlayerIconButton(
                      size: buttonSize,
                      iconSize: iconSize,
                      icon: const Icon(Icons.tune_rounded),
                      tooltip: context.l10n.subsAppearanceTooltip,
                      showActiveBadge: _showAppearance,
                      onPressed: () =>
                          _setAppearance(!_showAppearance),
                    ),
                    // No close button: the full-screen barrier behind every
                    // open menu dismisses on a tap anywhere off the panel,
                    // and the back arrow returns to the settings root.
                    //
                    // "Speech Text Sync" was here too, and is gone. It
                    // adjusted subtitle timing by following the spoken
                    // dialogue, which almost nobody understood from the name
                    // -- and the plain delay control next to it already
                    // answers "the subtitles are out of sync", which is the
                    // only thing a viewer is actually trying to fix.
                  ],
                ),
              ],
            ),
          ),

          // 2. Responsive Content Body -- the track list, or the appearance
          // editor when the tune button has switched to it.
          if (!_showAppearance) _buildLoadedStrip(),

          Expanded(
            child: _showAppearance
                ? SubtitleStyleEditor(player: widget.player)
                : (isCompact
                    ? _buildCompactLayout(
                        context, isOff, filteredVariants, totalVariantsCount)
                    : _buildDesktopLayout(context, isOff, filteredVariants,
                        totalVariantsCount, isLandscapeMobile)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // "In this video" strip
  // ───────────────────────────────────────────────────────────────────────────

  /// The subtitles that are already there, one tap away at the top: the
  /// online one currently loaded, then the tracks stored inside the file with
  /// the file's own default first. They used to sit behind an "Embedded" pill
  /// and a category of their own, two taps in and easy to miss -- though for
  /// most videos they are the answer.
  Widget _buildLoadedStrip() {
    final loaded = widget.isSubtitleEnabled ? widget.selectedVariant : null;
    final embedded = [...widget.embeddedSubtitles]
      ..sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
    if (loaded == null && embedded.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0x14000000),
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.subsInThisVideo.toUpperCase(),
            style: const TextStyle(
              color: PlayerTheme.inkSubtle,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                if (loaded != null)
                  _buildStripChip(
                    language: loaded.language,
                    label: loaded.language,
                    isSelected: true,
                    badges: [
                      _TrackBadge(
                        label: context.l10n.subsLoadedBadge,
                        color: PlayerTheme.accent,
                        icon: Icons.download_done_rounded,
                      ),
                    ],
                    onTap: () {},
                  ),
                for (final track in embedded)
                  _buildStripChip(
                    language: track.language,
                    label: (track.language != null && track.language!.isNotEmpty)
                        ? track.language!
                        : track.title,
                    isSelected: widget.isSubtitleEnabled &&
                        widget.selectedEmbeddedIndex == track.index,
                    badges: [
                      if (track.isDefault)
                        _TrackBadge(
                          label: context.l10n.subsDefaultBadge,
                          color: const Color(0xFF60A5FA),
                          icon: Icons.star_rounded,
                        ),
                      if (track.isHearingImpaired)
                        _TrackBadge(
                          label: context.l10n.subsHearingImpaired,
                          color: const Color(0xFF10B981),
                          icon: Icons.hearing_rounded,
                        ),
                      if (track.isForced)
                        _TrackBadge(
                          label: context.l10n.subsForced,
                          color: const Color(0xFFF59E0B),
                          icon: Icons.translate_rounded,
                        ),
                    ],
                    onTap: () => widget.onSelectEmbedded(track),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripChip({
    required String? language,
    required String label,
    required bool isSelected,
    required List<Widget> badges,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? PlayerTheme.accent.withValues(alpha: 0.22) : PlayerTheme.raised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (language != null && language.isNotEmpty) ...[
                  _flag(language),
                  const SizedBox(width: 6),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                for (final badge in badges) ...[
                  const SizedBox(width: 5),
                  badge,
                ],
                if (isSelected) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.check_rounded, size: 14, color: PlayerTheme.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Compact / Mobile Layout (Top Horizontal Category Bar + Full-width List)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCompactLayout(
    BuildContext context,
    bool isOff,
    List<SubtitleVariant> filteredVariants,
    int totalVariantsCount,
  ) {
    return Column(
      children: [
        // Horizontal Scrollable Category & Language Selector
        _buildHorizontalLanguageBar(isOff, totalVariantsCount),

        // Filter Chips Toolbar
        if (_selectedLanguage != '__embedded__') _buildFilterToolbar(compact: true),

        // Subtitles List / Embedded List
        Expanded(
          child: _selectedLanguage == '__embedded__'
              ? _buildEmbeddedList(compact: true)
              : _buildVariantList(filteredVariants, compact: true),
        ),

        // Bottom Search Trigger
        if (_selectedLanguage != '__embedded__') _buildBottomSearchBar(compact: true),
      ],
    );
  }

  Widget _buildHorizontalLanguageBar(bool isOff, int totalVariantsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0x20000000),
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Auto: one tap, best track. The transport bar's subtitle button
            // used to do this on every press; the button opens this panel
            // now, so the behavior lives here rather than being lost.
            _buildLanguagePill(
              label: context.l10n.subsAuto,
              isSelected: false,
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: PlayerTheme.inkSubtle,
              ),
              onTap: widget.onAutoPick,
            ),
            const SizedBox(width: 6),

            // Off Button
            _buildLanguagePill(
              label: context.l10n.detailsOff,
              isSelected: isOff,
              icon: Icon(
                Icons.block_rounded,
                size: 13,
                color: isOff ? Colors.white : PlayerTheme.inkSubtle,
              ),
              onTap: widget.onToggleOff,
            ),
            const SizedBox(width: 6),

            // Embedded Subtitles Pill
            if (widget.embeddedSubtitles.isNotEmpty) ...[
              _buildLanguagePill(
                label: context.l10n.subsEmbedded,
                emoji: '⚡',
                count: widget.embeddedSubtitles.length,
                isSelected: _selectedLanguage == '__embedded__',
                onTap: () => setState(() => _selectedLanguage = '__embedded__'),
              ),
              const SizedBox(width: 6),
            ],

            // All Languages Pill
            if (_dynamicGroups.isNotEmpty) ...[
              _buildLanguagePill(
                label: context.l10n.subsAll,
                emoji: '🌐',
                count: totalVariantsCount,
                isSelected: _selectedLanguage == '__all__',
                onTap: () => setState(() => _selectedLanguage = '__all__'),
              ),
              const SizedBox(width: 6),

              // Individual Languages
              ..._dynamicGroups.map((g) {
                final isSelected = _selectedLanguage == g.language;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildLanguagePill(
                    label: g.language,
                    icon: _flag(g.language, height: 11),
                    count: g.variants.length,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedLanguage = g.language),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePill({
    required String label,
    String? emoji,
    Widget? icon,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? PlayerTheme.accent.withValues(alpha: 0.35) : PlayerTheme.raised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? PlayerTheme.accent : PlayerTheme.edgeSoft,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 5),
              ] else if (emoji != null) ...[
                Text(emoji, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? PlayerTheme.accent : PlayerTheme.surfaceHover,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : PlayerTheme.inkSubtle,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Desktop / Tablet / Wide Layout (2-Column: Left Sidebar + Right List)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isOff,
    List<SubtitleVariant> filteredVariants,
    int totalVariantsCount,
    bool isLandscapeMobile,
  ) {
    final sidebarWidth = isLandscapeMobile ? 138.0 : 155.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Language Sidebar
        Container(
          width: sidebarWidth,
          decoration: const BoxDecoration(
            color: Color(0x22000000),
            border: Border(right: BorderSide(color: PlayerTheme.edgeSoft)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(7),
            physics: const BouncingScrollPhysics(),
            children: [
              // Subtitles Off Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onToggleOff,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: isOff ? PlayerTheme.raised : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOff ? PlayerTheme.edge : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: isOff ? PlayerTheme.accent : PlayerTheme.raised,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: isOff
                              ? const Icon(Icons.check_rounded, size: 9.5, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          context.l10n.detailsOff,
                          style: const TextStyle(
                            color: PlayerTheme.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Embedded Subtitles Category
              if (widget.embeddedSubtitles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 10, bottom: 4),
                  child: Text(
                    context.l10n.subsEmbedded.toUpperCase(),
                    style: const TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedLanguage = '__embedded__'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _selectedLanguage == '__embedded__' ? PlayerTheme.raised : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedLanguage == '__embedded__' ? PlayerTheme.edge : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 11.5)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              context.l10n.subsEmbedded,
                              style: const TextStyle(
                                color: PlayerTheme.ink,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: PlayerTheme.accent.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${widget.embeddedSubtitles.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              if (_dynamicGroups.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 10, bottom: 4),
                  child: Text(
                    context.l10n.subsLanguages.toUpperCase(),
                    style: const TextStyle(
                      color: PlayerTheme.inkSubtle,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // All Languages Option
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selectedLanguage = '__all__'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _selectedLanguage == '__all__' ? PlayerTheme.raised : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedLanguage == '__all__' ? PlayerTheme.edge : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🌐', style: TextStyle(fontSize: 11.5)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              context.l10n.subsAllLanguages,
                              style: const TextStyle(
                                color: PlayerTheme.inkMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$totalVariantsCount',
                            style: const TextStyle(
                              color: PlayerTheme.inkSubtle,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Individual Language Groups
                ..._dynamicGroups.map((g) {
                  final isSelected = _selectedLanguage == g.language;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedLanguage = g.language),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? PlayerTheme.raised : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? PlayerTheme.edge : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _flag(g.language, height: 12),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                g.language,
                                style: TextStyle(
                                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${g.variants.length}',
                              style: const TextStyle(
                                color: PlayerTheme.inkSubtle,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        // Right Variants & Search Panel
        Expanded(
          child: _selectedLanguage == '__embedded__'
              ? _buildEmbeddedList(compact: false)
              : Column(
                  children: [
                    _buildFilterToolbar(compact: false),
                    Expanded(child: _buildVariantList(filteredVariants, compact: false)),
                    _buildBottomSearchBar(compact: false),
                  ],
                ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Shared Filter Toolbar
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildFilterToolbar({required bool compact}) {
    final inLanguage = _variantsForLanguage();
    final hearingCount = inLanguage.where((v) => v.isHearingImpaired).length;
    final forcedCount = inLanguage.where((v) => v.isForced).length;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: Row(
        children: [
          // "All" is the absence of a filter: lit when neither CC nor Forced
          // is on, and pressing it clears them. It used to be a permanently
          // lit chip that did nothing.
          PlayerToggleChip(
            active: !_filterHI && !_filterForced,
            label: context.l10n.subsAll,
            onClick: () => setState(() {
              _filterHI = false;
              _filterForced = false;
            }),
          ),
          const SizedBox(width: 5),
          // Counted, and dimmed when the language has none: the chip used to
          // be pressable whatever was there, and pressing it just emptied the
          // list.
          Tooltip(
            message: context.l10n.subsHearingImpairedTip,
            child: PlayerToggleChip(
              active: _filterHI,
              label: context.l10n.subsHearingImpaired,
              count: '$hearingCount',
              disabled: hearingCount == 0 && !_filterHI,
              onClick: () => setState(() => _filterHI = !_filterHI),
            ),
          ),
          const SizedBox(width: 5),
          Tooltip(
            message: context.l10n.subsForcedTip,
            child: PlayerToggleChip(
              active: _filterForced,
              label: context.l10n.subsForced,
              count: '$forcedCount',
              disabled: forcedCount == 0 && !_filterForced,
              onClick: () => setState(() => _filterForced = !_filterForced),
            ),
          ),
          const Spacer(),
          if (compact)
            GestureDetector(
              onTap: _searchOnline,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 13, color: PlayerTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.subsSearchOnline,
                    style: TextStyle(
                      color: PlayerTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Embedded Subtitles List
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEmbeddedList({required bool compact}) {
    return ListView.builder(
      padding: const EdgeInsets.all(7),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.embeddedSubtitles.length,
      itemBuilder: (context, i) {
        final track = widget.embeddedSubtitles[i];
        final isSelected = widget.isSubtitleEnabled && widget.selectedEmbeddedIndex == track.index;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onSelectEmbedded(track),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? PlayerTheme.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? PlayerTheme.edge : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 10.5, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (track.language != null && track.language!.isNotEmpty) ...[
                              _flag(track.language!),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                track.title,
                                style: TextStyle(
                                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: PlayerTheme.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.l10n.subsEmbedded.toUpperCase(),
                                style: TextStyle(
                                  color: PlayerTheme.accent,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (track.isDefault) ...[
                              const SizedBox(width: 4),
                              _TrackBadge(
                                label: context.l10n.subsDefaultBadge,
                                color: const Color(0xFF60A5FA),
                                icon: Icons.star_rounded,
                              ),
                            ],
                            if (track.isHearingImpaired) ...[
                              const SizedBox(width: 4),
                              _TrackBadge(
                                label: context.l10n.subsHearingImpaired,
                                color: const Color(0xFF10B981),
                                icon: Icons.hearing_rounded,
                                tooltip: context.l10n.subsHearingImpairedTip,
                              ),
                            ],
                            if (track.isForced) ...[
                              const SizedBox(width: 4),
                              _TrackBadge(
                                label: context.l10n.subsForced,
                                color: const Color(0xFFF59E0B),
                                icon: Icons.translate_rounded,
                                tooltip: context.l10n.subsForcedTip,
                              ),
                            ],
                            if (track.language != null && track.language!.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Text(
                                track.language!.toUpperCase(),
                                style: const TextStyle(
                                  color: PlayerTheme.inkSubtle,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (track.codec != null && track.codec!.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Text(
                                track.codec!.toUpperCase(),
                                style: const TextStyle(
                                  color: PlayerTheme.inkSubtle,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                            const SizedBox(width: 5),
                            Text(
                              '#${track.index + 1}',
                              style: const TextStyle(
                                color: PlayerTheme.inkDisabled,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // External Subtitle Variants List
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildVariantList(List<SubtitleVariant> filteredVariants, {required bool compact}) {
    if (_isLoadingSearch) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: PlayerTheme.accent,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.subsSearching,
              style: const TextStyle(color: PlayerTheme.inkMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (filteredVariants.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.subtitles_off_rounded,
                size: 30,
                color: PlayerTheme.inkSubtle,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.subsNone,
                style: const TextStyle(
                  color: PlayerTheme.inkMuted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PlayerTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 15),
                label: Text(context.l10n.subsSearchProviders, style: const TextStyle(fontSize: 11.5)),
                onPressed: _searchOnline,
              ),
            ],
          ),
        ),
      );
    }

    final rowTitles = numberedRowTitles(filteredVariants, fallback: context.l10n.subsStandardTitle);

    return ListView.builder(
      padding: const EdgeInsets.all(7),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredVariants.length,
      itemBuilder: (context, i) {
        final variant = filteredVariants[i];
        final isSelected = widget.isSubtitleEnabled && widget.selectedVariant?.downloadUrl == variant.downloadUrl;

        // The variant carries its own classification now -- from the
        // provider's flag where it sends one, from the title where it does
        // not -- so the menu no longer re-derives it by sniffing the title
        // at render time.
        final isHI = variant.isHearingImpaired;
        final isForced = variant.isForced;
        final display = describeSubtitle(variant);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onSelectVariant(variant),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isSelected ? PlayerTheme.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? PlayerTheme.edge : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 10.5, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (variant.language.isNotEmpty) ...[
                              _flag(variant.language),
                              const SizedBox(width: 5),
                              // The language as words, not just a flag: the
                              // flags are small and several are easy to
                              // confuse at a glance, and "which of these is
                              // the English one" is the question this list
                              // exists to answer. The group header already
                              // says the language, but a row repeated out of
                              // context -- or a screenshot of one -- should
                              // still say it.
                              Text(
                                variant.language,
                                style: TextStyle(
                                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              // A release name when there is one; otherwise
                              // "Standard", because a row that says only a
                              // language and a provider id reads as broken.
                              // Identical rows are numbered.
                              child: Text(
                                rowTitles[i],
                                style: TextStyle(
                                  color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Where it came from, as quiet text: it is the
                            // last thing to choose by, so it must not shout
                            // like the badges that change what you see.
                            Text(
                              [display.provider, display.format].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 10.5),
                            ),
                            for (final tag in display.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x15FFFFFF),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: PlayerTheme.inkMuted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isHI)
                              _TrackBadge(
                                label: context.l10n.subsHearingImpaired,
                                color: const Color(0xFF10B981),
                                icon: Icons.hearing_rounded,
                                tooltip: context.l10n.subsHearingImpairedTip,
                              ),
                            if (isForced)
                              _TrackBadge(
                                label: context.l10n.subsForced,
                                color: const Color(0xFFF59E0B),
                                icon: Icons.translate_rounded,
                                tooltip: context.l10n.subsForcedTip,
                              ),
                            if (display.isTranslated)
                              _TrackBadge(
                                label: context.l10n.subsAutoTranslated,
                                color: const Color(0xFF8B5CF6),
                                icon: Icons.auto_awesome_rounded,
                                tooltip: context.l10n.subsAutoTranslatedTip,
                              ),
                            if (display.downloads != null && display.downloads! > 0)
                              Tooltip(
                                message: context.l10n.subsDownloadsTip(compactCount(display.downloads!)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.download_rounded, size: 10, color: PlayerTheme.inkSubtle),
                                    const SizedBox(width: 2),
                                    Text(
                                      compactCount(display.downloads!),
                                      style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bottom Search Trigger
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBottomSearchBar({required bool compact}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _searchOnline,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 13, color: PlayerTheme.accent),
                  const SizedBox(width: 5),
                  Text(
                    context.l10n.subsFindMore,
                    style: const TextStyle(
                      color: PlayerTheme.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tag on a subtitle row: an icon and a short label in one color --
/// CC / SDH, Forced, Default, Loaded. One widget so the online list, the
/// embedded list and the strip on top show them the same way.
class _TrackBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String? tooltip;

  const _TrackBadge({
    required this.label,
    required this.color,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.5, color: color),
          const SizedBox(width: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip!, child: badge);
  }
}
