import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../widgets/common/first_focus_scope.dart';
import '../../widgets/common/glass_back_button.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import 'iptv_channel_sheet.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

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
    AppColors.dependOn(context);
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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Same leading inset as every other page's back button; AppBar's
        // own 56px leading slot would center it somewhere else again.
        // + kMinInteractiveDimension: GlassBackButton is a 48x48
        // IconButton, and a narrower slot clamps it into an ellipse.
        leadingWidth: AppSpacing.pageInset(context) + context.rem(3),
        leading: Padding(
          padding: EdgeInsetsDirectional.only(start: AppSpacing.pageInset(context)),
          child: const Center(child: GlassBackButton()),
        ),
        title: Container(
          height: context.rem(2.75),
          decoration: BoxDecoration(
            color: AppColors.inkAlpha(0.08),
            borderRadius: BorderRadius.circular(context.rem(0.875)),
            border: Border.all(color: AppColors.inkAlpha(0.15)),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
            decoration: InputDecoration(
              hintText: context.l10n.iptvSearchLiveHint,
              hintStyle: TextStyle(color: AppColors.inkAlpha(0.4), fontSize: AppType.smallPlus),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent, size: context.rem(AppRem.icon)),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      tooltip: context.l10n.commonClose,
                      icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle, size: context.rem(AppRem.iconSm)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: context.rem(0.6875)),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category Pills Filter
          SizedBox(
            height: AppSpacing.textScaledHeight(context, 48),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.rem(1.25), vertical: context.rem(AppRem.sm)),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => SizedBox(width: context.rem(AppRem.sm)),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;

                return HoverButton(
                  scaleAmount: 1.05,
                  focusFillRadius: context.rem(1.25),
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.snug)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.inkAlpha(0.06),
                      borderRadius: BorderRadius.circular(context.rem(1.25)),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.inkAlpha(0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? AppColors.ink : AppColors.inkMuted,
                          fontSize: AppType.captionPlus,
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
                ? Center(
                    child: Text(context.l10n.iptvNoChannelsMatch, style: TextStyle(color: AppColors.inkSubtle)),
                  )
                : FirstFocusScope(
                    // The isEmpty branch above already handles the other case.
                    ready: true,
                    child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(context.rem(1.25), context.rem(AppRem.ms), context.rem(1.25), context.rem(1.875)),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: context.rem(0.875),
                      mainAxisSpacing: context.rem(AppRem.md),
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
          ),
        ],
      ),
    );
  }
}
