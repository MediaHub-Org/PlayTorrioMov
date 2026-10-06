import 'package:flutter/material.dart';

import '../../models/movie/movie_section.dart';
import '../../pages/catalog/catalog_page.dart';
import '../../utils/navigation/route_transitions.dart';
import './movie_card.dart';
import '../common/horizontal_slider_scroll.dart';
import '../common/section_header.dart';
import '../common/slider_arrow.dart';
import '../../services/app_units.dart';

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
  bool _isHoveringSlider = false;

  @override
  Widget build(BuildContext context) {
    final sizing = MovieCardSizing.of(context);
    final isDesktop = isDesktopPlatform();

    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(1.625)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: widget.section.title,
            subtitle: widget.section.subtitle,
            onSeeAll: () {
              pushPage(context, CatalogPage(section: widget.section));
            },
          ),
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
                  if (isDesktop)
                    RailEdgeArrows(
                      visible: _isHoveringSlider,
                      canGoPrevious: canScrollLeft,
                      canGoNext: canScrollRight,
                      onPrevious: () => scrollSlider(-1),
                      onNext: () => scrollSlider(1),
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
