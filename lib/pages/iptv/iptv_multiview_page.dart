import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_storage.dart';
import '../../services/playback_coordinator.dart';

/// Watch up to 4 live channels at once in a grid.
///
/// Only offers channels that already have a cached stream URL from a
/// previous watch/scan (`IptvChannelResultsStore`). Resolving a *fresh*
/// stream goes through `IptvController`'s single-active-channel scan flow,
/// which has no concept of N concurrent scans -- rather than bolt that on,
/// multi-view just reuses whatever's already been found. Watch a channel
/// normally first to make it available here.
class IptvMultiViewPage extends StatefulWidget {
  const IptvMultiViewPage({super.key});

  @override
  State<IptvMultiViewPage> createState() => _IptvMultiViewPageState();
}

class _IptvMultiViewPageState extends State<IptvMultiViewPage> {
  static const _maxTiles = 4;

  bool _loading = true;
  List<_AvailableChannel> _available = [];
  final List<_AvailableChannel> _selected = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableChannels();
  }

  Future<void> _loadAvailableChannels() async {
    final found = <_AvailableChannel>[];
    for (final ch in HardcodedChannels.all) {
      final hits = await IptvChannelResultsStore.load(ch.id);
      if (hits.isNotEmpty) {
        found.add(_AvailableChannel(channel: ch, streamUrl: hits.first.streamUrl));
      }
    }
    if (mounted) {
      setState(() {
        _available = found;
        _loading = false;
      });
    }
  }

  void _toggleSelect(_AvailableChannel ch) {
    setState(() {
      if (_selected.contains(ch)) {
        _selected.remove(ch);
      } else if (_selected.length < _maxTiles) {
        _selected.add(ch);
      }
    });
  }

  void _startGrid() {
    // Multi-view plays several sources at once, which conflicts with the
    // app's single-active-source model -- stop whatever else is playing
    // instead of layering audio on top of it.
    PlaybackCoordinator.stopActive();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _IptvMultiViewGrid(channels: List.of(_selected)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080A0F),
        title: const Text('Multi-View'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _startGrid,
              child: Text(
                'Watch (${_selected.length})',
                style: const TextStyle(color: Color(0xFF7C5CFF), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF)))
          : _available.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No channels ready yet. Watch a few channels normally first '
                      '-- multi-view reuses their already-found streams.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  ),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Pick up to $_maxTiles channels to watch at once',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: _available.length,
                        itemBuilder: (context, index) {
                          final ch = _available[index];
                          final isSelected = _selected.contains(ch);
                          return _ChannelPickTile(
                            channel: ch.channel,
                            selected: isSelected,
                            onTap: () => _toggleSelect(ch),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AvailableChannel {
  final HardcodedChannel channel;
  final String streamUrl;
  const _AvailableChannel({required this.channel, required this.streamUrl});

  @override
  bool operator ==(Object other) =>
      other is _AvailableChannel && other.channel.id == channel.id;
  @override
  int get hashCode => channel.id.hashCode;
}

class _ChannelPickTile extends StatelessWidget {
  final HardcodedChannel channel;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelPickTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = channel.gradient.isNotEmpty ? channel.gradient.first : const Color(0xFF7C5CFF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : Colors.white.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.live_tv_rounded,
              color: selected ? primary : Colors.white38,
              size: 22,
            ),
            const SizedBox(height: 8),
            Text(
              channel.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual N-up grid: each tile runs its own muted [VideoPlayerController];
/// tapping a tile swaps audio focus to it (mutes the rest). Deliberately
/// bypasses [PlaybackCoordinator] -- multiple simultaneous video sources
/// don't fit its single-active-source model, and each tile already fully
/// owns and disposes its own controller.
class _IptvMultiViewGrid extends StatefulWidget {
  final List<_AvailableChannel> channels;
  const _IptvMultiViewGrid({required this.channels});

  @override
  State<_IptvMultiViewGrid> createState() => _IptvMultiViewGridState();
}

class _IptvMultiViewGridState extends State<_IptvMultiViewGrid> {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _errored = {};
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.channels.length; i++) {
      final ch = widget.channels[i];
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(ch.streamUrl),
        httpHeaders: const {
          'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        },
      );
      _controllers[ch.channel.id] = controller;
      final index = i;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller
          ..setLooping(true)
          ..play()
          ..setVolume(index == _focusedIndex ? 1 : 0);
        setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _errored[ch.channel.id] = true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _focusTile(int index) {
    setState(() => _focusedIndex = index);
    for (var i = 0; i < widget.channels.length; i++) {
      _controllers[widget.channels[i].channel.id]?.setVolume(i == index ? 1 : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.channels.length;
    final crossAxisCount = count <= 1 ? 1 : 2;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Multi-View'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 16 / 9,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final ch = widget.channels[index];
          final controller = _controllers[ch.channel.id];
          final hasError = _errored[ch.channel.id] ?? false;
          final isFocused = index == _focusedIndex;

          return GestureDetector(
            onTap: () => _focusTile(index),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? const Color(0xFF7C5CFF) : Colors.white24,
                  width: isFocused ? 3 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasError)
                    const Center(
                      child: Icon(Icons.error_outline_rounded, color: Colors.white38, size: 32),
                    )
                  else if (controller != null && controller.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  else
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFF)),
                      ),
                    ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFocused) ...[
                            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            ch.channel.name,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
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
}
