import 'package:flutter/material.dart';

import 'pill_tab_row.dart';

/// A reusable tabbed "Library" scaffold shared by the Media, Music, and Books
/// hubs so they all present their library content with a consistent design.
///
/// Each hub supplies its own [tabs]; the widget renders a header with the
/// [title] and a [PillTabRow] + [TabBarView] -- the same pill-tag visual
/// language Watch/Anime use for their own type switch, rather than the
/// underline-indicator [TabBar] this used to render.
class LibraryTabs extends StatefulWidget {
  final String title;
  final IconData titleIcon;
  final List<LibraryTab> tabs;
  final int initialIndex;
  final Widget? trailing;

  const LibraryTabs({
    super.key,
    required this.title,
    required this.titleIcon,
    required this.tabs,
    this.initialIndex = 0,
    this.trailing,
  });

  @override
  State<LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<LibraryTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _activeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _activeId = _idOf(widget.initialIndex);
    // Swiping the TabBarView (not just tapping a pill) must move the pill
    // selection too -- animateTo fires this listener at both ends.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final id = _idOf(_tabController.index);
      if (id != _activeId) setState(() => _activeId = id);
    });
  }

  String _idOf(int index) => index.toString();

  void _selectPill(String id) {
    final index = int.parse(id);
    setState(() => _activeId = id);
    _tabController.animateTo(index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.titleIcon, color: const Color(0xFF7C5CFF), size: 22),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (widget.trailing != null) widget.trailing!,
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PillTabRow(
                tabs: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    SubTab(
                      id: _idOf(i),
                      label: widget.tabs[i].label,
                      icon: widget.tabs[i].icon,
                    ),
                ],
                activeId: _activeId,
                onSelected: _selectPill,
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: widget.tabs.map((t) => t.builder(context)).toList(),
      ),
    );
  }
}

/// A single tab within a [LibraryTabs].
class LibraryTab {
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  const LibraryTab({
    required this.label,
    required this.icon,
    required this.builder,
  });
}

/// A shared empty-state used across library tabs.
class LibraryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const LibraryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
