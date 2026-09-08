import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/app_spacing.dart';

/// The single back-navigation button design used across every page that
/// pushes content on top of the hub (Details, Search, and so on). Used to
/// diverge per page -- a frosted floating circle here, a plain icon in a
/// header bar there, `arrow_back_ios_rounded` in one place and
/// `arrow_back_ios_new_rounded` in another -- which read as inconsistent
/// even though each was a reasonable choice on its own. One widget, used
/// everywhere a page needs to pop itself, so it cannot drift again.
class GlassBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  const GlassBackButton({super.key, this.onPressed, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: size,
          ),
          onPressed: onPressed ?? () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
      ),
    );
  }
}

/// [GlassBackButton], positioned, for a page that floats one over a
/// full-bleed hero instead of putting it in a header row.
///
/// One widget owns the offsets so the button lands in the same place on
/// every such page. They each used to carry their own `Positioned`: Details
/// at `topInset + 10` / 16px (48px on desktop), Anime Details at a flat
/// `top: 24` that ignored the status-bar inset entirely, so on a phone with
/// a notch its button sat under the system clock.
class FloatingBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const FloatingBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.floatingTopInset(context),
      left: AppSpacing.pageInset(context),
      child: GlassBackButton(onPressed: onPressed),
    );
  }
}
