import 'package:flutter/material.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../common/browse_row_view.dart';
import 'iptv_channel_card.dart';

class IptvCardSizing {
  final double cardWidth;
  final double posterHeight;
  final double totalHeight;
  final double spacing;
  final double sidePadding;

  const IptvCardSizing({
    required this.cardWidth,
    required this.posterHeight,
    required this.totalHeight,
    required this.spacing,
    required this.sidePadding,
  });

  factory IptvCardSizing.fromWidth(double screenWidth) {
    double cardWidth;
    if (screenWidth < 600) {
      cardWidth = 145;
    } else if (screenWidth < 1000) {
      cardWidth = 165;
    } else if (screenWidth < 1400) {
      cardWidth = 185;
    } else {
      cardWidth = 205;
    }

    final posterHeight = cardWidth * 1.35;
    final totalHeight = posterHeight + 66;

    return IptvCardSizing(
      cardWidth: cardWidth,
      posterHeight: posterHeight,
      totalHeight: totalHeight,
      spacing: 16,
      sidePadding: 18,
    );
  }

  RowCardSizing toRowSizing() => RowCardSizing(
        cardWidth: cardWidth,
        totalHeight: totalHeight,
        spacing: spacing,
        sidePadding: sidePadding,
      );
}

/// A Live TV channel row: a [BrowseRowView] with [IptvChannelCard] as the
/// item builder, sized to [IptvCardSizing]'s logo/banner shape instead of
/// [BrowseRowView]'s default poster shape.
///
/// Used to be a full second copy of the row -- its own `MouseRegion`,
/// `SectionHeader`, hover-arrow `Stack` and scroll-edge tracking, all
/// hand-rolled again. That meant Live TV's row could drift from Movies',
/// Series' and Anime's on spacing, arrow behaviour or hover feel with
/// nothing to stop it. The one visual difference that's real -- channel
/// cards being a wider, shorter shape than a poster -- stays real: it comes
/// through [BrowseRowView.sizingOf], not from forcing every row through the
/// same aspect ratio.
class IptvSliderSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<HardcodedChannel> channels;
  final Function(HardcodedChannel) onChannelTap;
  final VoidCallback? onSeeAll;

  const IptvSliderSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.channels,
    required this.onChannelTap,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return BrowseRowView<HardcodedChannel>(
      title: title,
      subtitle: subtitle,
      items: channels,
      onSeeAll: onSeeAll,
      sizingOf: (width) => IptvCardSizing.fromWidth(width).toRowSizing(),
      itemBuilder: (context, channel) => IptvChannelCard(
        channel: channel,
        onTap: () => onChannelTap(channel),
      ),
    );
  }
}
