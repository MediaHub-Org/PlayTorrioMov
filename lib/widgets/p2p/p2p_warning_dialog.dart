import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/p2p/p2p_settings_service.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class P2pWarningDialog extends StatelessWidget {
  const P2pWarningDialog({super.key});

  // Getters, not variables: a static variable is initialized lazily, once,
  // on its first read -- which would freeze whichever theme happened to be
  // active when this dialog was first opened, and leave it there through
  // every later theme change.
  static Color get _surfaceColor => AppColors.surface;
  static Color get _backgroundColor => AppColors.canvas;
  static const Color _warningColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final size = MediaQuery.sizeOf(context);
    final isSmallScreen = size.width < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.lg)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.rem(33.75),
            maxHeight: size.height * 0.90,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(context.rem(AppRem.lg)),
              border: Border.all(
                color: _warningColor.withValues(alpha: 0.35),
                width: 1.5, // px: a hairline, not a layout size
              ),
              boxShadow: [
                BoxShadow(
                  color: _warningColor.withValues(alpha: 0.15),
                  blurRadius: context.rem(2.5),
                  spreadRadius: context.rem(AppRem.xxs),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.70),
                  blurRadius: context.rem(1.875),
                  offset: Offset(0, context.rem(0.625)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rem(AppRem.lg)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header Banner
                  Container(
                    padding: EdgeInsets.fromLTRB(context.rem(1.25), context.rem(1.25), context.rem(AppRem.md), context.rem(1.125)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _warningColor.withValues(alpha: 0.22),
                          _warningColor.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: _warningColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.rem(AppRem.ms)),
                          decoration: BoxDecoration(
                            color: _warningColor.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(context.rem(0.875)),
                            border: Border.all(
                              color: _warningColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: _warningColor,
                            size: context.rem(1.75),
                          ),
                        ),
                        SizedBox(width: context.rem(0.875)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: context.rem(0.4375),
                                      vertical: context.rem(0.1875),
                                    ),
                                    decoration: BoxDecoration(
                                      color: _warningColor.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                                    ),
                                    child: Text(
                                      context.l10n.p2pAdvisoryBadge.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: TvType.scale(AppType.micro),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: _warningColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: context.rem(0.3125)),
                              Text(
                                context.l10n.p2pTitle,
                                style: TextStyle(
                                  fontSize: AppType.lead,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppColors.inkAlpha(0.60)),
                          tooltip: context.l10n.p2pExit,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: context.rem(1.375), vertical: context.rem(1.125)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main advisory text
                          Text(
                            context.l10n.p2pBody,
                            style: TextStyle(
                              fontSize: AppType.smallPlus,
                              color: AppColors.inkAlpha(0.88),
                              height: 1.45, // ratio: a line height, not a size
                            ),
                          ),
                          SizedBox(height: context.rem(AppRem.md)),

                          // Engine Breakdown Box
                          Container(
                            padding: EdgeInsets.all(context.rem(0.875)),
                            decoration: BoxDecoration(
                              color: _backgroundColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(context.rem(0.875)),
                              border: Border.all(
                                color: AppColors.inkAlpha(0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildSourceInfoRow(
                                  context,
                                  icon: Icons.cloud_done_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  title: context.l10n.p2pHttpTitle,
                                  subtitle: context.l10n.p2pHttpSubtitle,
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: context.rem(0.625)),
                                  child: Divider(
                                    height: 1, // px: a hairline, not a layout size
                                    color: AppColors.inkAlpha(0.06),
                                  ),
                                ),
                                _buildSourceInfoRow(
                                  context,
                                  icon: Icons.hub_rounded,
                                  iconColor: _warningColor,
                                  title: context.l10n.p2pEngineTitle,
                                  subtitle: context.l10n.p2pEngineSubtitle,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: context.rem(AppRem.md)),

                          // Prompt question
                          Container(
                            padding: EdgeInsets.all(context.rem(0.875)),
                            decoration: BoxDecoration(
                              color: _warningColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(context.rem(0.875)),
                              border: Border.all(
                                color: _warningColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  color: _warningColor,
                                  size: context.rem(AppRem.iconMd),
                                ),
                                SizedBox(width: context.rem(AppRem.ms)),
                                Expanded(
                                  child: Text(
                                    context.l10n.p2pQuestion,
                                    style: TextStyle(
                                      fontSize: AppType.small,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkAlpha(0.95),
                                      height: 1.35, // ratio: a line height, not a size
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: context.rem(0.625)),
                          Text(
                            context.l10n.p2pNote,
                            style: TextStyle(
                              fontSize: AppType.tinyPlus,
                              color: AppColors.inkAlpha(0.45),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Responsive Action Buttons Footer
                  Container(
                    padding: EdgeInsets.fromLTRB(context.rem(1.125), context.rem(0.875), context.rem(1.125), context.rem(1.125)),
                    decoration: BoxDecoration(
                      color: _backgroundColor.withValues(alpha: 0.95),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.inkAlpha(0.08),
                        ),
                      ),
                    ),
                    child: isSmallScreen
                        ? _buildStackedButtons(context)
                        : _buildHorizontalButtons(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceInfoRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(context.rem(0.4375)),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(context.rem(0.5625)),
          ),
          child: Icon(icon, color: iconColor, size: context.rem(AppRem.iconSm)),
        ),
        SizedBox(width: context.rem(AppRem.ms)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: context.rem(AppRem.xxs)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppType.caption,
                  color: AppColors.inkAlpha(0.55),
                  height: 1.25, // ratio: a line height, not a size
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalButtons(BuildContext context) {
    return Row(
      children: [
        // Exit button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.ms)),
            foregroundColor: AppColors.inkAlpha(0.60),
          ),
          child: Text(
            context.l10n.p2pExit,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),

        // Don't show again button (keeps P2P enabled)
        OutlinedButton(
          onPressed: () async {
            await P2pSettingsService.setNeverShowWarning(true);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.inkAlpha(0.20)),
            foregroundColor: AppColors.inkMuted,
            padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.ms)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd))),
          ),
          child: Text(
            context.l10n.p2pDontShowAgain,
            style: const TextStyle(fontSize: AppType.captionPlus, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(width: context.rem(0.625)),

        // Yes, Turn Off P2P button
        ElevatedButton.icon(
          onPressed: () async {
            await P2pSettingsService.setP2pEnabled(false);
            await P2pSettingsService.setNeverShowWarning(true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.p2pTurnedOff),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).pop();
            }
          },
          icon: Icon(Icons.check_circle_outline_rounded, size: context.rem(AppRem.iconSm)),
          label: Text(
            context.l10n.p2pTurnOff,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.small),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _warningColor,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.ms)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd))),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Yes, Turn Off P2P button
        ElevatedButton.icon(
          onPressed: () async {
            await P2pSettingsService.setP2pEnabled(false);
            await P2pSettingsService.setNeverShowWarning(true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.p2pTurnedOff),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).pop();
            }
          },
          icon: Icon(Icons.check_circle_outline_rounded, size: context.rem(AppRem.iconSm)),
          label: Text(
            context.l10n.p2pTurnOff,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.smallPlus),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _warningColor,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(vertical: context.rem(0.8125)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd))),
            elevation: 0,
          ),
        ),
        SizedBox(height: context.rem(AppRem.sm)),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await P2pSettingsService.setNeverShowWarning(true);
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.inkAlpha(0.20)),
                  foregroundColor: AppColors.inkMuted,
                  padding: EdgeInsets.symmetric(vertical: context.rem(AppRem.ms)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd))),
                ),
                child: Text(
                  context.l10n.p2pDontShowAgain,
                  style: const TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: context.rem(AppRem.sm)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.ms)),
                foregroundColor: AppColors.inkAlpha(0.60),
              ),
              child: Text(
                context.l10n.p2pExit,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
