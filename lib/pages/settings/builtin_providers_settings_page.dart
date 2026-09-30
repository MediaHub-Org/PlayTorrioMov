import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_spacing.dart';
import '../../services/p2p/p2p_settings_service.dart';
import '../../services/scraper/builtin_providers_service.dart';
import '../../services/scraper/stream_scraper.dart';
import '../../services/stream/stream_service.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../widgets/p2p/p2p_warning_dialog.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

/// Per-provider control over the app's built-in scrapers.
///
/// The roster is not written down anywhere: it is
/// `ScraperManager.instance.scrapers`, the scrapers the app actually
/// registered. Porting a scraper adds a row here; deleting one removes it.
class BuiltinProvidersSettingsPage extends StatefulWidget {
  const BuiltinProvidersSettingsPage({super.key});

  @override
  State<BuiltinProvidersSettingsPage> createState() =>
      _BuiltinProvidersSettingsPageState();
}

class _BuiltinProvidersSettingsPageState
    extends State<BuiltinProvidersSettingsPage> {
  late List<StreamScraper> _providers;
  String _query = '';

  // Shared with the Scrollbar so the thumb tracks this list. Without a
  // controller on both, the bar has nothing to attach to and does not draw.
  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Settings is reachable without ever opening a stream, and registration
    // used to happen only on the first fetch -- so without this the list
    // would be empty on a fresh launch. Idempotent.
    StreamService.registerBuiltInScrapers();
    _providers = ScraperManager.instance.scrapers.toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  }

  List<StreamScraper> get _visible {
    if (_query.isEmpty) return _providers;
    final q = _query.toLowerCase();
    return _providers
        .where((p) => p.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inset = AppSpacing.pageInset(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.builtinProvidersTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: BuiltinProvidersService.revision,
        builder: (context, _, __) {
          final visible = _visible;
          final off = BuiltinProvidersService.disabledCountAmong(
            _providers.map((p) => p.id),
          );
          final on = _providers.length - off;

          // Full width, with the content centered by padding rather than by
          // a ConstrainedBox around the list. This page has a pinned header
          // so it cannot use SettingsScrollView directly, but it borrows
          // that widget's gutter so it lines up with every other settings
          // page -- and, like them, keeps the scrollable the full width of
          // the window so the wheel works wherever the pointer is.
          final gutter = SettingsScrollView.gutterFor(
            MediaQuery.sizeOf(context).width,
            minGutter: inset,
          );

          // One scrollable, not a pinned header over a list. The header was
          // pinned, but at 3x text scale it is taller than the screen on its
          // own -- the intro paragraph, the P2P row, the counter and the
          // filter field all grow -- so pinning it meant the list below got
          // whatever was left, which was nothing. Scrolling the two together
          // is what every other settings page does, and it is the only
          // arrangement that survives the scale.
          return CustomScrollView(
            controller: _listController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, context.rem(1.25), gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: _header(on, _providers.length, visible),
                ),
              ),
              if (_providers.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _empty())
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, context.rem(AppRem.md), gutter, context.rem(AppRem.lg)),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => SizedBox(height: context.rem(AppRem.sm)),
                    itemBuilder: (context, i) => _row(visible[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(int on, int total, List<StreamScraper> visible) {
    final l10n = context.l10n;
    final visibleIds = visible.map((p) => p.id).toList();
    final visibleOff = BuiltinProvidersService.disabledCountAmong(visibleIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.builtinProvidersIntro,
          style: TextStyle(
            fontSize: AppType.smallPlus,
            color: AppColors.inkAlpha(0.5),
            height: 1.4, // ratio: a line height, not a size
          ),
        ),
        SizedBox(height: context.rem(0.875)),
        // The master switch every torrent row below answers to -- used to
        // be its own top-level Settings row, disconnected from the list
        // whose rows it silences.
        ValueListenableBuilder<bool>(
          valueListenable: P2pSettingsService.isP2pEnabled,
          builder: (context, isP2p, _) {
            return Container(
              margin: EdgeInsets.only(bottom: context.rem(0.875)),
              padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.625)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                border: Border.all(
                  color: isP2p
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                      : AppColors.inkAlpha(0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    size: context.rem(AppRem.icon),
                    color: isP2p
                        ? const Color(0xFFF59E0B)
                        : AppColors.inkAlpha(0.35),
                  ),
                  SizedBox(width: context.rem(AppRem.ms)),
                  Expanded(
                    child: Text(
                      l10n.builtinProvidersP2pLabel,
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkAlpha(0.85),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: context.rem(AppRem.iconXs),
                      color: AppColors.inkSubtle,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: l10n.builtinProvidersP2pTooltip,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const P2pWarningDialog(),
                    ),
                  ),
                  SizedBox(width: context.rem(AppRem.snug)),
                  Switch.adaptive(
                    value: isP2p,
                    activeColor: const Color(0xFFF59E0B),
                    onChanged: (val) => P2pSettingsService.setP2pEnabled(val),
                  ),
                ],
              ),
            );
          },
        ),
        // A Wrap, not a Row: at 3x the counter and the two buttons together
        // are wider than a phone, and the buttons are the part that can
        // move to a second line.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.rem(AppRem.sm),
          runSpacing: context.rem(AppRem.xs),
          children: [
            Text(
              l10n.builtinProvidersActiveCount(on, total),
              style: const TextStyle(
                fontSize: AppType.small,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
            // Scoped to what is on screen: with a filter typed in, "Enable
            // all" next to four visible rows should not silently switch on
            // forty others the user cannot see.
            TextButton(
              onPressed: visibleOff == 0
                  ? null
                  : () => BuiltinProvidersService.enableAll(visibleIds),
              child: Text(l10n.builtinProvidersEnableAll),
            ),
            TextButton(
              onPressed: visibleOff == visible.length
                  ? null
                  : () => BuiltinProvidersService.disableAll(visibleIds),
              child: Text(l10n.builtinProvidersDisableAll),
            ),
          ],
        ),
        if (_providers.length > 8) ...[
          SizedBox(height: context.rem(AppRem.snug)),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: AppType.body),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.builtinProvidersFilterHint,
              prefixIcon: Icon(Icons.search_rounded, size: context.rem(AppRem.icon)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: EdgeInsets.all(context.rem(AppRem.xl)),
      child: Text(
        context.l10n.builtinProvidersEmpty,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.inkAlpha(0.5)),
      ),
    ),
  );

  Widget _row(StreamScraper provider) {
    final l10n = context.l10n;
    // A torrent provider that is on but whose master switch is off is not
    // actually being searched; say so rather than showing an active row that
    // does nothing.
    return ValueListenableBuilder<bool>(
      valueListenable: P2pSettingsService.isP2pEnabled,
      builder: (context, p2pOn, _) {
        final enabled = BuiltinProvidersService.isEnabled(provider.id);
        final mutedByP2p = provider.isTorrent && !p2pOn;
        final live = enabled && !mutedByP2p;

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
          child: InkWell(
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
            onTap: () =>
                BuiltinProvidersService.setEnabled(provider.id, !enabled),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(0.625)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                border: Border.all(
                  color: live
                      ? const Color(0xFF10B981).withValues(alpha: 0.25)
                      : AppColors.inkAlpha(0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isTorrent
                        ? Icons.hub_rounded
                        : Icons.cloud_outlined,
                    size: context.rem(AppRem.icon),
                    color: live
                        ? const Color(0xFF10B981)
                        : AppColors.inkAlpha(0.35),
                  ),
                  SizedBox(width: context.rem(AppRem.ms)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.displayName,
                          style: const TextStyle(
                            fontSize: AppType.bodyPlus,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: context.rem(AppRem.xxs)),
                        Text(
                          mutedByP2p
                              ? l10n.builtinProvidersTorrentSilenced
                              : (provider.isTorrent
                                    ? l10n.builtinProvidersTorrent
                                    : l10n.builtinProvidersDirect),
                          style: TextStyle(
                            fontSize: AppType.caption,
                            color: mutedByP2p
                                ? const Color(0xFFF59E0B)
                                : AppColors.inkAlpha(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.rem(AppRem.sm)),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(
                      0xFF10B981,
                    ).withValues(alpha: 0.35),
                    inactiveThumbColor: AppColors.inkAlpha(0.60),
                    inactiveTrackColor: AppColors.inkAlpha(0.10),
                    onChanged: (v) =>
                        BuiltinProvidersService.setEnabled(provider.id, v),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
