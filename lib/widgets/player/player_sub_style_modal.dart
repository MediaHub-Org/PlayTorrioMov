import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/player/player_settings.dart';
import 'player_glass.dart';

/// How opaque the subtitle background is, 0 to 1, read from a `#AARRGGBB`
/// string. A value that does not parse counts as no background.
double subtitleBackgroundOpacity(String hex) {
  final str = hex.replaceAll('#', '').trim();
  if (str.length != 8) return 0;
  final alpha = int.tryParse(str.substring(0, 2), radix: 16);
  return alpha == null ? 0 : alpha / 255;
}

/// [hex] with its alpha replaced. The color underneath is kept, so a preset
/// with a tinted box (or a saved one from before the list of boxes went
/// away) keeps its tint and only its strength changes.
String withSubtitleBackgroundOpacity(String hex, double opacity) {
  final str = hex.replaceAll('#', '').trim();
  final rgb = str.length == 8 ? str.substring(2) : '000000';
  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  return '#${alpha.toRadixString(16).padLeft(2, '0')}$rgb'.toUpperCase();
}

/// Floating card used to present [SubtitleStyleEditor] as an overlay above
/// the video during playback (`player_screen.dart`). Settings → Video
/// Player embeds [SubtitleStyleEditor] directly instead of this wrapper, so
/// the customizer reads as part of the page rather than a pop-up (#71).
class PlayerSubStyleModal extends StatelessWidget {
  final Player? player;
  final VoidCallback onClose;

  const PlayerSubStyleModal({
    super.key,
    this.player,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.width < 600;
    final isLandscapeMobile = screen.height < 500;

    final double cardWidth;
    if (isCompact) {
      cardWidth = (screen.width - 24).clamp(320.0, 560.0);
    } else if (isLandscapeMobile) {
      cardWidth = (screen.width - 32).clamp(440.0, 680.0);
    } else {
      cardWidth = (640.0).clamp(460.0, screen.width - 48);
    }

    final double cardHeight;
    if (isLandscapeMobile) {
      cardHeight = (screen.height - 32).clamp(240.0, screen.height - 20);
    } else if (isCompact) {
      cardHeight = (screen.height * 0.85).clamp(420.0, 660.0);
    } else {
      cardHeight = (screen.height * 0.76).clamp(520.0, 720.0);
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: PlayerGlassCard(
          width: cardWidth,
          height: cardHeight,
          borderRadius: 22,
          padding: EdgeInsets.zero,
          child: SubtitleStyleEditor(player: player, onClose: onClose),
        ),
      ),
    );
  }
}

/// The subtitle style controls themselves: live preview, presets, and the
/// typography/colors/outline/position/advanced tabs. Reused both floating
/// (via [PlayerSubStyleModal], mid-playback) and embedded inline (Settings →
/// Video Player, where [onClose] is left null and no floating chrome is
/// drawn around it).
///
/// Needs a bounded height from its parent — the tab content scrolls inside
/// whatever height it is given, rather than sizing itself to content.
class SubtitleStyleEditor extends StatefulWidget {
  final Player? player;
  final VoidCallback? onClose;

  const SubtitleStyleEditor({
    super.key,
    this.player,
    this.onClose,
  });

  @override
  State<SubtitleStyleEditor> createState() => _SubtitleStyleEditorState();
}

class _SubtitleStyleEditorState extends State<SubtitleStyleEditor> {

  static const List<Map<String, dynamic>> _textColorPalette = [
    {'name': 'White', 'hex': '#FFFFFFFF', 'color': Color(0xFFFFFFFF)},
    {'name': 'Cinema Yellow', 'hex': '#FFFFEB3B', 'color': Color(0xFFFFEB3B)},
    {'name': 'Amber Gold', 'hex': '#FFFFC107', 'color': Color(0xFFFFC107)},
    {'name': 'Electric Cyan', 'hex': '#00E5FF', 'color': Color(0xFF00E5FF)},
    {'name': 'Neon Green', 'hex': '#00E676', 'color': Color(0xFF00E676)},
    {'name': 'Vibrant Orange', 'hex': '#FF9100', 'color': Color(0xFFFF9100)},
    {'name': 'Soft Rose', 'hex': '#FF80AB', 'color': Color(0xFFFF80AB)},
    {'name': 'Light Gray', 'hex': '#D1D5DB', 'color': Color(0xFFD1D5DB)},
  ];

  static const List<Map<String, dynamic>> _borderColorPalette = [
    {'name': 'Black', 'hex': '#FF000000', 'color': Color(0xFF000000)},
    {'name': 'Dark Slate', 'hex': '#FF1E293B', 'color': Color(0xFF1E293B)},
    {'name': 'White', 'hex': '#FFFFFFFF', 'color': Color(0xFFFFFFFF)},
    {'name': 'Gold', 'hex': '#FFFFD700', 'color': Color(0xFFFFD700)},
    {'name': 'Crimson', 'hex': '#FFE11D48', 'color': Color(0xFFE11D48)},
    {'name': 'Neon Cyan', 'hex': '#FF00E5FF', 'color': Color(0xFF00E5FF)},
  ];

  /// The display name of a palette swatch. The palettes are `const` maps keyed
  /// by an English name, so the name is looked up here rather than stored
  /// translated; an unknown name (a future palette entry) shows as written.
  String _paletteName(AppLocalizations l10n, String name) => switch (name) {
    'White' => l10n.subStyleWhite,
    'Cinema Yellow' => l10n.subStyleCinemaYellow,
    'Amber Gold' => l10n.subStyleAmberGold,
    'Electric Cyan' => l10n.subStyleElectricCyan,
    'Neon Green' => l10n.subStyleNeonGreen,
    'Vibrant Orange' => l10n.subStyleVibrantOrange,
    'Soft Rose' => l10n.subStyleSoftRose,
    'Light Gray' => l10n.subStyleLightGray,
    'Black' => l10n.subStyleBlack,
    'Dark Slate' => l10n.subStyleDarkSlate,
    'Gold' => l10n.subStyleGold,
    'Crimson' => l10n.subStyleCrimson,
    'Neon Cyan' => l10n.subStyleNeonCyan,
    _ => name,
  };

  Color _parseColorFromHex(String hex, {Color fallback = Colors.white}) {
    var str = hex.replaceAll('#', '').trim();
    if (str.length == 6) {
      str = 'FF$str';
    }
    if (str.length == 8) {
      final val = int.tryParse(str, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    // Sized from the constraints this widget is actually given, not the
    // screen: the floating dialog and the inline settings panel hand it
    // different heights, and both need the same compact-layout behavior
    // once space gets tight.
    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<int>(
          valueListenable: PlayerSettings.changeNotifier,
          builder: (context, _, __) {
            return Column(
              children: [
                // No header of its own: the subtitle panel's header names
                // this view and carries the back arrow.
                _buildPresetsBar(),

                // One scrolling page, in the order people reach for things:
                // the text itself, its background, its outline, where it
                // sits -- then everything rarer behind "More options". It was
                // five tabs, and a viewer hunting for one setting opened
                // three of them.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSectionHeader(context.l10n.subStyleSecText),
                      ..._sizeItems(),
                      ..._textColorItems(),
                      ..._boldItems(),
                      const SizedBox(height: 24),

                      _buildSectionHeader(context.l10n.subStyleSecBackground),
                      ..._boxItems(),
                      const SizedBox(height: 24),

                      _buildSectionHeader(context.l10n.subStyleSecOutline),
                      ..._outlineColorItems(),
                      ..._thicknessItems(),
                      const SizedBox(height: 24),

                      _buildSectionHeader(context.l10n.subStyleSecPosition),
                      ..._alignItems(),
                      ..._vposItems(),
                      const SizedBox(height: 8),

                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          iconColor: PlayerTheme.inkMuted,
                          collapsedIconColor: PlayerTheme.inkMuted,
                          title: Text(
                            context.l10n.subStyleMore,
                            style: const TextStyle(color: PlayerTheme.ink, fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          children: [
                            const SizedBox(height: 6),
                            ..._fontFamilyItems(),
                            ..._scaleItems(),
                            ..._shadowItems(),
                            ..._marginItems(),
                            ..._advancedItems(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Presets Horizontal Bar
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPresetsBar() {
    final activePreset = PlayerSettings.subStylePreset.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PlayerTheme.edgeSoft)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: SubtitleStylePreset.values
              .where((preset) => preset != SubtitleStylePreset.custom)
              .map((preset) {
            final isSelected = activePreset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => PlayerSettings.setSubStylePreset(preset, player: widget.player),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _parseColorFromHex(preset.textColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 0.8),
                        ),
                      ),
                      Text(
                        preset.label(context.l10n),
                        style: TextStyle(
                          color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// The fonts as chips, each set in its own face. A dropdown opened a menu
  /// in its own overlay -- sized to its widest entry, not to this panel, and
  /// unreachable with a remote's arrow keys -- and showed every font in the
  /// same one, so choosing meant guessing.
  List<Widget> _fontFamilyItems() {
    final current = PlayerSettings.popularFonts.contains(PlayerSettings.subFont.value)
        ? PlayerSettings.subFont.value
        : 'subfont';
    return [
      _buildSectionTitle(context.l10n.subStyleFontFamily.toUpperCase()),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: PlayerSettings.popularFonts.map((f) {
          final isDefault = f == 'subfont';
          return _buildChoiceChip(
            selected: f == current,
            onTap: () => PlayerSettings.setSubFont(f, player: widget.player),
            child: Text(
              isDefault ? context.l10n.subStyleFontDefault : f,
              style: TextStyle(
                color: f == current ? Colors.white : PlayerTheme.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: isDefault ? 'Poppins' : f,
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _sizeItems() {
    return [
        // Base Font Size Slider
        _buildSectionTitle(context.l10n.subStyleBaseFontSize(PlayerSettings.subFontSize.value.round()).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subFontSize.value.toDouble(),
            min: 16.0,
            max: 72.0,
            divisions: 28,
            onChanged: (v) => PlayerSettings.setSubFontSize(v.round(), player: widget.player),
          ),
        ),
        const SizedBox(height: 8),
    ];
  }

  List<Widget> _scaleItems() {
    return [
        // Scale Multiplier Slider
        _buildSectionTitle(context.l10n.subStyleScale((PlayerSettings.subScale.value * 100).round()).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subScale.value,
            min: 0.5,
            max: 2.5,
            divisions: 20,
            onChanged: (v) => PlayerSettings.setSubScale(v, player: widget.player),
          ),
        ),
        const SizedBox(height: 8),
    ];
  }

  List<Widget> _boldItems() {
    return [
        // Bold and Italic Toggles
        Row(
          children: [
            Expanded(
              child: _buildToggleTile(
                title: context.l10n.subStyleBold,
                icon: Icons.format_bold_rounded,
                value: PlayerSettings.subBold.value,
                onChanged: (val) => PlayerSettings.setSubBold(val, player: widget.player),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToggleTile(
                title: context.l10n.subStyleItalic,
                icon: Icons.format_italic_rounded,
                value: PlayerSettings.subItalic.value,
                onChanged: (val) => PlayerSettings.setSubItalic(val, player: widget.player),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _textColorItems() {
    final activeColor = PlayerSettings.subColor.value;
    return [
        // Text Color Palette
        _buildSectionTitle(context.l10n.subStyleTextColor.toUpperCase()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _textColorPalette.map((item) {
            final isSelected = activeColor.toLowerCase() == (item['hex'] as String).toLowerCase();
            return _buildChoiceChip(
              selected: isSelected,
              onTap: () => PlayerSettings.setSubColor(item['hex'], player: widget.player),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flexible: at a large text scale the name is wider than
                  // the panel, and a Row sizes its children to their natural
                  // width unless one may give.
                  Flexible(
                    child: Text(
                      _paletteName(context.l10n, item['name'] as String),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
    ];
  }

  /// The background as one slider, from none to solid. It was a list of six
  /// boxes -- "25% dark", "50% dark", ... "50% indigo" -- which were a slider
  /// with the steps hard-coded and one odd tint. The color is kept as it is;
  /// only its strength moves.
  List<Widget> _boxItems() {
    final hex = PlayerSettings.subBackColor.value;
    final percent = (subtitleBackgroundOpacity(hex) * 100).round();
    return [
      _buildSectionTitle(context.l10n.subStyleBackgroundOpacity(percent).toUpperCase()),
      SliderTheme(
        data: _sliderTheme(),
        child: Slider(
          value: (percent / 5).round() * 5 / 100,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          onChanged: (v) => PlayerSettings.setSubBackColor(withSubtitleBackgroundOpacity(hex, v), player: widget.player),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _outlineColorItems() {
    final activeBorderColor = PlayerSettings.subBorderColor.value;
    return [
        // Outline Color Selector
        _buildSectionTitle(context.l10n.subStyleOutlineColor.toUpperCase()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _borderColorPalette.map((item) {
            final isSelected = activeBorderColor.toLowerCase() == (item['hex'] as String).toLowerCase();
            return _buildChoiceChip(
              selected: isSelected,
              onTap: () => PlayerSettings.setSubBorderColor(item['hex'], player: widget.player),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flexible: at a large text scale the name is wider than
                  // the panel, and a Row sizes its children to their natural
                  // width unless one may give.
                  Flexible(
                    child: Text(
                      _paletteName(context.l10n, item['name'] as String),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
    ];
  }

  List<Widget> _thicknessItems() {
    return [
        // Outline Thickness Slider
        _buildSectionTitle(context.l10n.subStyleOutlineThickness(PlayerSettings.subBorderSize.value.toStringAsFixed(1)).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subBorderSize.value,
            min: 0.0,
            max: 6.0,
            divisions: 12,
            onChanged: (v) => PlayerSettings.setSubBorderSize(v, player: widget.player),
          ),
        ),
        const SizedBox(height: 8),
    ];
  }

  List<Widget> _shadowItems() {
    return [
        // Drop Shadow Offset Slider
        _buildSectionTitle(context.l10n.subStyleShadowOffset(PlayerSettings.subShadowOffset.value.toStringAsFixed(1)).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subShadowOffset.value,
            min: 0.0,
            max: 6.0,
            divisions: 12,
            onChanged: (v) => PlayerSettings.setSubShadowOffset(v, player: widget.player),
          ),
        ),
        const SizedBox(height: 8),
    ];
  }

  List<Widget> _alignItems() {
    return [
        // Horizontal Alignment
        _buildSectionTitle(context.l10n.subStyleHAlign.toUpperCase()),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAlignButton(context.l10n.subStyleLeft, 'left', Icons.format_align_left_rounded),
            const SizedBox(width: 8),
            _buildAlignButton(context.l10n.subStyleCenter, 'center', Icons.format_align_center_rounded),
            const SizedBox(width: 8),
            _buildAlignButton(context.l10n.subStyleRight, 'right', Icons.format_align_right_rounded),
          ],
        ),
        const SizedBox(height: 18),
    ];
  }

  List<Widget> _marginItems() {
    return [
        // Bottom Margin
        _buildSectionTitle(context.l10n.subStyleBottomMargin(PlayerSettings.subMarginY.value.round()).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subMarginY.value,
            min: 10.0,
            max: 150.0,
            divisions: 28,
            onChanged: (v) => PlayerSettings.setSubMarginY(v, player: widget.player),
          ),
        ),
        const SizedBox(height: 8),
    ];
  }

  List<Widget> _vposItems() {
    return [
        // Vertical Screen Position
        _buildSectionTitle(context.l10n.subStyleVPosition(PlayerSettings.subPos.value.round()).toUpperCase()),
        SliderTheme(
          data: _sliderTheme(),
          child: Slider(
            value: PlayerSettings.subPos.value,
            min: 0.0,
            max: 100.0,
            divisions: 20,
            onChanged: (v) => PlayerSettings.setSubPos(v, player: widget.player),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.subStyleTop, style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11)),
              Text(context.l10n.subStyleBottom, style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11)),
            ],
          ),
        ),
    ];
  }

  Widget _buildAlignButton(String title, String alignVal, IconData icon) {
    final isSelected = PlayerSettings.subAlignX.value == alignVal;
    return Expanded(
      child: InkWell(
        onTap: () => PlayerSettings.setSubAlignX(alignVal, player: widget.player),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? PlayerTheme.accent : PlayerTheme.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : PlayerTheme.inkSubtle, size: 18),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : PlayerTheme.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The two switches that used to be a whole tab. A four-way choice of how
  /// hard to override styled (SSA/ASS) subtitles, and a radio pair for the
  /// rendering engine, came down to: use my style on styled subtitles or not,
  /// and whether to let libass draw. The saved values are unchanged, so the
  /// old "scale only" and "force" modes still work if they were chosen; they
  /// show as "on".
  List<Widget> _advancedItems() {
    final l10n = context.l10n;
    return [
      _buildSectionTitle(l10n.subStyleAssMode.toUpperCase()),
      const SizedBox(height: 8),
      _buildSwitchCard(
        title: l10n.subStyleAssApply,
        description: l10n.subStyleAssApplyDesc,
        value: PlayerSettings.subAssOverride.value != 'no',
        onChanged: (on) => PlayerSettings.setSubAssOverride(on ? 'yes' : 'no', player: widget.player),
      ),
      const SizedBox(height: 10),
      _buildSwitchCard(
        title: l10n.subStyleNativeEngine,
        description: l10n.subStyleNativeEngineDesc,
        value: PlayerSettings.useLibass.value,
        onChanged: (on) => PlayerSettings.setUseLibass(on, player: widget.player),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildSwitchCard({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: PlayerTheme.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlayerTheme.edgeSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: PlayerTheme.ink, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: PlayerTheme.inkSubtle, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: PlayerTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: PlayerTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: PlayerTheme.ink, fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper Component Builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: PlayerTheme.inkSubtle,
        letterSpacing: 1.1,
      ),
    );
  }

  /// A selectable pill: a swatch or a font name. One widget for the colors and
  /// the fonts, so they select, focus and size the same way.
  Widget _buildChoiceChip({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? PlayerTheme.accent : PlayerTheme.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? PlayerTheme.accentGlow : PlayerTheme.edgeSoft),
        ),
        child: child,
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PlayerTheme.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlayerTheme.edgeSoft),
      ),
      child: Row(
        children: [
          // Expanded, with the title free to wrap: two of these tiles share a
          // row, so on a 360px phone each is under 170px wide and the fixed
          // icon + title + switch came to more than that, in English too.
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: PlayerTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      activeTrackColor: PlayerTheme.accent,
      inactiveTrackColor: Colors.white12,
      thumbColor: Colors.white,
    );
  }
}

