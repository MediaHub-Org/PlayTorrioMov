import 'package:flutter/material.dart';

import '../../models/stream/stream_model.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

const Color _kHealthy = Color(0xFF51CF66);
const Color _kThin = Color(0xFFFBBF24);
const Color _kStalled = Color(0xFFFF6B6B);

/// How likely a torrent is to actually start playing, by seed count.
///
/// The thresholds are deliberately blunt -- the useful question in a source
/// list is "will this start, or should I pick the one under it", not the
/// exact number. Under ten seeds a stream regularly never buffers at all,
/// which is the case worth coloring red.
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
      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.rem(0.625), color: color),
            SizedBox(width: context.rem(0.1875)),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: TvType.scale(AppType.micro),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// How healthy a torrent is -- the one delivery fact worth a pill.
///
/// Every source picker shows this, so the same source reads the same way
/// whether you reached it from a movie, a series episode, an anime episode,
/// or the panel inside the player. [StreamSource.seeders] was already being
/// parsed out of the source title and then never shown anywhere, which left
/// the seed count, the single most useful signal for picking between two
/// otherwise identical torrents, invisible.
///
/// There is no "HTTP" or "P2P" pill any more. They were neutral gray, present
/// on every row, and so told nobody anything: a torrent is recognizable by
/// its seed count, and a direct link by its absence. On a TV, where #80's
/// feedback was that the rows carry too many tags, that was a pill per row
/// spent on nothing. The Watch Sources rows dropped them first; the
/// in-player panel and the anime episode sheet now match.
List<Widget> sourceDeliveryBadges(StreamSource source) {
  final seeders = source.isMagnet ? source.seeders : null;
  if (seeders == null) return const [];
  return [
    SourceBadge(
      '$seeders',
      seedHealthColor(seeders),
      icon: Icons.arrow_upward_rounded,
    ),
  ];
}
