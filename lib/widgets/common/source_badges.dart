import 'package:flutter/material.dart';

import '../../models/stream/stream_model.dart';

/// Neutral badge tint, for facts that describe a source rather than rank it
/// (codec, file size, how it is delivered).
const Color kSourceBadgeNeutral = Color(0xFF66666B);

const Color _kHealthy = Color(0xFF51CF66);
const Color _kThin = Color(0xFFFBBF24);
const Color _kStalled = Color(0xFFFF6B6B);

/// How likely a torrent is to actually start playing, by seed count.
///
/// The thresholds are deliberately blunt -- the useful question in a source
/// list is "will this start, or should I pick the one under it", not the
/// exact number. Under ten seeds a stream regularly never buffers at all,
/// which is the case worth colouring red.
Color seedHealthColor(int seeders) {
  if (seeders >= 50) return _kHealthy;
  if (seeders >= 10) return _kThin;
  return _kStalled;
}

/// One small pill in a stream source's badge row.
class SourceBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const SourceBadge(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// How a source is delivered, and -- for a torrent -- how healthy it is.
///
/// Every source picker shows these, so the same source reads the same way
/// whether you reached it from a movie, a series episode, an anime episode,
/// or the panel inside the player. [StreamSource.seeders] was already being
/// parsed out of the source title and then never shown anywhere, which left
/// the seed count, the single most useful signal for picking between two
/// otherwise identical torrents, invisible.
List<Widget> sourceDeliveryBadges(StreamSource source) {
  if (!source.isMagnet) {
    return const [SourceBadge('HTTP', kSourceBadgeNeutral)];
  }

  final seeders = source.seeders;
  return [
    const SourceBadge('P2P', kSourceBadgeNeutral),
    if (seeders != null)
      SourceBadge(
        '$seeders',
        seedHealthColor(seeders),
        icon: Icons.arrow_upward_rounded,
      ),
  ];
}
