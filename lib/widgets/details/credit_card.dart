import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/details/credit.dart';
import '../../services/theme/app_colors.dart';
import '../common/hover_button.dart';

/// One person on a details page's credits rail: avatar, name, and what they
/// did on this title.
///
/// Public and self-contained so it can be *probed*. It was a private builder
/// on `DetailsPage`, which fetches its own data over the network — so nothing
/// could construct it, and the clamps that stop its text leaving the rail's
/// fixed box were reasoned from arithmetic rather than measured (#69).
/// `test/text_scale_overflow_test.dart` renders it now.
class CreditCard extends StatelessWidget {
  final Credit credit;

  /// Opens whatever the name should lead to. A callback rather than a route,
  /// because a widget reaching for a page would point the dependency the wrong
  /// way — `pages → widgets`, never back.
  final VoidCallback onTap;

  /// The rail's fixed height, which is the whole reason the text below is
  /// capped. Named rather than assumed so a probe can state it.
  static const double railHeight = 148;

  const CreditCard({super.key, required this.credit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          HoverButton(
            onTap: onTap,
            scaleAmount: 1.05,
            child: _PersonAvatar(
              profileUrl: credit.profileUrl,
              name: credit.name,
            ),
          ),
          const SizedBox(height: 6),
          // The rail is a fixed 148 and the column is avatar + 6 + name + 2 +
          // role (12, already capped at 1.0). At 3x this 12px name alone wants
          // ~43px and the column asks ~151 of a 148 box. Capped like its
          // sibling rather than the whole rail, because the avatar above it
          // should keep its size (#69).
          Text(
            credit.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler:
                MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          // Fixed height, not a conditional child: a card whose role is
          // unknown has to occupy the same box as one whose role is known, or
          // a single uncredited actor shortens their column and the whole
          // row's avatars stop lining up. Capped at 1.0x (never grows, still
          // shrinks with a smaller system setting) so a large accessibility
          // text size cannot outgrow this fixed 12px (#69).
          SizedBox(
            height: 12,
            child: Text(
              credit.role ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.0),
              style: TextStyle(
                color: AppColors.inkSubtle,
                fontSize: 10.5,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar, or two initials on a gradient when there is no photo.
class _PersonAvatar extends StatelessWidget {
  final String? profileUrl;
  final String name;

  const _PersonAvatar({required this.profileUrl, required this.name});

  /// Six pairs, picked by the name's hash so the same person keeps the same
  /// colors between visits.
  static const _pairs = [
    [Color(0xFF3A1C71), Color(0xFFD76D77)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF1F4037), Color(0xFF99F2C8)],
    [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
    [Color(0xFF614385), Color(0xFF516395)],
    [Color(0xFF232526), Color(0xFF6E6E6E)],
  ];

  String get _initials {
    if (name.isEmpty) return '?';
    return name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join('')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final pair = _pairs[name.hashCode.abs() % _pairs.length];
    final fallback = _InitialsCircle(initials: _initials, colors: pair);

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: profileUrl == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: pair,
              )
            : null,
        border: Border.all(color: AppColors.inkAlpha(0.1), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: profileUrl != null
          ? CachedNetworkImage(
              imageUrl: profileUrl!,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            )
          : Text(
              _initials,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

/// The placeholder and the error state were the same forty lines twice over.
class _InitialsCircle extends StatelessWidget {
  final String initials;
  final List<Color> colors;

  const _InitialsCircle({required this.initials, required this.colors});

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
