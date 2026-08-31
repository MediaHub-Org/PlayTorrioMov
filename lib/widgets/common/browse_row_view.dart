import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import '../movie/movie_card.dart';
import 'section_header.dart';
import 'slider_arrow.dart';

/// One horizontal row of poster cards: a [SectionHeader], a horizontally
/// scrolling list, and scroll arrows that fade in on hover.
///
/// The single row implementation in the app. [BrowseScaffold] builds its rows
/// from it, and [AnimeSliderSection] wraps it — before that they were two
/// copies of the same widget with the same `MovieCardSizing`, the same
/// `SectionHeader` and the same arrows, sitting on adjacent screens and free
/// to drift apart.
///
/// Its own widget, rather than a method on the scaffold, because each row
/// needs its own [ScrollController] and its own "can I still scroll this way"
/// state; holding those centrally would mean a map keyed by row and a rebuild
/// of every row whenever one of them scrolled.
class BrowseRowView<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<T> items;
  final VoidCallback? onSeeAll;

  /// Builds one card. Given a box already sized to [MovieCardSizing.cardWidth].
  final Widget Function(BuildContext context, T item) itemBuilder;

  const BrowseRowView({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.subtitle,
    this.onSeeAll,
  });

  @override
  State<BrowseRowView<T>> createState() => _BrowseRowViewState<T>();
}

class _BrowseRowViewState<T> extends State<BrowseRowView<T>> {
  final ScrollController _controller = ScrollController();
  bool _hovering = false;
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEdges);
    // Scroll extents are unknown until the first layout, so without this the
    // right arrow would never appear on a row nobody has scrolled yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateEdges);
    _controller.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final left = p.pixels > 10;
    final right = p.pixels < p.maxScrollExtent - 10;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  /// Scrolls by just under a viewport, so the card at the edge stays partly
  /// visible — a full-viewport jump loses the reader's place.
  void _scrollBy(double direction) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + direction * p.viewportDimension * 0.8)
        .clamp(0.0, p.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final sizing = MovieCardSizing.fromWidth(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: widget.title,
          subtitle: widget.subtitle,
          onSeeAll: widget.onSeeAll,
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: SizedBox(
            height: sizing.totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.separated(
                  clipBehavior: Clip.none,
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: sizing.sidePadding),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => SizedBox(width: sizing.spacing),
                  itemBuilder: (context, i) => SizedBox(
                    width: sizing.cardWidth,
                    child: widget.itemBuilder(context, widget.items[i]),
                  ),
                ),
                // Gated on hover alone. A platform or width check would be a
                // proxy for "has a pointer", and a wrong one both ways: a
                // Windows tablet in touch mode would get arrows it cannot
                // hover, and an Android device with a mouse would not get
                // them. A touch device never fires onEnter, so hover is the
                // direct answer.
                _Arrow(
                  visible: _canLeft && _hovering,
                  alignLeft: true,
                  onTap: () => _scrollBy(-1),
                ),
                _Arrow(
                  visible: _canRight && _hovering,
                  alignLeft: false,
                  onTap: () => _scrollBy(1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  final bool visible;
  final bool alignLeft;
  final VoidCallback onTap;

  const _Arrow({
    required this.visible,
    required this.alignLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: alignLeft ? (visible ? 10 : -60) : null,
      right: alignLeft ? null : (visible ? 10 : -60),
      top: 0,
      bottom: 0,
      child: Center(
        child: SliderArrow(
          icon: alignLeft
              ? Icons.arrow_back_ios_new_rounded
              : Icons.arrow_forward_ios_rounded,
          onTap: onTap,
        ),
      ),
    );
  }
}
