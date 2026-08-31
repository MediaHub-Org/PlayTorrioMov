import 'package:flutter/material.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import 'iptv_channel_sheet.dart';

class IptvSearchPage extends StatefulWidget {
  const IptvSearchPage({super.key});

  @override
  State<IptvSearchPage> createState() => _IptvSearchPageState();
}

class _IptvSearchPageState extends State<IptvSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Combat',
    'Racing',
    'Sports',
    'Movies',
    'News',
    'Arabic',
    'Discovery',
    'Kids',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HardcodedChannel> _filteredChannels() {
    return HardcodedChannels.all.where((c) {
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.short.toLowerCase().contains(q) ||
          c.keywords.any((k) => k.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final channels = _filteredChannels();
    final width = MediaQuery.sizeOf(context).width;

    // Responsive columns
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 6;
    } else if (width > 900) {
      crossAxisCount = 5;
    } else if (width > 600) {
      crossAxisCount = 4;
    } else if (width > 420) {
      crossAxisCount = 3;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search 60+ live channels, leagues, networks…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13.5),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C5CFF), size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category Pills Filter
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C5CFF)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7C5CFF)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Channel Grid
          Expanded(
            child: channels.isEmpty
                ? const Center(
                    child: Text('No channels match your search.', style: TextStyle(color: Colors.white54)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      return IptvChannelCard(
                        channel: ch,
                        onTap: () => IptvChannelSheet.show(context, ch),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
