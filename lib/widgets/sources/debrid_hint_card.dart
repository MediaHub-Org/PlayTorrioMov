import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../services/app_units.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/theme/app_colors.dart';

/// A line on the sources page about the one thing that makes torrents fast on
/// a slow connection: a debrid service.
///
/// A torrent is as fast as its swarm and as the device holding the pieces
/// together; a debrid service downloads it elsewhere and hands over a plain
/// file, which is also why a title starts in a second and skipping around
/// costs nothing. The app has had the setting for a long time, unconfigured
/// and unmentioned, so most people never found it.
///
/// It says so once, plainly, and goes away: no purchase is pushed (it is a
/// paid service and the viewer's call), torrents keep working without it, and
/// "Not now" is remembered. It never shows once debrid is on for streams.
class DebridHintCard extends StatefulWidget {
  /// Opens the debrid settings, and completes when the viewer comes back. The
  /// screen supplies it: the card is a widget and does not know about pages.
  final Future<void> Function() onSetUp;

  const DebridHintCard({super.key, required this.onSetUp});

  /// The remembered "Not now".
  static const dismissedKey = 'debrid_hint_dismissed';

  @override
  State<DebridHintCard> createState() => _DebridHintCardState();
}

class _DebridHintCardState extends State<DebridHintCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    var show = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(DebridHintCard.dismissedKey) ?? false;
      show = !dismissed && !await DebridService().isDebridActiveForStreams();
    } catch (e) {
      // Storage unavailable: the hint is a nicety, so it stays hidden.
      debugPrint('[DebridHintCard] could not read state: $e');
    }
    if (mounted && show != _visible) setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DebridHintCard.dismissedKey, true);
    } catch (e) {
      debugPrint('[DebridHintCard] could not save dismissal: $e');
    }
  }

  Future<void> _openSettings() async {
    await widget.onSetUp();
    // Back from settings the viewer may have turned it on; the card should
    // not be waiting there.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: context.rem(AppRem.sm)),
      child: Container(
        padding: EdgeInsets.all(context.rem(AppRem.ms)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: context.rem(AppRem.icon),
                  color: AppColors.accent,
                ),
                SizedBox(width: context.rem(AppRem.sm)),
                Expanded(
                  child: Text(
                    l10n.debridHintTitle,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: AppType.bodyMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rem(AppRem.xs)),
            Text(
              l10n.debridHintBody,
              style: TextStyle(
                color: AppColors.inkSubtle,
                fontSize: AppType.caption,
                height: 1.35, // ratio: a line height, not a size
              ),
            ),
            SizedBox(height: context.rem(AppRem.xs)),
            Wrap(
              spacing: context.rem(AppRem.sm),
              children: [
                TextButton(
                  autofocus: false,
                  onPressed: _openSettings,
                  child: Text(l10n.debridHintSetUp),
                ),
                TextButton(
                  onPressed: _dismiss,
                  child: Text(l10n.debridHintNotNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
