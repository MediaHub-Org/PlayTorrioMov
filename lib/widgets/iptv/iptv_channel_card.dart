import '../common/clamped_text_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/iptv/favorite_channels_service.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_settings.dart';
import '../common/interactive_card_shell.dart';
import '../common/like_button.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class IptvChannelCard extends StatelessWidget {
  final HardcodedChannel channel;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const IptvChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final ch = channel;
    final palette = AppThemeService.currentPalette.value;
    final primaryColor = ch.gradient.isNotEmpty ? ch.gradient.first : palette.primaryColor;
    final secondaryColor = ch.gradient.length > 1 ? ch.gradient.last : palette.accentColor;

    // A grid cell is a fixed box; its text is not. Capped so a
    // large system scale cannot paint outside the cell.
    return ClampedTextScale(
      child: InteractiveCardShell(
        pressedScale: 0.96,
        onTap: onTap,
        builder: (context, hovered, pressed) => RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // Poster / Gradient Box
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withValues(alpha: 0.85),
                              secondaryColor.withValues(alpha: 0.70),
                              AppColors.bar,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hovered
                                  ? primaryColor.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.35),
                              blurRadius: context.rem(hovered ? 1.25 : 0.625),
                              offset: Offset(0, context.rem(hovered ? AppRem.sm : AppRem.xs)),
                            ),
                          ],
                          border: Border.all(
                            color: hovered
                                ? primaryColor.withValues(alpha: 0.8)
                                : AppColors.inkAlpha(0.12),
                            width: hovered ? 1.5 : 1.0, // px: a hairline, not a layout size
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(context.rem(0.9375)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Ambient Pattern Lines / Glow
                              Positioned(
                                top: -context.rem(1.25),
                                right: -context.rem(1.25),
                                child: Container(
                                  width: context.rem(6.25),
                                  height: context.rem(6.25),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.inkAlpha(0.1),
                                  ),
                                ),
                              ),

                              // Channel Icon / Logo / Short text
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(context.rem(0.875), context.rem(1.75), context.rem(0.875), context.rem(AppRem.md)),
                                  child: SizedBox(
                                    width: context.rem(8.125),
                                    height: context.rem(6.25),
                                    child: ch.iconUrl != null && ch.iconUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: ch.iconUrl!,
                                            fit: BoxFit.contain,
                                            placeholder: (_, _) => Center(
                                              child: SizedBox(
                                                width: context.rem(AppRem.lg),
                                                height: context.rem(AppRem.lg),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.inkAlpha(0.3),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (_, _, _) => _buildShortBadge(context, ch),
                                          )
                                        // The badge is a fixed-size box inside a
                                        // poster that shrinks with the cell. At a
                                        // large scale its text wraps and paints
                                        // past the box, so it scales down to fit
                                        // instead of overflowing.
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: _buildShortBadge(context, ch),
                                          ),
                                  ),
                                ),
                              ),

                              // Live Indicator Top-Left
                              if (IptvSettings.showHdBadge.value)
                                Positioned(
                                  top: context.rem(0.625),
                                  left: context.rem(0.625),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: context.rem(0.4375), vertical: context.rem(0.1875)),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                                      border: Border.all(
                                        color: const Color(0xFFFF3B30).withValues(alpha: 0.6),
                                        width: 0.8, // px: a hairline, not a layout size
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: context.rem(AppRem.snug),
                                          height: context.rem(AppRem.snug),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3B30),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF3B30),
                                                blurRadius: context.rem(AppRem.xs),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: context.rem(AppRem.xs)),
                                        Text(
                                          context.l10n.iptvLive.toUpperCase(),
                                          style: TextStyle(
                                            color: AppColors.ink,
                                            fontSize: TvType.scale(AppType.nanoPlus),
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Category Tag Top-Right
                              if (IptvSettings.showCategoryTag.value)
                                Positioned(
                                  top: context.rem(0.625),
                                  right: context.rem(0.625),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug), vertical: context.rem(0.1562)),
                                    decoration: BoxDecoration(
                                      color: AppColors.inkAlpha(0.15),
                                      borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                                    ),
                                    child: Text(
                                      ch.category,
                                      style: TextStyle(
                                        color: AppColors.inkMuted,
                                        fontSize: TvType.scale(AppType.nano),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                              // Favorite toggle, bottom-right
                              Positioned(
                                bottom: context.rem(AppRem.xs),
                                right: context.rem(AppRem.xs),
                                child: ValueListenableBuilder<List<FavoriteChannel>>(
                                  valueListenable: FavoriteChannelsService.items,
                                  builder: (context, _, _) {
                                    final isFav = FavoriteChannelsService.isFavorite(ch.id);
                                    return DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: LikeButton(
                                        isLiked: isFav,
                                        onTap: () => FavoriteChannelsService.toggle(ch.id),
                                        style: LikeButtonStyle.icon,
                                        size: context.rem(0.9375),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Gloss overlay on hover
                              if (hovered)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.inkAlpha(0.12),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Title
                    SizedBox(height: context.rem(AppRem.sm)),
                    Text(
                      ch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.bodyPlus,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),

                    // Category & Stream tag
                    SizedBox(height: context.rem(0.1875)),
                    Row(
                      children: [
                        if (IptvSettings.showCategoryTag.value) ...[
                          // Both legs flex: the clamp keeps them legible at
                          // ordinary settings, this stops them painting
                          // outside the cell whatever scale they are handed.
                          Flexible(
                            child: Text(
                              ch.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppType.caption,
                                color: AppColors.inkAlpha(0.52),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.snug)),
                            child: Container(
                              width: context.rem(0.2188),
                              height: context.rem(0.2188),
                              decoration: BoxDecoration(
                                color: AppColors.inkAlpha(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            context.l10n.iptvHdLive,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppType.caption,
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortBadge(BuildContext context, HardcodedChannel ch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.sm)),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
            border: Border.all(color: AppColors.onAccent.withValues(alpha: 0.2)),
          ),
          child: Text(
            ch.short,
            style: const TextStyle(
              color: AppColors.onAccent,
              fontSize: AppType.titleMd,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
