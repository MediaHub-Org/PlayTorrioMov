import 'package:flutter/material.dart';
import 'player_glass.dart';

class AspectOption {
  final String id;
  final String label;

  /// The [BoxFit] handed to the video widget. Null when this option forces a
  /// ratio instead — see [forcedRatio].
  final BoxFit? fit;

  /// The aspect ratio (width / height) the picture is forced into, when this
  /// option is a ratio override rather than a fit mode. Null for the fit
  /// modes, which keep whatever shape the source has.
  final double? forcedRatio;

  const AspectOption.fit(this.id, this.label, this.fit) : forcedRatio = null;

  const AspectOption.ratio(this.id, this.label, this.forcedRatio) : fit = null;
}

const List<AspectOption> aspectOptions = [
  // BoxFit.contain *is* the original shape: it scales the picture to the
  // largest size that fits whole, preserving the source's own aspect ratio
  // and letterboxing the rest. It was labelled "Fit to screen (Contain)"
  // before, which read as a mode rather than an answer to "show it the way
  // it was shot" -- the label now says that.
  AspectOption.fit('original', 'Original (keeps the source shape)', BoxFit.contain),
  AspectOption.fit('cover', 'Fill screen (crops the edges)', BoxFit.cover),
  AspectOption.fit('fill', 'Stretch to fill (distorts)', BoxFit.fill),
  // Ratio overrides, for the two shapes old content is most often trapped
  // in. A 4:3 film mis-tagged as 16:9 shows squeezed in Original; forcing
  // the ratio re-squares it. Done by wrapping the video in an AspectRatio,
  // not by a BoxFit -- BoxFit has no "force this shape" mode.
  AspectOption.ratio('16:9', 'Force 16:9 (widescreen)', 16 / 9),
  AspectOption.ratio('4:3', 'Force 4:3 (classic TV)', 4 / 3),
];

/// The human label for the current picture mode, for the settings row.
String aspectLabelFor(BoxFit fit, double? forcedRatio) {
  if (forcedRatio != null) {
    for (final opt in aspectOptions) {
      if (opt.forcedRatio != null &&
          (opt.forcedRatio! - forcedRatio).abs() < 0.001) {
        return opt.label
            .replaceAll('Force ', '')
            .replaceAll(' (widescreen)', '')
            .replaceAll(' (classic TV)', '');
      }
    }
  }
  return switch (fit) {
    BoxFit.cover => 'Fill',
    BoxFit.fill => 'Stretch',
    _ => 'Original',
  };
}

/// Aspect ratio and picture popover menu.
///
/// Owns only the picture's shape. Subtitle size used to live here too, a
/// slider under the aspect list, which is where nobody looking for subtitle
/// settings would find it -- it moved into the subtitle appearance panel.
class PlayerAspectMenu extends StatelessWidget {
  final BoxFit currentFit;

  /// The ratio currently forced, or null when the picture keeps its own
  /// shape. Used both to tick the right row and to untick the fit rows.
  final double? currentForcedRatio;
  final ValueChanged<BoxFit> onFitSelected;
  final ValueChanged<double> onRatioSelected;
  final VoidCallback onClose;

  /// Back to the settings root, when this menu was stepped into from
  /// there rather than opened directly.
  final VoidCallback? onBack;

  const PlayerAspectMenu({
    super.key,
    required this.currentFit,
    this.currentForcedRatio,
    required this.onFitSelected,
    required this.onRatioSelected,
    required this.onClose,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return PlayerGlassCard(
      width: (320.0).clamp(240.0, screenWidth - 32),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayerMenuHeader(
            title: 'ASPECT RATIO',
            onBack: onBack,
          ),

          const SizedBox(height: 6),

          // Aspect Options List
          Column(
            children: aspectOptions.map((opt) {
              final isSelected = opt.fit != null
                  ? (currentForcedRatio == null && currentFit == opt.fit)
                  : ((currentForcedRatio ?? 0) - (opt.forcedRatio ?? 0)).abs() <
                      0.001;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (opt.fit != null) {
                      onFitSelected(opt.fit!);
                    } else {
                      onRatioSelected(opt.forcedRatio!);
                    }
                    onClose();
                  },
                  child: Container(
                    // A minimum, not a fixed height: the label grows with
                    // text scale and the row had nowhere to put it -- 685px
                    // past the card at 3x. PlayerMenuAnchor bounds and
                    // scrolls the card, so growing here is safe.
                    constraints: const BoxConstraints(minHeight: 38),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? PlayerTheme.raised : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? PlayerTheme.edge : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Flexible so the label yields to the check icon
                        // rather than pushing it off the edge.
                        Flexible(
                          child: Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? PlayerTheme.ink : PlayerTheme.inkMuted,
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: PlayerTheme.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
