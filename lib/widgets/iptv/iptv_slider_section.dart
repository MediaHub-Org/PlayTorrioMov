import 'package:flutter/material.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../common/horizontal_slider_scroll.dart';
import '../common/section_header.dart';
import '../common/slider_arrow.dart';
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
}

class IptvSliderSection extends StatefulWidget {
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
  State<IptvSliderSection> createState() => _IptvSliderSectionState();
}

class _IptvSliderSectionState extends State<IptvSliderSection>
    with HorizontalSliderScroll<IptvSliderSection> {
  bool _isHoveringSlider = false;

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    final sizing = IptvCardSizing.fromWidth(MediaQuery.sizeOf(context).width);
    final isDesktop = isDesktopPlatform();

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header matching Home & Anime Pages
          SectionHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            onSeeAll: widget.onSeeAll,
          ),

          // Horizontal List with Desktop Navigation Arrows
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringSlider = true),
            onExit: (_) => setState(() => _isHoveringSlider = false),
            child: SizedBox(
              height: sizing.totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    controller: sliderScrollController,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding),
                    physics: const BouncingScrollPhysics(),
                    itemCount: widget.channels.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(width: sizing.spacing),
                    itemBuilder: (context, index) {
                      final ch = widget.channels[index];
                      return SizedBox(
                        width: sizing.cardWidth,
                        child: IptvChannelCard(
                          channel: ch,
                          onTap: () => widget.onChannelTap(ch),
                        ),
                      );
                    },
                  ),

                  // Desktop Floating Scroll Arrows
                  if (isDesktop) ...[
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: canScrollLeft && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => scrollSlider(-1),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      right: canScrollRight && _isHoveringSlider ? 10 : -60,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SliderArrow(
                          icon: Icons.arrow_forward_ios_rounded,
                          onTap: () => scrollSlider(1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
