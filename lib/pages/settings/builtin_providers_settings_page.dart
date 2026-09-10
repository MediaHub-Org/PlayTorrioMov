import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';
import '../../services/p2p/p2p_settings_service.dart';
import '../../services/scraper/builtin_providers_service.dart';
import '../../services/scraper/stream_scraper.dart';
import '../../services/stream/stream_service.dart';
import '../../widgets/p2p/p2p_warning_dialog.dart';

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
    final inset = AppSpacing.pageInset(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Built-in Providers',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 20, inset, 0),
                    child: _header(on, _providers.length, visible),
                  ),
                  Expanded(
                    child: _providers.isEmpty
                        ? _empty()
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _row(visible[i]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(int on, int total, List<StreamScraper> visible) {
    final visibleIds = visible.map((p) => p.id).toList();
    final visibleOff = BuiltinProvidersService.disabledCountAmong(visibleIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turn off a provider to stop it being searched when you open a '
          'title. Fewer providers means a faster, shorter source list; more '
          'means a better chance something plays.',
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        // The master switch every torrent row below answers to -- used to
        // be its own top-level Settings row, disconnected from the list
        // whose rows it silences.
        ValueListenableBuilder<bool>(
          valueListenable: P2pSettingsService.isP2pEnabled,
          builder: (context, isP2p, _) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF12151E),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: isP2p
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    size: 20,
                    color: isP2p
                        ? const Color(0xFFF59E0B)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Built-in P2P torrent source',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'P2P Advisory Details',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const P2pWarningDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
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
        Row(
          children: [
            Text(
              '$on of $total active',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
            const Spacer(),
            // Scoped to what is on screen: with a filter typed in, "Enable
            // all" next to four visible rows should not silently switch on
            // forty others the user cannot see.
            TextButton(
              onPressed: visibleOff == 0
                  ? null
                  : () => BuiltinProvidersService.enableAll(visibleIds),
              child: const Text('Enable all'),
            ),
            TextButton(
              onPressed: visibleOff == visible.length
                  ? null
                  : () => BuiltinProvidersService.disableAll(visibleIds),
              child: const Text('Disable all'),
            ),
          ],
        ),
        if (_providers.length > 8) ...[
          const SizedBox(height: 6),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter providers',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: const Color(0xFF12151E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.all(32),
      child: Text(
        'No built-in providers are registered in this build.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      ),
    ),
  );

  Widget _row(StreamScraper provider) {
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
          color: const Color(0xFF12151E),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () =>
                BuiltinProvidersService.setEnabled(provider.id, !enabled),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: live
                      ? const Color(0xFF10B981).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.isTorrent
                        ? Icons.hub_rounded
                        : Icons.cloud_outlined,
                    size: 20,
                    color: live
                        ? const Color(0xFF10B981)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.displayName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mutedByP2p
                              ? 'Torrent source \u2014 silenced by the P2P master switch'
                              : (provider.isTorrent
                                    ? 'Torrent source'
                                    : 'Direct HTTP source'),
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedByP2p
                                ? const Color(0xFFF59E0B)
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: enabled,
                    activeColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(
                      0xFF10B981,
                    ).withValues(alpha: 0.35),
                    inactiveThumbColor: Colors.white60,
                    inactiveTrackColor: Colors.white10,
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
