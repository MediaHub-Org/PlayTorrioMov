import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../services/app_spacing.dart';

const Color _kBackground = Color(0xFF080A0F);
const Color _kSurface = Color(0xFF12151E);
const Color _kAccent = Color(0xFF7C5CFF);
const Color _kAccentAlt = Color(0xFF00E5FF);

const String _kRepoUrl = 'https://github.com/MediaHub-Org/PlayTorrioMod';
const String _kUpstreamUrl = 'https://github.com/ayman708-UX/PlayTorrioV3';

/// The About screen.
///
/// Rewritten from a static marketing blurb into something a tester can act on:
/// it states which build is installed and that the build is untested, what the
/// app actually does today (three hubs, not a feature list of things that only
/// half exist), where the code lives, and — because this is a fork — who wrote
/// the original.
class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About ${AppInfo.name}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              const _BrandHeader(),
              const SizedBox(height: AppSpacing.lg),
              if (AppInfo.isPrerelease) ...[
                const _TestingNotice(),
                const SizedBox(height: AppSpacing.md),
              ],
              const _Card(
                title: 'Watch, Listen, Read',
                body:
                    'One app for every format. Navigation is organised by what '
                    'you want to do rather than by file type, so the same '
                    'search, library and playback surface serves all three.',
                child: _HubList(),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('HOW IT WORKS'),
              const SizedBox(height: AppSpacing.sm),
              const _Tile(
                title: 'Stremio-compatible addons',
                subtitle:
                    'Catalogs, metadata and streams come from addons you '
                    'install. Nothing is bundled or hosted by this app.',
              ),
              const SizedBox(height: 10),
              const _Tile(
                title: 'media_kit / libmpv playback',
                subtitle:
                    'Hardware-accelerated decoding on every platform, with '
                    'the same subtitle and track handling throughout.',
              ),
              const SizedBox(height: 10),
              const _Tile(
                title: 'Torrent and debrid sources',
                subtitle:
                    'Streams resolve from torrent swarms directly, or through '
                    'Real-Debrid and TorBox when an account is connected.',
              ),
              const SizedBox(height: 10),
              const _Tile(
                title: 'Trakt and Simkl sync',
                subtitle:
                    'Optional. Watchlist, episode progress and scrobbling '
                    'stay in step across devices.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionLabel('PROJECT'),
              const SizedBox(height: AppSpacing.sm),
              const _LinkTile(
                icon: Icons.code_rounded,
                title: 'Source code',
                subtitle: 'MediaHub-Org/PlayTorrioMod — GPL-3.0',
                url: _kRepoUrl,
              ),
              const SizedBox(height: 10),
              const _LinkTile(
                icon: Icons.bug_report_outlined,
                title: 'Report a problem',
                subtitle: 'Open an issue with your platform and build number',
                url: '$_kRepoUrl/issues/new',
              ),
              const SizedBox(height: 10),
              const _LinkTile(
                icon: Icons.favorite_outline_rounded,
                title: 'Original project',
                subtitle:
                    'A fork of PlayTorrioV3 by Ayman, who wrote the addon '
                    'integration, scrapers, torrent engine and reader',
                url: _kUpstreamUrl,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Licensed under GPL-3.0. Built with Flutter and Dart. '
                'Playback via media_kit and libmpv.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccent, _kAccentAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            AppInfo.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = AppInfo.versionLabel(snapshot.data?.version);
              final build = snapshot.hasData
                  ? snapshot.data!.buildNumber
                  : AppInfo.fallbackBuildNumber;
              return Text(
                'Version $version · build $build',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shown while [AppInfo.channel] is set. The releases are ordinary versions
/// now, so without this a tester has no way to tell a verified build from one
/// that has only ever run in CI.
class _TestingNotice extends StatelessWidget {
  const _TestingNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Testing build',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This build compiles and passes the automated checks, but it '
                  'has not been verified on a device. Expect rough edges, and '
                  'please report what you hit.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubList extends StatelessWidget {
  const _HubList();

  static const _hubs = [
    (Icons.play_circle_outline_rounded, 'Watch',
        'Movies/Series · Anime · Live TV · Library'),
    (Icons.headphones_rounded, 'Listen',
        'Music · Podcasts · Radio · Library'),
    (Icons.menu_book_rounded, 'Read',
        'Audiobooks · Books · Comics/Manga · Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, label, sections) in _hubs)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _kAccent),
                const SizedBox(width: 12),
                SizedBox(
                  width: 58,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    sections,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.35),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String body;
  final Widget? child;

  const _Card({required this.title, required this.body, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.45,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Tile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _kAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
