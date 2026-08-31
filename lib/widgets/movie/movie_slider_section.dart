import 'package:flutter/material.dart';

import '../../models/movie/movie_section.dart';
import '../../pages/catalog/catalog_page.dart';
import '../../utils/navigation/route_transitions.dart';
import './movie_card.dart';
import '../common/horizontal_slider_scroll.dart';
import '../common/section_header.dart';
import '../common/slider_arrow.dart';

class MovieSliderSection extends StatefulWidget {
  final MovieSection section;

  const MovieSliderSection({
    super.key,
    required this.section,
  });

  @override
  State<MovieSliderSection> createState() => _MovieSliderSectionState();
}

class _MovieSliderSectionState extends State<MovieSliderSection>
    with HorizontalSliderScroll<MovieSliderSection> {
  Offset? _tapPosition;
  bool _isHoveringSlider = false;

  @override
  Widget build(BuildContext context) {
    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);
    final isDesktop = isDesktopPlatform();

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Listener(
            onPointerDown: (event) => _tapPosition = event.position,
            child: SectionHeader(
              title: widget.section.title,
              subtitle: widget.section.subtitle,
              onSeeAll: () {
                Navigator.push(
                  context,
                  LiquidRevealRoute(
                    page: CatalogPage(section: widget.section),
                    tapPosition: _tapPosition,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringSlider = true),
            onExit: (_) => setState(() => _isHoveringSlider = false),
            child: SizedBox(
              height: sizing.totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListView.separated(
                    clipBehavior: Clip.none,
                    controller: sliderScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding),
                    itemCount: widget.section.movies.length,
                    separatorBuilder: (context, index) {
                      return SizedBox(width: sizing.spacing);
                    },
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: sizing.cardWidth,
                        child: MovieCard(movie: widget.section.movies[index]),
                      );
                    },
                  ),
                  
                  // Desktop Scroll Arrows
                  if (isDesktop) ...[
                    // Left Arrow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
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

                    // Right Arrow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
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
