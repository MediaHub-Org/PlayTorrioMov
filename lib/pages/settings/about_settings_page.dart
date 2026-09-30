import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../l10n/l10n.dart';
import '../../services/updater/app_updater_service.dart';
import '../../widgets/updater/update_dialog.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';
import '../../services/app_units.dart';

// Getters, not variables: a top-level or static variable is initialized
// lazily, once, on its first read -- which would freeze whichever theme
// happened to be active when this screen was first opened, and leave it
// there through every later theme change.
Color get _kBackground => AppColors.canvas;
Color get _kSurface => AppColors.surface;
Color get _kAccent => AppColors.accent;
const Color _kAccentAlt = Color(0xFF00E5FF);

const String _kRepoUrl = 'https://github.com/MediaHub-Org/PlayTorrioMov';
const String _kUpstreamUrl = 'https://github.com/ayman708-UX/PlayTorrioV3';

/// The About screen.
///
/// Rewritten from a static marketing blurb into something a tester can act on:
/// it states which build is installed and that the build is untested, what the
/// app actually does today (three hubs, not a feature list of things that only
/// half exist), where the code lives, and — because this is a fork — who wrote
/// the original.
class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  bool _isCheckingForUpdates = false;
  bool _autoCheckEnabled = true;

  @override
  void initState() {
    super.initState();
    AppUpdaterService.isAutoCheckEnabled().then((enabled) {
      if (mounted) setState(() => _autoCheckEnabled = enabled);
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingForUpdates = true);
    try {
      final updateInfo = await AppUpdaterService().checkForUpdates(
        ignoreDismissed: true,
      );
      if (!mounted) return;
      if (updateInfo != null) {
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.aboutUpToDate(AppInfo.name)),
            backgroundColor: _kAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.aboutUpdateError('$e')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingForUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsCategoryAbout(AppInfo.name),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 24,
        bottomPadding: 24,
        children: [
          const _BrandHeader(),
          SizedBox(height: context.rem(AppRem.md)),
          _UpdatesRow(
            isChecking: _isCheckingForUpdates,
            autoCheckEnabled: _autoCheckEnabled,
            onCheckNow: _checkForUpdates,
            onAutoCheckChanged: (value) {
              setState(() => _autoCheckEnabled = value);
              AppUpdaterService.setAutoCheckEnabled(value);
            },
          ),
          SizedBox(height: context.rem(AppRem.lg)),
          if (AppInfo.isPrerelease) ...[
            const _TestingNotice(),
            SizedBox(height: context.rem(AppRem.md)),
          ],
          _Card(
            title: l10n.aboutTaglineTitle,
            body: l10n.aboutTaglineBody,
          ),
          SizedBox(height: context.rem(AppRem.md)),
          _SectionLabel(l10n.aboutHowItWorks),
          SizedBox(height: context.rem(AppRem.sm)),
          _Tile(
            title: l10n.aboutAddonsTitle,
            subtitle: l10n.aboutAddonsBody,
          ),
          SizedBox(height: context.rem(0.625)),
          _Tile(
            title: l10n.aboutPlaybackTitle,
            subtitle: l10n.aboutPlaybackBody,
          ),
          SizedBox(height: context.rem(0.625)),
          _Tile(
            title: l10n.aboutSourcesTitle,
            subtitle: l10n.aboutSourcesBody,
          ),
          SizedBox(height: context.rem(0.625)),
          _Tile(
            title: l10n.aboutSyncTitle,
            subtitle: l10n.aboutSyncBody,
          ),
          SizedBox(height: context.rem(AppRem.lg)),
          _SectionLabel(l10n.aboutProject),
          SizedBox(height: context.rem(AppRem.sm)),
          _LinkTile(
            icon: Icons.code_rounded,
            title: l10n.aboutSourceCode,
            subtitle: 'MediaHub-Org/PlayTorrioMov — GPL-3.0',
            url: _kRepoUrl,
          ),
          SizedBox(height: context.rem(0.625)),
          _LinkTile(
            icon: Icons.bug_report_outlined,
            title: l10n.aboutReportProblem,
            subtitle: l10n.aboutReportProblemBody,
            url: '$_kRepoUrl/issues/new',
          ),
          SizedBox(height: context.rem(0.625)),
          _LinkTile(
            icon: Icons.favorite_outline_rounded,
            title: l10n.aboutOriginalProject,
            subtitle: l10n.aboutOriginalProjectBody,
            url: _kUpstreamUrl,
          ),
          SizedBox(height: context.rem(AppRem.lg)),
          Text(
            l10n.aboutLicense,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppType.tinyPlus,
              height: 1.5, // ratio: a line height, not a size
              color: AppColors.inkAlpha(0.3),
            ),
          ),
          SizedBox(height: context.rem(AppRem.lg)),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Center(
      child: Column(
        children: [
          Container(
            width: context.rem(4.5),
            height: context.rem(4.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kAccent, _kAccentAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(context.rem(1.375)),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.3),
                  blurRadius: context.rem(1.25),
                  offset: Offset(0, context.rem(AppRem.sm)),
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: AppColors.ink,
              size: context.rem(2.75),
            ),
          ),
          SizedBox(height: context.rem(AppRem.md)),
          Text(
            AppInfo.name,
            style: TextStyle(
              fontSize: AppType.heading,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: context.rem(AppRem.snug)),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = AppInfo.versionLabel(snapshot.data?.version);
              final build = snapshot.hasData
                  ? snapshot.data!.buildNumber
                  : AppInfo.fallbackBuildNumber;
              return Text(
                context.l10n.aboutVersionBuild(version, build),
                style: TextStyle(
                  fontSize: AppType.small,
                  color: AppColors.inkAlpha(0.45),
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

/// One button, one switch -- what used to be its own "App Updates & System"
/// page (a description paragraph, a version card, an auto-check toggle with
/// its own explanation, and two marketing tiles about the release channel)
/// is just the two controls that actually do something.
class _UpdatesRow extends StatelessWidget {
  final bool isChecking;
  final bool autoCheckEnabled;
  final VoidCallback onCheckNow;
  final ValueChanged<bool> onAutoCheckChanged;

  const _UpdatesRow({
    required this.isChecking,
    required this.autoCheckEnabled,
    required this.onCheckNow,
    required this.onAutoCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(0.625)),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: isChecking ? null : onCheckNow,
              style: TextButton.styleFrom(
                foregroundColor: _kAccent,
                padding: EdgeInsets.symmetric(vertical: context.rem(0.625)),
              ),
              icon: isChecking
                  ? SizedBox(
                      width: context.rem(0.875),
                      height: context.rem(0.875),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAccent,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, size: context.rem(AppRem.iconSm)),
              label: Text(
                isChecking ? context.l10n.aboutChecking : context.l10n.aboutCheckForUpdates,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.small,
                ),
              ),
            ),
          ),
          SizedBox(width: context.rem(AppRem.sm)),
          Text(
            context.l10n.aboutAutoCheck,
            style: TextStyle(fontSize: AppType.captionPlus, color: AppColors.inkSubtle),
          ),
          Switch(
            value: autoCheckEnabled,
            activeThumbColor: _kAccent,
            onChanged: onAutoCheckChanged,
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
    AppColors.dependOn(context);
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.science_outlined,
            color: const Color(0xFFF59E0B),
            size: context.rem(AppRem.icon),
          ),
          SizedBox(width: context.rem(AppRem.ms)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutTestingBuild,
                  style: const TextStyle(
                    fontSize: AppType.smallPlus,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                SizedBox(height: context.rem(AppRem.xs)),
                Text(
                  l10n.aboutTestingBuildBody,
                  style: TextStyle(
                    fontSize: AppType.captionPlus,
                    height: 1.4, // ratio: a line height, not a size
                    color: AppColors.inkAlpha(0.55),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: AppType.caption,
        fontWeight: FontWeight.w700,
        color: AppColors.inkAlpha(0.35),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String body;

  const _Card({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      padding: EdgeInsets.all(context.rem(1.125)),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(color: AppColors.inkAlpha(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppType.bodyMd,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: context.rem(AppRem.sm)),
          Text(
            body,
            style: TextStyle(
              fontSize: AppType.small,
              color: AppColors.inkAlpha(0.5),
              height: 1.45, // ratio: a line height, not a size
            ),
          ),
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
    AppColors.dependOn(context);
    return Container(
      padding: EdgeInsets.all(context.rem(0.875)),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
        border: Border.all(color: AppColors.inkAlpha(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: context.rem(AppRem.xxs)),
            width: context.rem(AppRem.sm),
            height: context.rem(AppRem.sm),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(context.rem(AppRem.xs)),
            ),
          ),
          SizedBox(width: context.rem(0.875)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppType.smallPlus,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: context.rem(AppRem.xxs)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppType.caption,
                    height: 1.35, // ratio: a line height, not a size
                    color: AppColors.inkAlpha(0.4),
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
    // Captured before the await: reading `context.l10n` afterwards is a
    // BuildContext use across an async gap, and the analyzer is right to
    // flag it -- the widget can be gone by the time the launch returns.
    final l10n = context.l10n;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.aboutCouldNotOpen(url))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
        child: Container(
          padding: EdgeInsets.all(context.rem(0.875)),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
            border: Border.all(color: AppColors.inkAlpha(0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, size: context.rem(AppRem.icon), color: _kAccent),
              SizedBox(width: context.rem(0.875)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppType.smallPlus,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: context.rem(AppRem.xxs)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppType.caption,
                        height: 1.35, // ratio: a line height, not a size
                        color: AppColors.inkAlpha(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: context.rem(AppRem.iconXs),
                color: AppColors.inkAlpha(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
