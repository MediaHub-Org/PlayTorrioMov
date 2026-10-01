import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/iptv/iptv_models.dart';
import '../../services/iptv/custom_channels_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../utils/navigation/adaptive_sheet.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/hover_button.dart';
import '../../widgets/common/like_button.dart';
import 'iptv_player_page.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class IptvChannelSheet extends StatefulWidget {
  final HardcodedChannel channel;

  const IptvChannelSheet({super.key, required this.channel});

  static Future<void> show(BuildContext context, HardcodedChannel channel) {
    return showAdaptiveSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IptvChannelSheet(channel: channel),
    );
  }

  @override
  State<IptvChannelSheet> createState() => _IptvChannelSheetState();
}

class _IptvChannelSheetState extends State<IptvChannelSheet> {
  final _ctrl = IptvController.instance;

  bool _isSelecting = false;
  final Set<String> _selectedUrls = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl.openHardcodedChannel(widget.channel);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playHit(ChannelHit hit) {
    final results = _ctrl.channelResults;
    if (results.isEmpty) return;
    final index = results.indexOf(hit);
    Navigator.pop(context);
    pushPage(
      context,
      IptvPlayerPage(
        channel: widget.channel,
        hits: results,
        initialHitIndex: index >= 0 ? index : 0,
        isLive: true,
      ),
    );
  }

  void _toggleSelection(String streamUrl) {
    setState(() {
      if (_selectedUrls.contains(streamUrl)) {
        _selectedUrls.remove(streamUrl);
      } else {
        _selectedUrls.add(streamUrl);
      }
    });
  }

  Future<void> _deleteSelectedStreams() async {
    if (_selectedUrls.isEmpty) return;
    final count = _selectedUrls.length;
    final toDelete = Set<String>.from(_selectedUrls);
    setState(() {
      _selectedUrls.clear();
      _isSelecting = false;
    });
    await _ctrl.removeChannelHits(widget.channel.id, toDelete);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.iptvRemovedFeeds(count)),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.raised,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final ch = widget.channel;
    final primaryColor = ch.gradient.isNotEmpty ? ch.gradient.first : AppColors.accent;
    final secondaryColor = ch.gradient.length > 1 ? ch.gradient.last : const Color(0xFF00D2EF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final results = _ctrl.channelResults;
        final isScanning = _ctrl.channelIsRunning;
        final status = _ctrl.channelStatus;
        final filteredResults = _searchQuery.trim().isEmpty
            ? results
            : results.where((hit) {
                final q = _searchQuery.trim().toLowerCase();
                final nameMatches = hit.stream.name.toLowerCase().contains(q);
                final portalMatches = hit.portal.name.toLowerCase().contains(q) ||
                    hit.portal.portal.username.toLowerCase().contains(q);
                final formatMatches = hit.stream.containerExt.toLowerCase().contains(q);
                return nameMatches || portalMatches || formatMatches;
              }).toList();
        final allSelected = results.isNotEmpty && _selectedUrls.length == results.length;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(context.rem(1.75))),
            border: Border.all(color: AppColors.inkAlpha(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                blurRadius: context.rem(1.875),
                offset: Offset(0, -context.rem(0.625)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: context.rem(AppRem.ms), bottom: context.rem(AppRem.sm)),
                  width: context.rem(2.75),
                  height: context.rem(0.2812),
                  decoration: BoxDecoration(
                    color: AppColors.inkAlpha(0.2),
                    borderRadius: BorderRadius.circular(context.rem(0.1875)),
                  ),
                ),
              ),

              // Header Banner
              Padding(
                padding: EdgeInsets.fromLTRB(context.rem(1.375), context.rem(0.625), context.rem(AppRem.md), context.rem(0.625)),
                child: Row(
                  children: [
                    // Channel Short / Icon Badge
                    Container(
                      width: context.rem(3.25),
                      height: context.rem(3.25),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(context.rem(0.875)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primaryColor, secondaryColor],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: context.rem(AppRem.ms),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          ch.short,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: AppType.bodyLg,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: context.rem(0.875)),

                    // Title & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                                ),
                                child: Text(
                                  context.l10n.iptvLive.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.onAccent,
                                    fontSize: TvType.scale(AppType.nano),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              SizedBox(width: context.rem(AppRem.snug)),
                              Text(
                                ch.category,
                                style: TextStyle(
                                  color: AppColors.inkAlpha(0.5),
                                  fontSize: AppType.caption,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.rem(0.1875)),
                          Text(
                            ch.name,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: AppType.titleSm,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Favorite (save to Library) toggle
                    ValueListenableBuilder<List<FavoriteChannel>>(
                      valueListenable: FavoriteChannelsService.items,
                      builder: (context, _, _) {
                        final isFav = FavoriteChannelsService.isFavorite(ch.id);
                        return LikeButton(
                          isLiked: isFav,
                          onTap: () => FavoriteChannelsService.toggle(ch.id),
                          style: LikeButtonStyle.icon,
                        );
                      },
                    ),

                    // Delete, for a channel the user made themselves. A
                    // built-in has nothing to delete -- it is catalog data --
                    // so this is the only place a custom one can be undone,
                    // and a channel you can create but never remove is a
                    // trap.
                    if (CustomChannelsService.isCustom(ch.id))
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.inkMuted,
                          size: context.rem(AppRem.iconMd),
                        ),
                        tooltip: context.l10n.iptvDeleteChannel,
                        onPressed: () async {
                          await CustomChannelsService.remove(ch.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),

                    // Pen / Edit Button
                    if (results.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _isSelecting ? Icons.edit_off_rounded : Icons.edit_rounded,
                          color: _isSelecting ? const Color(0xFF00D2EF) : AppColors.inkMuted,
                          size: context.rem(AppRem.iconMd),
                        ),
                        tooltip: _isSelecting ? 'Cancel Selection' : 'Manage / Delete Channels',
                        onPressed: () {
                          setState(() {
                            _isSelecting = !_isSelecting;
                            if (!_isSelecting) _selectedUrls.clear();
                          });
                        },
                      ),

                    // Close Button
                    IconButton(
                      tooltip: context.l10n.commonClose,
                      icon: Icon(Icons.close_rounded, color: AppColors.inkSubtle),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Input Field
              if (results.isNotEmpty || _searchQuery.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(context.rem(1.375), 0, context.rem(1.375), context.rem(0.625)),
                  child: Container(
                    height: context.rem(2.625),
                    decoration: BoxDecoration(
                      color: AppColors.inkAlpha(0.06),
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : AppColors.inkAlpha(0.1),
                        width: 1, // px: a hairline, not a layout size
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: AppColors.ink, fontSize: AppType.smallPlus),
                      cursorColor: AppColors.accent,
                      decoration: InputDecoration(
                        hintText: context.l10n.iptvSearchFeeds(results.length),
                        hintStyle: TextStyle(
                          color: AppColors.inkAlpha(0.4),
                          fontSize: AppType.small,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _searchQuery.isNotEmpty
                              ? AppColors.accent
                              : AppColors.inkAlpha(0.4),
                          size: context.rem(AppRem.icon),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: context.l10n.commonClose,
                                icon: Icon(Icons.close_rounded, color: AppColors.inkMuted, size: context.rem(AppRem.iconSm)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: context.rem(0.6875)),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                ),

              // Selection Toolbar (when in edit mode)
              if (_isSelecting)
                Container(
                  margin: EdgeInsets.fromLTRB(context.rem(1.375), 0, context.rem(1.375), context.rem(0.625)),
                  padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.sm)),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      // Select All / Deselect All
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(AppRem.snug)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: context.rem(AppRem.iconSm),
                          color: const Color(0xFF00D2EF),
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.small),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedUrls.clear();
                            } else {
                              _selectedUrls.clear();
                              _selectedUrls.addAll(results.map((h) => h.streamUrl));
                            }
                          });
                        },
                      ),
                      SizedBox(width: context.rem(AppRem.sm)),
                      Text(
                        '(${_selectedUrls.length}/${results.length})',
                        style: TextStyle(
                          color: AppColors.inkAlpha(0.7),
                          fontSize: AppType.caption,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Delete Selected
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: AppColors.onAccent,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(0.4375)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm))),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.delete_rounded, size: context.rem(0.9375)),
                        label: Text(
                          context.l10n.iptvDeleteCount(_selectedUrls.length),
                          style: const TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _selectedUrls.isEmpty ? null : _deleteSelectedStreams,
                      ),
                    ],
                  ),
                ),

              // Status Bar / Progress
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rem(1.375)),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.5625)),
                  decoration: BoxDecoration(
                    color: AppColors.inkAlpha(0.05),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                    border: Border.all(color: AppColors.inkAlpha(0.08)),
                  ),
                  child: Row(
                    children: [
                      if (isScanning)
                        SizedBox(
                          width: context.rem(0.875),
                          height: context.rem(0.875),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      else
                        Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: context.rem(AppRem.iconXs)),
                      SizedBox(width: context.rem(0.625)),
                      Expanded(
                        child: Text(
                          status.isNotEmpty
                              ? status
                              : (_searchQuery.trim().isNotEmpty
                                  ? context.l10n.iptvFoundFeeds(filteredResults.length, results.length)
                                  : context.l10n.iptvFeedsAvailable(results.length)),
                          style: TextStyle(
                            color: AppColors.inkAlpha(0.75),
                            fontSize: AppType.captionPlus,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isScanning)
                        HoverButton(
                          scaleAmount: 1.05,
                          showFocusRing: true,
                          onTap: _ctrl.stopChannelSearch,
                          child: Text(
                            context.l10n.iptvStop,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: AppType.caption,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: context.rem(0.875)),

              // Discovered Stream Hits List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(context.rem(AppRem.lg)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isScanning) ...[
                                CircularProgressIndicator(color: AppColors.accent),
                                SizedBox(height: context.rem(AppRem.md)),
                                Text(
                                  context.l10n.iptvScanningPortals,
                                  style: TextStyle(color: AppColors.inkMuted, fontSize: AppType.body),
                                ),
                              ] else ...[
                                Icon(Icons.tv_off_rounded, color: AppColors.inkDisabled, size: context.rem(3)),
                                SizedBox(height: context.rem(AppRem.ms)),
                                Text(
                                  context.l10n.iptvNoAlive,
                                  style: TextStyle(color: AppColors.inkMuted, fontSize: AppType.bodyMd, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: context.rem(AppRem.snug)),
                                Text(
                                  context.l10n.iptvScanHint,
                                  style: TextStyle(color: AppColors.inkDisabled, fontSize: AppType.small),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : (filteredResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(context.rem(AppRem.lg)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, color: AppColors.inkDisabled, size: context.rem(3)),
                                  SizedBox(height: context.rem(AppRem.ms)),
                                  Text(
                                    context.l10n.iptvNoFeedsMatch(_searchQuery),
                                    style: TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: AppType.bodyMd,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: context.rem(AppRem.sm)),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: Text(
                                      context.l10n.iptvClearSearch,
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: context.rem(1.375), vertical: context.rem(AppRem.snug)),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredResults.length,
                            separatorBuilder: (_, _) => SizedBox(height: context.rem(0.625)),
                            itemBuilder: (context, index) {
                              final hit = filteredResults[index];
                              final isFav = _ctrl.isFavoriteHit(ch.id, hit);
                              final isSelected = _selectedUrls.contains(hit.streamUrl);

                              return HoverButton(
                                scaleAmount: 1.02,
                                showFocusRing: true,
                                focusRingBorderRadius: context.rem(AppRem.radiusLg) + context.rem(AppRem.xxs),
                                onTap: () => _isSelecting
                                    ? _toggleSelection(hit.streamUrl)
                                    : _playHit(hit),
                                child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.ms)),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.accent.withValues(alpha: 0.15)
                                          : AppColors.inkAlpha(0.05),
                                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.accent
                                            : (isFav
                                                ? AppColors.accent.withValues(alpha: 0.6)
                                                : AppColors.inkAlpha(0.08)),
                                        width: isSelected || isFav ? 1.6 : 1.0, // px: a hairline, not a layout size
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Selection checkbox or Play icon
                                        if (_isSelecting)
                                          Container(
                                            width: context.rem(AppRem.xl),
                                            height: context.rem(AppRem.xl),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.accent
                                                  : AppColors.inkAlpha(0.06),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.accent
                                                    : AppColors.inkDisabled,
                                                width: 2, // px: a hairline, not a layout size
                                              ),
                                            ),
                                            child: isSelected
                                                ? Icon(Icons.check_rounded, color: AppColors.ink, size: context.rem(AppRem.iconSm))
                                                : null,
                                          )
                                        else
                                          Container(
                                            width: context.rem(2.25),
                                            height: context.rem(2.25),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: AppColors.accent,
                                              size: context.rem(AppRem.iconMd),
                                            ),
                                          ),

                                        SizedBox(width: context.rem(0.875)),

                                        // Stream Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: context.rem(0.4375),
                                                    height: context.rem(0.4375),
                                                    decoration: BoxDecoration(
                                                      color: Colors.greenAccent,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.greenAccent,
                                                          blurRadius: context.rem(AppRem.xs),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(width: context.rem(AppRem.snug)),
                                                  Expanded(
                                                    child: Text(
                                                      hit.stream.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: AppColors.ink,
                                                        fontSize: AppType.bodyPlus,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: context.rem(AppRem.xxs)),
                                              Padding(
                                                padding: EdgeInsetsDirectional.only(start: context.rem(0.8125)),
                                                child: Text(
                                                  hit.portal.portal.username.isNotEmpty
                                                      ? hit.portal.portal.username
                                                      : (hit.portal.name.isNotEmpty
                                                          ? hit.portal.name
                                                          : context.l10n.iptvServerN(index + 1)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppColors.inkAlpha(0.5),
                                                    fontSize: AppType.caption,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Format Tag
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(AppRem.xxs)),
                                          decoration: BoxDecoration(
                                            color: AppColors.inkAlpha(0.1),
                                            borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
                                          ),
                                          child: Text(
                                            hit.stream.containerExt.toUpperCase(),
                                            style: TextStyle(
                                              color: AppColors.inkMuted,
                                              fontSize: TvType.scale(AppType.micro),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),

                                        SizedBox(width: context.rem(AppRem.sm)),

                                        // Favorite Pin
                                        IconButton(
                                          tooltip: isFav
                                              ? context.l10n.iptvRemoveFavorite
                                              : context.l10n.iptvAddFavorite,
                                          icon: Icon(
                                            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                            color: isFav ? const Color(0xFFFFC107) : AppColors.inkDisabled,
                                            size: context.rem(AppRem.iconMd),
                                          ),
                                          onPressed: () => _ctrl.toggleFavoriteHit(hit),
                                        ),
                                      ],
                                    ),
                                  ),
                              );
                            },
                          )),
              ),

              // Bottom Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(context.rem(1.375), context.rem(AppRem.ms), context.rem(1.375), context.rem(AppRem.lg)),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.inkAlpha(0.06))),
                ),
                child: Row(
                  children: [
                    // Quick Play Best
                    if (results.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: EdgeInsets.symmetric(vertical: context.rem(0.875)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(0.875))),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, color: AppColors.onAccent),
                          label: Text(
                            context.l10n.iptvWatchLive,
                            style: const TextStyle(color: AppColors.onAccent, fontSize: AppType.bodyMd, fontWeight: FontWeight.bold),
                          ),
                          onPressed: filteredResults.isNotEmpty
                              ? () => _playHit(filteredResults.first)
                              : () => _playHit(results.first),
                        ),
                      ),

                    if (results.isNotEmpty) SizedBox(width: context.rem(AppRem.ms)),

                    // Scan More
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: BorderSide(color: AppColors.inkAlpha(0.2)),
                        padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(0.875)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(0.875))),
                      ),
                      icon: Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconSm)),
                      label: Text(context.l10n.iptvScanMore, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: isScanning ? null : () => _ctrl.getMoreChannels(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
